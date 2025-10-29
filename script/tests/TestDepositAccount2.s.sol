// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../src/KipuBankV3.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestDepositAccount2 is Script {
    // Contract address
    address constant BANK = 0xd307e41b2E580302E4c02a35d4ad59899d06b5fa;
    
    // Sepolia addresses
    address constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    function run() external {
        // Segunda conta
        uint256 account2PrivateKey = 0xc8894d5e47dafe19f1ac3e33d99d9722f81ec1d88c1db6b4fe65ef3675028185;
        address account2 = vm.addr(account2PrivateKey);
        
        KipuBank bank = KipuBank(payable(BANK));
        
        console.log("=== Test: Direct USDC Deposit from Account 2 ===");
        console.log("Account 2:", account2);
        console.log("Bank:", address(bank));
        
        // Check initial balances
        uint256 usdcWalletBefore = IERC20(USDC).balanceOf(account2);
        
        console.log("\n=== Initial Balances ===");
        console.log("Account 2 Wallet USDC:", usdcWalletBefore / 1e6, "USDC");
        
        vm.startBroadcast(account2PrivateKey);
        
        try bank.getBalanceOf(USDC, account2) returns (uint256 bankBal) {
            console.log("Account 2 Bank USDC balance:", bankBal / 1e6, "USDC");
        } catch {
            console.log("Account 2 Bank USDC balance: 0 USDC");
        }
        
        vm.stopBroadcast();

        // Deposit amount
        uint256 usdcToDeposit = 5 * 1e6; // 5 USDC
        
        require(usdcWalletBefore >= usdcToDeposit, "Insufficient USDC balance");
        
        console.log("\n=== Depositing 5 USDC ===");

        vm.startBroadcast(account2PrivateKey);
        
        // Approve USDC to bank
        IERC20(USDC).approve(address(bank), usdcToDeposit);
        console.log("USDC approved");
        
        // Direct deposit (no swap)
        bank.depositToken(USDC, usdcToDeposit);
        
        // Check final balances (before stopBroadcast)
        uint256 bankUSDCBalance = bank.getBalanceOf(USDC, account2);
        
        vm.stopBroadcast();
        
        uint256 usdcWalletAfter = IERC20(USDC).balanceOf(account2);
        
        console.log("\n=== Transaction Complete ===");
        
        console.log("\n=== Final Balances ===");
        console.log("Wallet USDC:", usdcWalletAfter / 1e6, "USDC");
        console.log("USDC spent:", (usdcWalletBefore - usdcWalletAfter) / 1e6, "USDC");
        console.log("Bank USDC balance:", bankUSDCBalance / 1e6, "USDC");
        
        // Verify
        console.log("\n=== Verification ===");
        console.log("USDC deposited:", usdcToDeposit / 1e6, "USDC");
        console.log("Account 2 bank balance:", bankUSDCBalance / 1e6, "USDC");
        
        vm.startBroadcast(account2PrivateKey);
        
        // Check total bank USD
        uint256 totalBankUSD = bank.totalBankUsd();
        
        vm.stopBroadcast();
        
        console.log("Total Bank USD (8 decimals):", totalBankUSD / 1e8, "USD");
        
        console.log("\n=== SUCCESS: Account 2 deposited 5 USDC ===");
    }
}
