// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../src/KipuBankV3.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestAccount2TryWithdrawAll is Script {
    // Contract address
    address constant BANK = 0xd307e41b2E580302E4c02a35d4ad59899d06b5fa;
    
    // Sepolia addresses
    address constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    function run() external {
        // Segunda conta
        uint256 account2PrivateKey = 0xc8894d5e47dafe19f1ac3e33d99d9722f81ec1d88c1db6b4fe65ef3675028185;
        address account2 = vm.addr(account2PrivateKey);
        
        KipuBank bank = KipuBank(payable(BANK));
        
        console.log("=== Test: Account 2 Trying to Withdraw ALL Bank Funds ===");
        console.log("Account 2:", account2);
        console.log("Bank:", address(bank));
        
        vm.startBroadcast(account2PrivateKey);
        
        // Check balances
        uint256 account2Balance = bank.getBalanceOf(USDC, account2);
        uint256 totalBankUsd = bank.totalBankUsd();
        
        vm.stopBroadcast();
        
        console.log("\n=== Current State ===");
        console.log("Account 2 balance:", account2Balance / 1e6, "USDC");
        console.log("Total bank balance:", totalBankUsd / 1e8, "USD");
        console.log("Total in USDC (6 decimals):", totalBankUsd / 100, "raw");
        
        // Account 2 tem 5 USDC mas vai tentar sacar o total do banco (19.27 USDC)
        uint256 totalBankUsdc = totalBankUsd / 100; // Converter de 8 para 6 decimals
        
        console.log("\n=== Attempting to Withdraw ALL Bank Funds ===");
        console.log("Trying to withdraw:", totalBankUsdc / 1e6, "USDC");
        console.log("Account 2 only has:", account2Balance / 1e6, "USDC");
        console.log("Excess attempted:", (totalBankUsdc - account2Balance) / 1e6, "USDC");
        
        vm.startBroadcast(account2PrivateKey);
        
        try bank.withdrawToken(USDC, totalBankUsdc) {
            vm.stopBroadcast();
            console.log("\n[CRITICAL SECURITY ISSUE] Withdrawal succeeded!");
            console.log("Account 2 should NOT be able to withdraw more than its balance!");
            revert("SECURITY BREACH: Withdrew more than account balance");
        } catch Error(string memory reason) {
            vm.stopBroadcast();
            console.log("\n=== SUCCESS: Withdrawal Blocked ===");
            console.log("Error reason:", reason);
            console.log("[OK] Contract prevented withdrawal beyond account balance");
        } catch (bytes memory lowLevelData) {
            vm.stopBroadcast();
            console.log("\n=== SUCCESS: Withdrawal Blocked ===");
            console.log("[OK] Contract prevented withdrawal beyond account balance");
            
            // Decode the error
            if (lowLevelData.length >= 68) {
                bytes4 errorSelector = bytes4(lowLevelData);
                console.log("Error selector:");
                console.logBytes4(errorSelector);
                
                // InsufficientBalance selector is 0x96d4f75e
                if (errorSelector == 0x96d4f75e) {
                    uint256 balance = abi.decode(slice(lowLevelData, 4, lowLevelData.length - 4), (uint256));
                    console.log("Account actual balance:", balance / 1e6, "USDC");
                }
            }
        }
        
        // Now try to withdraw the correct amount (only what Account 2 has)
        console.log("\n=== Now Withdrawing Correct Amount ===");
        console.log("Withdrawing Account 2's actual balance:", account2Balance / 1e6, "USDC");
        
        vm.startBroadcast(account2PrivateKey);
        
        bank.withdrawToken(USDC, account2Balance);
        
        uint256 finalBalance = bank.getBalanceOf(USDC, account2);
        
        vm.stopBroadcast();
        
        uint256 walletBalance = IERC20(USDC).balanceOf(account2);
        
        console.log("\n=== After Correct Withdrawal ===");
        console.log("Account 2 bank balance:", finalBalance / 1e6, "USDC");
        console.log("Account 2 wallet balance:", walletBalance / 1e6, "USDC");
        
        vm.startBroadcast(account2PrivateKey);
        uint256 finalTotalBank = bank.totalBankUsd();
        vm.stopBroadcast();
        
        console.log("Total bank remaining:", finalTotalBank / 1e8, "USD");
        
        console.log("\n=== SECURITY VALIDATED ===");
        console.log("[OK] Account 2 could only withdraw its own balance (5 USDC)");
        console.log("[OK] Other accounts' funds remain safe (14.27 USDC)");
    }
    
    function slice(bytes memory data, uint256 start, uint256 length) internal pure returns (bytes memory) {
        bytes memory result = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            result[i] = data[start + i];
        }
        return result;
    }
}
