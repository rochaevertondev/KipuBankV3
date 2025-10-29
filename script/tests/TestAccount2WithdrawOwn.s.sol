// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../src/KipuBankV3.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestAccount2WithdrawOwn is Script {
    // Contract address
    address constant BANK = 0xd307e41b2E580302E4c02a35d4ad59899d06b5fa;
    
    // Sepolia addresses
    address constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    function run() external {
        // Segunda conta
        uint256 account2PrivateKey = 0xc8894d5e47dafe19f1ac3e33d99d9722f81ec1d88c1db6b4fe65ef3675028185;
        address account2 = vm.addr(account2PrivateKey);
        
        KipuBank bank = KipuBank(payable(BANK));
        
        console.log("=== Test: Account 2 Withdrawing Its Own Balance ===");
        console.log("Account 2:", account2);
        console.log("Bank:", address(bank));
        
        vm.startBroadcast(account2PrivateKey);
        
        // Check balances
        uint256 account2Balance = bank.getBalanceOf(USDC, account2);
        
        vm.stopBroadcast();
        
        console.log("\n=== Current State ===");
        console.log("Account 2 balance in bank:", account2Balance / 1e6, "USDC");
        
        console.log("\n=== Withdrawing Own Balance ===");
        
        vm.startBroadcast(account2PrivateKey);
        
        bank.withdrawToken(USDC, account2Balance);
        
        uint256 finalBankBalance = bank.getBalanceOf(USDC, account2);
        uint256 totalRemaining = bank.totalBankUsd();
        
        vm.stopBroadcast();
        
        uint256 walletBalance = IERC20(USDC).balanceOf(account2);
        
        console.log("\n=== After Withdrawal ===");
        console.log("Account 2 bank balance:", finalBankBalance / 1e6, "USDC");
        console.log("Account 2 wallet balance:", walletBalance / 1e6, "USDC");
        console.log("Total bank remaining:", totalRemaining / 1e8, "USD");
        
        console.log("\n=== SUCCESS ===");
        console.log("Account 2 withdrew its 5 USDC successfully");
    }
}
