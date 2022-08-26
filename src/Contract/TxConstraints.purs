-- | A module for building `TxConstraints` te pair with the `ScriptLookups`
-- | as part of an off-chain transaction.
module Contract.TxConstraints (module TxConstraints) where

import Types.TxConstraints
  ( InputConstraint(InputConstraint)
  , InputWithScriptRef(RefInput, SpendableInput)
  , OutputConstraint(OutputConstraint)
  , TxConstraint
      ( MustIncludeDatum
      , MustValidateIn
      , MustBeSignedBy
      , MustSpendAtLeast
      , MustProduceAtLeast
      , MustSpendPubKeyOutput
      , MustSpendScriptOutput
      , MustReferenceOutput
      , MustMintValue
      , MustPayToPubKeyAddress
      , MustPayToScript
      , MustHashDatum
      , MustSatisfyAnyOf
      )
  , TxConstraints(TxConstraints)
  , addTxIn
  , isSatisfiable
  , modifiesUtxoSet
  , mustBeSignedBy
  , mustHashDatum
  , mustIncludeDatum
  , mustMintCurrency
  , mustMintCurrencyUsingScriptRef
  , mustMintCurrencyWithRedeemer
  , mustMintCurrencyWithRedeemerUsingScriptRef
  , mustMintValue
  , mustMintValueWithRedeemer
  , mustPayToScript
  , mustPayToPubKey
  , mustPayToPubKeyAddress
  , mustPayWithDatumAndScriptRefToPubKey
  , mustPayWithDatumAndScriptRefToPubKeyAddress
  , mustPayWithDatumToPubKey
  , mustPayWithDatumToPubKeyAddress
  , mustPayWithScriptRefToPubKey
  , mustPayWithScriptRefToPubKeyAddress
  , mustPayWithScriptRefToScript
  , mustProduceAtLeast
  , mustProduceAtLeastTotal
  , mustReferenceOutput
  , mustSatisfyAnyOf
  , mustSpendAtLeast
  , mustSpendAtLeastTotal
  , mustSpendPubKeyOutput
  , mustSpendScriptOutput
  , mustSpendScriptOutputUsingScriptRef
  , mustValidateIn
  , pubKeyPayments
  , requiredDatums
  , requiredMonetaryPolicies
  , requiredSignatories
  , singleton
  ) as TxConstraints
