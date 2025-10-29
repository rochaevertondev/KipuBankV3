// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/KipuBankV3.sol";

contract DeployKipuBankV3 is Script {
    // Sepolia addresses
    address constant UNIVERSAL_ROUTER = 0x3A9D48AB9751398BbFa63ad67599Bb04e4BdF98b;
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address constant WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    
    // Token addresses
    address constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address constant LINK = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    
    // Chainlink price feeds
    address constant LINK_USD_FEED = 0xc59E3633BAAC79493d908e63626716e204A45EdF;
    address constant USDC_USD_FEED = 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Deploying KipuBankV3 (USDC-Only Architecture) ===");
        console.log("Deployer:", deployer);
        console.log("ETH Balance:", deployer.balance / 1e18, "ETH");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy contract
        KipuBank bank = new KipuBank(
            UNIVERSAL_ROUTER,
            PERMIT2,
            WETH,
            USDC,
            10000 * 10 ** 6  // 10k USDC cap
        );

        console.log("\n=== Deployment Successful ===");
        console.log("KipuBankV3:", address(bank));
        console.log("Owner:", bank.ownerBank());
        console.log("USDC:", address(bank.USDC()));
        console.log("Bank Cap (USDC):", bank.bankCapUsdc6() / 1e6, "USDC");
        
        console.log("\n=== Configuration ===");
        console.log("Universal Router:", address(bank.universalRouter()));
        console.log("Permit2:", address(bank.permit2()));
        console.log("WETH:", address(bank.weth()));
        
        console.log("\n=== Architecture ===");
        console.log("Storage: USDC-only (6 decimals)");
        console.log("Swaps: Uniswap V3 via Universal Router");
        console.log("Oracle Age Limit: 1 hour");

        vm.stopBroadcast();
        
        console.log("\n=== Next Steps ===");
        console.log("1. Verify contract on Etherscan");
        console.log("2. Test deposits (ETH/LINK -> USDC)");
        console.log("3. Test withdrawals (USDC -> ETH/LINK)");
        console.log("\nVerify with:");
        console.log("forge verify-contract", address(bank), "src/KipuBankV3.sol:KipuBank --chain sepolia --watch");
    }
}
