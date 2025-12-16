## Cross-chain Rebase Token

A cross-chain, interest-bearing ERC20 that:
- **Mints 1:1 against ETH deposits into a vault**
- **Accrues interest linearly over time** (per-user rate, fixed at deposit time)
- **Bridges across chains using Chainlink CCIP**, preserving each user’s interest rate on the destination chain

This repo is a Foundry project that showcases a CCIP-enabled rebase token with a per-user interest rate that can only ever go down globally, rewarding early adopters.

---

## High-level Design

- **Vault (`Vault.sol`)**
  - Accepts **ETH deposits** and **mints rebase tokens** to users 1:1 with the deposited ETH amount.
  - Users can **redeem** their rebase tokens for ETH. Passing `type(uint256).max` redeems the full balance.
  - Emits `Deposit` and `Redeem` events for integrations and indexing.

- **Rebase Token (`RebaseToken.sol`)**
  - ERC20 token (`RBK`) with **dynamic `balanceOf`**:
    - `balanceOf(user)` = principal × \(1 + r_{user} \times \Delta t\), computed linearly since last interaction.
    - `principleBalanceOf(user)` returns the raw principal (the actually minted amount, without pending interest).
  - **Interest model**
    - **Global interest rate** (`s_interestRate`) can only **decrease** over time (`setInterestRate`), rewarding early users.
    - Each user has a **locked-in per-user interest rate** set at deposit/mint time.
  - **Accrual triggers**
    - Interest is realized on:
      - `mint` (vault deposits)
      - `burn` (vault redemptions / cross-chain burns)
      - `transfer` and `transferFrom` (both sender and recipient)
  - **Access control**
    - Uses `Ownable` + `AccessControl`.
    - A `MINT_AND_BURN_ROLE` is required to call `mint`/`burn` (granted to the vault and CCIP pool).

- **Rebase Token Pool (`RebaseTokenPool.sol`)**
  - Extends Chainlink CCIP’s `TokenPool` to support **cross-chain transfers of the rebase token**.
  - On **lock/burn**:
    - Burns tokens on the source chain.
    - **Reads the user’s per-user interest rate** and encodes it into `destPoolData`.
  - On **release/mint**:
    - Mints tokens on the destination chain with **the same per-user interest rate**, preserving the user’s yield profile across chains.

---

## Contracts Overview

- **`RebaseToken.sol`**
  - ERC20 with:
    - Global interest rate (owner-controlled, non-increasing).
    - Per-user interest rate + last-update timestamps.
    - Overridden `balanceOf` to include linearly accrued interest.
  - Key functions:
    - `setInterestRate(uint256 _newInterestRate)` – only owner; must be **< current rate**.
    - `mint(address _to, uint256 _amount, uint256 _userInterestRate)` – only `MINT_AND_BURN_ROLE`.
    - `burn(address _from, uint256 _amount)` – only `MINT_AND_BURN_ROLE`, supports `type(uint256).max` for full-burn.
    - `principleBalanceOf(address _user)` – returns the principal (no pending interest).
    - `getInterestRate()` – returns the global interest rate.
    - `getUserInterestRate(address _user)` – returns the user-specific rate.

- **`Vault.sol`**
  - Accepts ETH and mints `RebaseToken`:
    - `deposit()` – payable; mints tokens equal to `msg.value` at current global interest rate.
    - `redeem(uint256 _amount)` – burns tokens and sends ETH back; `type(uint256).max` redeems full balance.
    - `getRebaseTokenAddress()` – helper getter.

- **`RebaseTokenPool.sol`**
  - Integrates with CCIP for cross-chain bridging:
    - `lockOrBurn` – validates, reads user interest rate, burns tokens, forwards rate to destination pool.
    - `releaseOrMint` – validates, decodes rate, mints tokens on destination chain.

---

## Cross-chain Flow (Example: Sepolia ↔ Base Sepolia)

The script `bridgeFromSepoliaToBaseSepolia.sh` provides an automated end-to-end demo:

1. **Deploy to Base Sepolia**
   - Deploy `RebaseToken`, `RebaseTokenPool`, and configure permissions via `Deployer.s.sol`.
2. **Deploy to Sepolia**
   - Deploy the same contracts on Sepolia via `Deployer.s.sol`.
3. **Deploy Vault on Sepolia**
   - Deploy `Vault` with the Sepolia `RebaseToken` address.
4. **Configure CCIP Pools**
   - Configure each `RebaseTokenPool` to recognize the counterpart pool and token on the other chain using `ConfigurePool.s.sol`.
5. **Deposit & Accrue Interest**
   - Deposit ETH into the Sepolia vault (mints rebase tokens at the current global interest rate).
6. **Bridge Tokens via CCIP**
   - Use `BridgeTokens.s.sol` to bridge tokens from Sepolia to Base Sepolia.
   - The per-user interest rate is carried in the CCIP message and applied on the destination chain.

---

## Local Development

This project uses **Foundry**.

- **Install dependencies**

 
  make install
  - **Build**

 
  make build
  - **Run tests**

 
  make test
  - **Format**

 
  make format
  - **Coverage**

 
  make coverage
  - **Local Anvil node**

 
  make anvil
  ---

## Deployment & Bridging

### Environment

Create a `.env` file with (at minimum):

```
SEPOLIA_RPC_URL=...
ARBITRUM_SEPOLIA_RPC_URL=.. for testing
BASE_SEPOLIA_RPC_URL=...
```

### Scripts

- **`script/Deployer.s.sol`**
  - Deploys `RebaseToken`, `RebaseTokenPool`, and `Vault` (for relevant entrypoints).
- **`script/ConfigurePool.s.sol`**
  - Wires the CCIP token pool configuration across chains.
- **`script/BridgeTokens.s.sol`**
  - Initiates a cross-chain transfer via CCIP.

You can also run the provided convenience script:

chmod +x bridgeFromSepoliaToBaseSepolia.sh
./bridgeFromSepoliaToBaseSepolia.shThis will:
- Deploy contracts on **Base Sepolia** and **Sepolia**.
- Deploy the **vault** on Sepolia.
- Configure both **token pools**.
- Deposit into the Sepolia vault and **bridge** tokens to Base Sepolia.
- Print balances before/after bridging.

---

## Key Ideas

- **Per-user fixed interest rate**: Each user’s rate is fixed at the time of deposit and does not change, even if the global rate decreases later.
- **Global rate can only decrease**: The owner can only reduce the global rate over time, rewarding early adopters with better yields.
- **Cross-chain fidelity**: When a user bridges, their **per-user rate** is preserved on the destination chain, so their yield profile remains consistent across L1/L2s.
- **Rebase via `balanceOf`**: Instead of periodic mass rebases, the token computes accrued interest on-demand in `balanceOf` and settles it by minting on user actions.


