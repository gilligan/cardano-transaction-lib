-- | Definitions for error types that may arise during transaction balancing,
-- | along with helpers for parsing and pretty-printing script evaluation errors
-- | that may be returned from Ogmios when calculating ex units.
module Ctl.Internal.BalanceTx.Error
  ( Actual(Actual)
  , InvalidInContext(InvalidInContext)
  , BalanceTxError
      ( BalanceInsufficientError
      , CouldNotConvertScriptOutputToTxInput
      , CouldNotGetChangeAddress
      , CouldNotGetCollateral
      , CouldNotGetUtxos
      , CollateralReturnError
      , CollateralReturnMinAdaValueCalcError
      , ExUnitsEvaluationFailed
      , InsufficientUtxoBalanceToCoverAsset
      , ReindexRedeemersError
      , UtxoLookupFailedFor
      , UtxoMinAdaValueCalculationFailed
      )
  , Expected(Expected)
  , ImpossibleError(Impossible)
  , printTxEvaluationFailure
  ) where

import Prelude

import Ctl.Internal.BalanceTx.RedeemerIndex (UnindexedRedeemer)
import Ctl.Internal.Cardano.Types.Transaction (Redeemer(Redeemer), Transaction, _redeemers, _witnessSet)
import Ctl.Internal.Plutus.Types.Value (Value)
import Ctl.Internal.QueryM.Ogmios (RedeemerPointer, ScriptFailure(..), TxEvaluationFailure(UnparsedError, ScriptFailures)) as Ogmios
import Ctl.Internal.QueryM.Ogmios (showRedeemerPointer)
import Ctl.Internal.Types.Natural (toBigInt) as Natural
import Ctl.Internal.Types.Transaction (TransactionInput)
import Data.Array (catMaybes, filter, uncons) as Array
import Data.Bifunctor (bimap)
import Data.BigInt (toString) as BigInt
import Data.Either (Either(Left, Right), either, isLeft)
import Data.Foldable (find, foldMap, foldl, length)
import Data.FoldableWithIndex (foldMapWithIndex)
import Data.Function (applyN)
import Data.Generic.Rep (class Generic)
import Data.Int (ceil, decimal, toNumber, toStringAs)
import Data.Lens (non, (^.))
import Data.Maybe (Maybe(Just, Nothing))
import Data.Newtype (class Newtype)
import Data.Show.Generic (genericShow)
import Data.String (Pattern(Pattern))
import Data.String.CodePoints (length) as String
import Data.String.Common (joinWith, split) as String
import Data.String.Utils (padEnd)

-- | Errors conditions that may possibly arise during transaction balancing
data BalanceTxError
  = BalanceInsufficientError Expected Actual InvalidInContext
  | CouldNotConvertScriptOutputToTxInput
  | CouldNotGetChangeAddress
  | CouldNotGetCollateral
  | CouldNotGetUtxos
  | CollateralReturnError String
  | CollateralReturnMinAdaValueCalcError
  | ExUnitsEvaluationFailed Transaction Ogmios.TxEvaluationFailure
  | InsufficientUtxoBalanceToCoverAsset ImpossibleError String
  | ReindexRedeemersError UnindexedRedeemer
  | UtxoLookupFailedFor TransactionInput
  | UtxoMinAdaValueCalculationFailed

derive instance Generic BalanceTxError _

instance Show BalanceTxError where
  show (ExUnitsEvaluationFailed tx failure) =
    "ExUnitsEvaluationFailed: " <> printTxEvaluationFailure tx failure
  show e = genericShow e

newtype Actual = Actual Value

derive instance Generic Actual _
derive instance Newtype Actual _

instance Show Actual where
  show = genericShow

newtype InvalidInContext = InvalidInContext Value

derive instance Generic InvalidInContext _
derive instance Newtype InvalidInContext _

instance Show InvalidInContext where
  show = genericShow

newtype Expected = Expected Value

derive instance Generic Expected _
derive instance Newtype Expected _

instance Show Expected where
  show = genericShow

-- | Indicates that an error should be impossible.
data ImpossibleError = Impossible

derive instance Generic ImpossibleError _

instance Show ImpossibleError where
  show = genericShow

--------------------------------------------------------------------------------
-- Failure parsing for Ogmios.EvaluateTx
--------------------------------------------------------------------------------

type WorkingLine = String
type FrozenLine = String

type PrettyString = Array (Either WorkingLine FrozenLine)

runPrettyString :: PrettyString -> String
runPrettyString ary = String.joinWith "" (either identity identity <$> ary)

freeze :: PrettyString -> PrettyString
freeze ary = either Right Right <$> ary

line :: String -> PrettyString
line s =
  case Array.uncons lines of
    Nothing -> []
    Just { head, tail } -> [ head ] <> freeze tail
  where
  lines = Left <<< (_ <> "\n") <$> String.split (Pattern "\n") s

bullet :: PrettyString -> PrettyString
bullet ary = freeze (bimap ("- " <> _) ("  " <> _) <$> ary)

number :: PrettyString -> PrettyString
number ary = freeze (foldl go [] ary)
  where
  biggestPrefix :: String
  biggestPrefix = toStringAs decimal (length (Array.filter isLeft ary)) <> ". "

  width :: Int
  width = ceil (toNumber (String.length biggestPrefix) / 2.0) * 2

  numberLine :: Int -> String -> String
  numberLine i l = padEnd width (toStringAs decimal (i + 1) <> ". ") <> l

  indentLine :: String -> String
  indentLine = applyN ("  " <> _) (width / 2)

  go :: PrettyString -> Either WorkingLine FrozenLine -> PrettyString
  go b a = b <> [ bimap (numberLine $ length b) indentLine a ]

-- | Pretty print the failure response from Ogmios's EvaluateTx endpoint.
-- | Exported to allow testing, use `Test.Ogmios.Aeson.printEvaluateTxFailures`
-- | to visually verify the printing of errors without a context on fixtures.
printTxEvaluationFailure
  :: Transaction -> Ogmios.TxEvaluationFailure -> String
printTxEvaluationFailure transaction e =
  runPrettyString $ case e of
    Ogmios.UnparsedError error -> line $ "Unknown error: " <> show error
    Ogmios.ScriptFailures sf -> line "Script failures:" <> bullet
      (foldMapWithIndex printScriptFailures sf)
  where
  lookupRedeemerPointer
    :: Ogmios.RedeemerPointer -> Maybe Redeemer
  lookupRedeemerPointer ptr =
    flip find (transaction ^. _witnessSet <<< _redeemers <<< non [])
      $ \(Redeemer { index, tag }) -> tag == ptr.redeemerTag && index ==
          Natural.toBigInt ptr.redeemerIndex

  printRedeemerPointer :: Ogmios.RedeemerPointer -> PrettyString
  printRedeemerPointer ptr =
    line
      ( show ptr.redeemerTag <> ":" <> BigInt.toString
          (Natural.toBigInt ptr.redeemerIndex)
      )

  -- TODO Investigate if more details can be printed, for example minting
  -- policy/minted assets
  -- https://github.com/Plutonomicon/cardano-transaction-lib/issues/881
  printRedeemerDetails :: Ogmios.RedeemerPointer -> PrettyString
  printRedeemerDetails ptr =
    let
      mbRedeemerTxIn = lookupRedeemerPointer ptr
      mbData = mbRedeemerTxIn <#> \(Redeemer r) -> "Redeemer: " <> show r.data
      mbTxIn = mbRedeemerTxIn <#> \txIn -> "Input: " <> show txIn
    in
      foldMap line $ Array.catMaybes [ mbData, mbTxIn ]

  printRedeemer :: Ogmios.RedeemerPointer -> PrettyString
  printRedeemer ptr =
    printRedeemerPointer ptr <> bullet (printRedeemerDetails ptr)

  printScriptFailure :: Ogmios.ScriptFailure -> PrettyString
  printScriptFailure = case _ of
    Ogmios.ExtraRedeemers ptrs -> line "Extra redeemers:" <> bullet
      (foldMap printRedeemer ptrs)
    Ogmios.MissingRequiredDatums missing
    -> line "Missing required datums:"
      <> bullet (foldMap line missing)
    Ogmios.MissingRequiredScripts missing
    -> line "Missing required scripts:"
      <> bullet (foldMap (line <<< showRedeemerPointer) missing)
    Ogmios.ValidatorFailed { error, traces } -> line error <> line "Trace:" <>
      number
        (foldMap line traces)
    Ogmios.UnknownInputReferencedByRedeemer txIn -> line
      ("Unknown input referenced by redeemer: " <> show txIn)
    Ogmios.NonScriptInputReferencedByRedeemer txIn -> line
      ("Non script input referenced by redeemer: " <> show txIn)
    Ogmios.NoCostModelForLanguage languages -> 
      line "No cost model for languages:" 
      <> bullet (foldMap line languages)
    Ogmios.InternalLedgerTypeConversionError error -> 
      line $ "Internal ledger type conversion error, if you ever run into this, please report the issue as you've likely discoverd a critical bug: \""
        <> error <> "\""

  printScriptFailures
    :: Ogmios.RedeemerPointer -> Array Ogmios.ScriptFailure -> PrettyString
  printScriptFailures ptr sfs = printRedeemer ptr <> bullet
    (foldMap printScriptFailure sfs)
