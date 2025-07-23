## Introduction

## Structure

### compare-abis

`Compares the abis of the current branch with dev-main's upon PR. This will perform checks that minor versions in the proxy contracts are incremented during abi changes. Additionally, this can perform checks that state is not being overridden in these contracts (todo)`

### submit-abis

`Submits any new abi version to the abi repo upon merge with dev-main`

### deploy-upgrades

`Ensures the indexer has the new abis and is ready for new impementations to be deployed and for upgrades to be run`
