// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../src/KipuBankV3.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestDirectWithdrawUSDC is Script {
    // Contract address
    address constant BANK = 0xd307e41b2E580302E4c02a35d4ad59899d06b5fa;
    
    // Sepolia addresses
    address constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        KipuBank bank = KipuBank(payable(BANK));
        
        console.log("=== Test: Direct USDC Withdrawal (No Swap) ===");
        console.log("User:", deployer);
        console.log("Bank:", address(bank));
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Check initial balances
        uint256 bankUSDCBefore = bank.getBalanceOf(USDC, deployer);
        
        vm.stopBroadcast();
        
        uint256 usdcWalletBefore = IERC20(USDC).balanceOf(deployer);
        
        console.log("\n=== Initial Balances ===");
        console.log("Bank USDC balance:", bankUSDCBefore / 1e6, "USDC");
        console.log("Wallet USDC:", usdcWalletBefore / 1e6, "USDC");
        
        require(bankUSDCBefore >= 60 * 1e6, "Need at least 60 USDC in bank to withdraw");

        // Withdraw 60 USDC
        uint256 usdcToWithdraw = 60 * 1e6;
        
        console.log("\n=== Withdrawing USDC Directly ===");
        console.log("Amount:", usdcToWithdraw / 1e6, "USDC");

        vm.startBroadcast(deployerPrivateKey);
        
        // Direct withdrawal (no swap)
        bank.withdrawToken(USDC, usdcToWithdraw);
        
        // Check final balances (before stopBroadcast)
        uint256 bankUSDCAfter = bank.getBalanceOf(USDC, deployer);
        
        vm.stopBroadcast();
        
        uint256 usdcWalletAfter = IERC20(USDC).balanceOf(deployer);
        
        console.log("\n=== Transaction Complete ===");
        
        console.log("\n=== Final Balances ===");
        console.log("Bank USDC balance:", bankUSDCAfter / 1e6, "USDC");
        console.log("Wallet USDC:", usdcWalletAfter / 1e6, "USDC");
        console.log("USDC received:", (usdcWalletAfter - usdcWalletBefore) / 1e6, "USDC");
        
        // Verify
        console.log("\n=== Verification ===");
        console.log("USDC withdrawn:", usdcToWithdraw / 1e6, "USDC");
        console.log("Bank balance reduced by:", (bankUSDCBefore - bankUSDCAfter) / 1e6, "USDC");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Check total bank USD
        uint256 totalBankUSD = bank.totalBankUsd();
        
        vm.stopBroadcast();
        
        console.log("Total Bank USD (8 decimals):", totalBankUSD / 1e8, "USD");
        
        console.log("\n=== SUCCESS: Direct withdrawal working ===");
    }
}
