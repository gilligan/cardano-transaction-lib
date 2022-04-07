# Cardano Transaction Lib
[![Hercules-ci][Herc badge]][Herc link]
[![Cachix Cache][Cachix badge]][Cachix link]

[Herc badge]: https://img.shields.io/badge/ci--by--hercules-green.svg
[Herc link]: https://hercules-ci.com/github/Plutonomicon/cardano-transaction-lib
[Cachix badge]: https://img.shields.io/badge/cachix-public_plutonomicon-blue.svg
[Cachix link]: https://public-plutonomicon.cachix.org

## Goals:

1. build a transaction in the browser that works with at least 1 light wallet (Nami).
2. once we can construct a simple user-to-user transaction, we will try to use the library to submit the Tx with nami. 
3. Once we have a simple working transaction, we will seek to build a Plutus Contract transaction With datum from scratch. 
4. Once we can construct Plutus Contract transactions, we will seek to build a library/dsl/interface such that transactions can be built using constraints and lookups - as close as possible to a cut-and-paste solution from `Contract` Monad code in haskell (but with no guarantee that code changes are not necessary)

## resources/tools:
  - Cardano-serialization-lib (Sundae fork):https://github.com/SundaeSwap-finance/cardano-serialization-lib)
  - ogmios - for querying the chain - https://ogmios.dev 
  - example testbed - https://github.com/Benjmhart/nami-integration 
  - CIP-30 (Wallet interface - nami partially implements this) -https://github.com/cardano-foundation/CIPs/tree/master/CIP-0030
  - Nami docs - https://github.com/Berry-Pool/nami-wallet 
  - cddl spec for alonzo - https://github.com/input-output-hk/cardano-ledger/blob/0738804155245062f05e2f355fadd1d16f04cd56/alonzo/impl/cddl-files/alonzo.cddl 

## Setup and dev environment

Running `nix develop` in the root of the repository will place you in an development environment with all of the necessary executables, tools, config, etc... to:

- build the project or use the repl with `spago` (the Purescript project can also be built using Nix directly, e.g. `nix build`). All of the JS dependencies are also present through symlinked `node_modules`
- run a Cardano testnet node along with our fork of `ogmios`. **Note**: at the moment, only running a public testnet node is supported. In future iterations we will support more scenarios (mainnet, private testnet, etc...)

There are a few Makefile targets provided for convenience, all of which require being in the Nix shell environment. `make run-testnet-node` starts the node in a Docker container and `make run-testnet-ogmios` starts our fork of `ogmios` with the correct flags (i.e. config and node socket locations). If you prefer to run these without `make`, the environment variables `CARDANO_NODE_SOCKET_PATH` and `CARDANO_NODE_CONFIG` are also exported in the shell pointing to the correct locations. 

After starting the node, you can use `make query-testnet-sync` to check its sync status. If the node is fully synced, you will see:

```
{  "epoch": 1005, 
   "hash": "162d6541cc5aa6b0e098add8fa08a94660a08b9463c0a86fcf84661b5f63375f", 
   "slot": 7232440, 
   "block": 322985, 
   "era": "Alonzo", 
   "syncProgress": "100.00" 
} 
``` 

In particular, `syncProgress` is the important part here.

In order to query for datums, another service, `omgios-datum-cache`, is required. This service in turn depends on a running Postgresql instance. `ogmios-datum-cache` is available in the Nix shell environment. There is also a Makefile target to run a Postgres Docker container (`run-datum-cache-postgres`) with a username, password, and DB name corresponding to the `ogmios-datum-cache` configuration file (`config.toml`) in the repository root.

### Building the PS project & testing

You can run `nix build` or `spago build` (once in the development shell) to build the Purescript project. `npm run test` can be used to only run the test suite.

### Running the project in the browser

`npm run dev` will start a Webpack development server at `localhost:4008`. By default, Webpack will build a small Purescript example (`examples/nami/Pkh2Pkh.purs`). You should have a Nami wallet enabled and allow the page to access your wallet. The example expects that wallet has some funds available and Nami's 0.5ADA collateral set (which can be done from the wallet gui - click on the robot's face). 

`npm run build` will output the Webpack-bundled project in `dist` (again using the example in `Pkh2Pkh.purs`).

**Note**: The `BROWSER_RUNTIME` environment variable must be set to `1` in order to build/bundle the project properly for the browser (e.g. `BROWSER_RUNTIME=1 webpack ...`). For Node environments, leave this variable unset or set it to `0`.

### Updating the autogenerated Nix expressions

Unfortunately, we rely on two projects that require autogenerated Nix code (`spago2nix` and `node2nix`). This means that it is possible for our declared dependencies to drift from the autogen Nix code we import in various places. If you add either a Purescript or JS dependency, make sure to run `make autogen-deps` from within the Nix shell to update the autogen Nix modules.

**Important**: If you add a dependency to the package.json, make sure to update the lockfile with `npm i --package-lock-only` _before_ entering a new dev shell, otherwise the `shellHook` will fail. You'll need to remove the existing symlinked `node_modules` to do this (for some reason `npm` will _still_ try to write to the `node_modules`, but will fail because they're symlinked to the Nix store).

## Architecture
So if we think of pab as a library instead of as a standalone process there are really just a few problems to consider:

1. How do we get the transaction in the right format - this is handled by cardano-serialization-lib,  a rust library available as wasm
2. How do we query the chain - Ogmios or BlockFrost api integration,   if these services don't have a permissive CORS setting,  the user/developer needs to provide the url for a proxy server.
3. Querying Datum may require chain-index or blockfrost, as ogmios does not support this feature.
note: this may have limitations for private testnets where Ogmios or blockfrost services do not yet exist
4. How do we submit the transaction - through the light wallet integration in the browser based on cip-30
5. The lingering question is around storage solutions if needed - this can be in memory,  in various browser storage solutions,  or a decentralized db like flurry

The main goal of the library is to provide a reasonable interface to build and balance a transaction manually

In the first iteration, we just want a library interface to achieve this with Nami so we can start shipping

In the second iteration we will want to support multiple wallets and automatic balancing, rather than manual.

In the third iteration,  we want to support an interface that matches the original pab so people can easily port their code over. This will likely Not be a compiled eDSL in PureScript.   Library code in a Promise Monad is much more likely.

We will support both a PureScript and a JavaScript api.
