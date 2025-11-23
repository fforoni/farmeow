# 🐱 Far Meow - Cat Running Game on Base

A Farcaster-native cat running game with hourly USDC prize pools on Base network.

## 🎮 Features
- **Hourly Rounds**: Top 20 players split the prize pool
- **USDC Rewards**: Real money payouts via smart contract
- **Farcaster Native**: Play directly in Farcaster frames
- **UUPS Upgradeable**: Contract can be improved without losing state

## 🏗️ Tech Stack
- **Smart Contracts**: Solidity 0.8.20, OpenZeppelin, Foundry
- **Frontend**: HTML5 Canvas, Ethers.js, Tailwind CSS
- **Backend**: Node.js, Express, PostgreSQL (separate repo)
- **Blockchain**: Base (Mainnet & Sepolia)

## 📁 Project Structure

````markdown
## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
````
