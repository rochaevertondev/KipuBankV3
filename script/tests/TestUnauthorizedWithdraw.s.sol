// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../src/KipuBankV3.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestUnauthorizedWithdraw is Script {
    // Contract address
    address constant BANK = 0xd307e41b2E580302E4c02a35d4ad59899d06b5fa;
    
    // Sepolia addresses
    address constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    function run() external {
        // Usando a chave privada da segunda conta
        uint256 attackerPrivateKey = 0xc8894d5e47dafe19f1ac3e33d99d9722f81ec1d88c1db6b4fe65ef3675028185;
        address attacker = vm.addr(attackerPrivateKey);
        
        // Conta original que tem saldo
        uint256 victimPrivateKey = vm.envUint("PRIVATE_KEY");
        address victim = vm.addr(victimPrivateKey);
        
        KipuBank bank = KipuBank(payable(BANK));
        
        console.log("=== Test: Unauthorized Withdrawal Attempt ===");
        console.log("Attacker:", attacker);
        console.log("Victim (has balance):", victim);
        console.log("Bank:", address(BANK));
        
        // Check victim's balance (need to use victim's key)
        vm.startBroadcast(victimPrivateKey);
        uint256 victimBalance = bank.getBalanceOf(USDC, victim);
        vm.stopBroadcast();
        
        console.log("\n=== Current Balances ===");
        console.log("Victim's bank balance:", victimBalance / 1e6, "USDC");
        
        // Now try to withdraw with attacker's account
        console.log("\n=== Attempting Unauthorized Withdrawal ===");
        console.log("Attacker trying to withdraw:", victimBalance / 1e6, "USDC from victim's account");
        
        vm.startBroadcast(attackerPrivateKey);
        
        try bank.withdrawToken(USDC, victimBalance) {
            console.log("\n[SECURITY ISSUE] Withdrawal succeeded - this should NOT happen!");
            vm.stopBroadcast();
            revert("CRITICAL: Unauthorized withdrawal was allowed");
        } catch Error(string memory reason) {
            vm.stopBroadcast();
            console.log("\n=== SUCCESS: Withdrawal Blocked ===");
            console.log("Error reason:", reason);
            console.log("[OK] Contract correctly prevented unauthorized withdrawal");
        } catch (bytes memory lowLevelData) {
            vm.stopBroadcast();
            console.log("\n=== SUCCESS: Withdrawal Blocked ===");
            console.log("[OK] Contract correctly prevented unauthorized withdrawal");
            console.log("Low level revert data length:", lowLevelData.length);
        }
    }
}
