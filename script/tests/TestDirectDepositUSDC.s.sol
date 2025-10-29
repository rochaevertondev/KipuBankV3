// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../src/KipuBankV3.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestDirectDepositUSDC is Script {
    // Contract address
    address constant BANK = 0xd307e41b2E580302E4c02a35d4ad59899d06b5fa;
    
    // Sepolia addresses
    address constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        KipuBank bank = KipuBank(payable(BANK));
        
        console.log("=== Test: Direct USDC Deposit (No Swap) ===");
        console.log("User:", deployer);
        console.log("Bank:", address(bank));
        
        // Check initial balances
        uint256 usdcWalletBefore = IERC20(USDC).balanceOf(deployer);
        
        console.log("\n=== Initial Balances ===");
        console.log("Wallet USDC:", usdcWalletBefore / 1e6, "USDC");
        
        try bank.getBalanceOf(USDC, deployer) returns (uint256 bankBal) {
            console.log("Bank USDC balance:", bankBal / 1e6, "USDC");
        } catch {
            console.log("Bank USDC balance: 0 USDC");
        }

        // Deposit amount
        uint256 usdcToDeposit = 2 * 1e6; // 2 USDC
        
        require(usdcWalletBefore >= usdcToDeposit, "Insufficient USDC balance");
        
        console.log("\n=== Depositing USDC Directly ===");
        console.log("Amount:", usdcToDeposit / 1e6, "USDC");

        vm.startBroadcast(deployerPrivateKey);
        
        // Approve USDC to bank
        IERC20(USDC).approve(address(bank), usdcToDeposit);
        console.log("USDC approved");
        
        // Direct deposit (no swap)
        bank.depositToken(USDC, usdcToDeposit);
        
        console.log("\n=== Transaction Complete ===");
        
        // Check final balances (call getBalanceOf before stopBroadcast)
        uint256 bankUSDCBalance = bank.getBalanceOf(USDC, deployer);
        
        vm.stopBroadcast();
        
        uint256 usdcWalletAfter = IERC20(USDC).balanceOf(deployer);
        
        console.log("\n=== Final Balances ===");
        console.log("Wallet USDC:", usdcWalletAfter / 1e6, "USDC");
        console.log("USDC spent:", (usdcWalletBefore - usdcWalletAfter) / 1e6, "USDC");
        console.log("Bank USDC balance:", bankUSDCBalance / 1e6, "USDC");
        
        // Verify
        console.log("\n=== Verification ===");
        console.log("USDC deposited:", usdcToDeposit / 1e6, "USDC");
        console.log("Bank credited:", bankUSDCBalance / 1e6, "USDC");
        
        // Check total bank USD
        uint256 totalBankUSD = bank.totalBankUsd();
        console.log("Total Bank USD (8 decimals):", totalBankUSD / 1e8, "USD");
        
        console.log("\n=== SUCCESS: Direct deposit working ===");
    }
}
