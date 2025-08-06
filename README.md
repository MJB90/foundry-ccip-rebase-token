
# Cross-chain Rebase Token

## How to Bridge Tokens Cross-Chain (Step-by-Step)

1. **Deploy contracts on both chains**
   - Deploy `RebaseToken`, `RebaseTokenPool`, and `Vault` using Foundry scripts on both source and destination chains.
   - Example:
     ```bash
     forge script ./script/Deployer.s.sol:TokenAndPoolDeployer --rpc-url <RPC_URL> --account <ACCOUNT> --broadcast
     forge script ./script/Deployer.s.sol:VaultDeployer --rpc-url <RPC_URL> --account <ACCOUNT> --broadcast --sig "run(address)" <REBASE_TOKEN_ADDRESS>
     ```

2. **Set permissions and register with CCIP**
   - Grant mint/burn roles to the pool and vault.
   - Register the token with Chainlink CCIP’s admin registry contracts.
   - Set the pool for the token in the registry.
   - Example:
     ```bash
     cast send <REBASE_TOKEN_ADDRESS> "grantMintAndBurnRole(address)" <POOL_ADDRESS> --rpc-url <RPC_URL> --account <ACCOUNT>
     cast send <REGISTRY_MODULE_OWNER_CUSTOM> "registerAdminViaOwner(address)" <REBASE_TOKEN_ADDRESS> --rpc-url <RPC_URL> --account <ACCOUNT>
     cast send <TOKEN_ADMIN_REGISTRY> "acceptAdminRole(address)" <REBASE_TOKEN_ADDRESS> --rpc-url <RPC_URL> --account <ACCOUNT>
     cast send <TOKEN_ADMIN_REGISTRY> "setPool(address,address)" <REBASE_TOKEN_ADDRESS> <POOL_ADDRESS> --rpc-url <RPC_URL> --account <ACCOUNT>
     ```

3. **Configure the pool for cross-chain bridging**
   - Set up the remote pool and token addresses for each chain using your `ConfigurePoolScript`.
   - Example:
     ```bash
     forge script ./script/ConfigurePool.s.sol:ConfigurePoolScript --rpc-url <RPC_URL> --account <ACCOUNT> --broadcast --sig "run(address,uint64,address,address,bool,uint128,uint128,bool,uint128,uint128)" <POOL_ADDRESS> <REMOTE_CHAIN_SELECTOR> <REMOTE_POOL_ADDRESS> <REMOTE_TOKEN_ADDRESS> false 0 0 false 0 0
     ```

4. **Deposit tokens to the vault**
   - Deposit ETH to the vault to mint rebase tokens.
   - Example:
     ```bash
     cast send <VAULT_ADDRESS> --value <AMOUNT> --rpc-url <RPC_URL> --account <ACCOUNT> "deposit()"
     ```

5. **Bridge tokens using CCIP**
   - Use your `BridgeTokensScript` to send tokens from the source chain to the destination chain via CCIP.
   - Example:
     ```bash
     forge script ./script/BridgeTokens.s.sol:BridgeTokensScript --rpc-url <RPC_URL> --account <ACCOUNT> --broadcast --sig "run(address,uint64,address,uint256,address,address)" <RECEIVER_ADDRESS> <DEST_CHAIN_SELECTOR> <TOKEN_TO_SEND_ADDRESS> <AMOUNT_TO_SEND> <LINK_TOKEN_ADDRESS> <ROUTER_ADDRESS>
     ```

6. **Monitor and confirm bridging**
   - Check balances on both chains to confirm the tokens have been bridged.
   - Use block explorers or `cast balance` to verify.

**Note:**
- Repeat steps 1–3 for both source and destination chains.
- Ensure your wallet is funded with enough ETH and LINK on both chains.
- All contract addresses and chain selectors must be correct and match the CCIP testnet/mainnet configuration.

1. A protocol that allows user to deposit into a vault and in return, receive rebase tokens that represent their underlying balance.

2. Rebase token --> balanceOf function is dynamic to show the changing balance with time.
    - Balance increases linearly with time
    - mint tokens for our users every time they perform an action (minting, burning, transferring or bridging)

3. Interest rate
    - Individually set an interest rate on each user based on some global interest rate of the protocol at the time the user deposits into the vault.
    - This global interest rate can only decrease to incentivise/reward early adopters. 
    - Increase token adoption