# Launchpad MVP

A minimal token launchpad built with Foundry.

This MVP includes:
- Sale creation via factory
- Basic buy flow with hard cap
- Finalization with soft cap success/fail
- Refund flow when soft cap is not met
- Vesting-based token claims on successful sales

## Contracts

- `src/LaunchpadFactory.sol`
  - Deploys one `TokenSale` + one `VestingVault` per launch
  - Tracks all created sales

- `src/TokenSale.sol`
  - Accepts `raiseToken` contributions during the sale window
  - Enforces hard cap
  - Finalizes sale outcome
  - Sends raised funds to treasury on success
  - Enables refunds on failure
  - Creates vesting entries when users claim

- `src/VestingVault.sol`
  - Holds project sale tokens
  - Stores per-user vesting schedules
  - Releases vested tokens to users via `claim()`

## Project Setup

1. Install Foundry:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. Install dependencies:
```bash
forge install
```

3. Build contracts:
```bash
forge build --skip test --skip script
```

## Run Tests

```bash
forge test -vv
```

Current tests are in `test/Counter.t.sol` and cover:
- sale creation and ownership wiring
- successful sale finalization and vesting claim path
- failed sale refund path

## Local Development

Start a local node:
```bash
anvil
```

## Testnet Deployment

Deployment script:
- `script/Launchpad.s.sol`
- Contract: `DeployLaunchpadScript`

Set environment variables:

```bash
PRIVATE_KEY=<deployer_private_key>
RAISE_TOKEN=<erc20_raise_token_address>
SALE_TOKEN=<erc20_sale_token_address>
TREASURY=<treasury_address>
PRICE=<raise_token_per_1e18_sale_tokens>
START_TIME=<unix_timestamp>
END_TIME=<unix_timestamp>
SOFT_CAP=<raise_token_amount>
HARD_CAP=<raise_token_amount>
VESTING_START=<unix_timestamp>
VESTING_CLIFF=<unix_timestamp>
VESTING_DURATION=<seconds>
```

Quick start:

```bash
cp .env.example .env
```

Run deployment:

```bash
forge script script/Launchpad.s.sol:DeployLaunchpadScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv
```

The script prints deployed addresses for:
- `LaunchpadFactory`
- `TokenSale`
- `VestingVault`

## Basic Usage Flow

1. Deploy with `DeployLaunchpadScript` (creates factory + first sale + vault)
2. Transfer enough `SALE_TOKEN` into the deployed `VestingVault`
3. Users approve `RAISE_TOKEN` to `TokenSale` and call `buy(amount)`
4. After sale end, owner calls `finalize()`
5. If successful:
   - users call `claimTokens()` on `TokenSale`
   - users call `claim()` on `VestingVault` over time
6. If failed:
   - users call `refund()` on `TokenSale`

## MVP Limitations

- No whitelist / signature gating
- No per-user allocation cap
- No pause/emergency controls
- No admin fee model
- No frontend/indexer in this repository

Use this as a starter implementation and extend based on your launch requirements.
