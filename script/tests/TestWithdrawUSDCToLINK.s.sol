// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../src/KipuBankV3.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestWithdrawUSDCToLINK is Script {
    // Contract address
    address constant BANK = 0xd307e41b2E580302E4c02a35d4ad59899d06b5fa;
    
    // Sepolia addresses
    address constant UNIVERSAL_ROUTER = 0x3A9D48AB9751398BbFa63ad67599Bb04e4BdF98b;
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address constant LINK = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    
    // V3 Pool: USDC/LINK (reverse of deposit)
    address constant POOL_LINK_USDC = 0x2d021e62D1aE41946846462d4bD8A85BB3d49C2c;
    uint24 constant POOL_FEE = 3000;
    
    // V3_SWAP_EXACT_IN command
    bytes1 constant V3_SWAP_EXACT_IN = 0x00;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        KipuBank bank = KipuBank(payable(BANK));
        
        console.log("=== Test: Withdraw USDC and Swap to LINK ===");
        console.log("User:", deployer);
        console.log("Bank:", address(bank));
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Check initial balances
        uint256 bankUSDCBefore = bank.getBalanceOf(USDC, deployer);
        
        vm.stopBroadcast();
        
        uint256 linkWalletBefore = IERC20(LINK).balanceOf(deployer);
        
        console.log("\n=== Initial Balances ===");
        console.log("Bank USDC balance:", bankUSDCBefore / 1e6, "USDC");
        console.log("Wallet LINK:", linkWalletBefore / 1e18, "LINK");
        
        require(bankUSDCBefore >= 32 * 1e6, "Need at least 32 USDC in bank");

        // Withdraw ~32 USDC and swap to 4 LINK
        uint256 usdcToWithdraw = 32 * 1e6; // 32 USDC should give ~4 LINK
        
        console.log("\n=== Preparing Swap ===");
        console.log("Withdrawing:", usdcToWithdraw / 1e6, "USDC");
        console.log("Target token: 4 LINK");
        console.log("Pool: USDC/LINK (0.3% fee)");
        
        // Build V3 swap path: USDC -> LINK
        bytes memory path = abi.encodePacked(
            USDC,           // tokenIn
            POOL_FEE,       // fee (uint24)
            LINK            // tokenOut
        );
        
        console.log("Path length:", path.length, "bytes (should be 43)");
        
        // Build inputs for V3_SWAP_EXACT_IN
        uint256 minLINKOut = 35 * 1e17; // Minimum 3.5 LINK
        bytes memory inputs = abi.encode(
            BANK,               // recipient (BANK receives LINK, then transfers to user)
            usdcToWithdraw,     // amountIn (USDC from bank)
            minLINKOut,         // minAmountOut
            path,               // path
            true                // payerIsUser (true = router pulls from bank via Permit2)
        );
        
        bytes memory commands = abi.encodePacked(V3_SWAP_EXACT_IN);
        bytes[] memory inputsArray = new bytes[](1);
        inputsArray[0] = inputs;
        
        uint256 deadline = block.timestamp + 300;
        
        console.log("\n=== Executing Withdrawal + Swap ===");
        console.log("Min LINK out:", minLINKOut / 1e18, "LINK");
        console.log("Deadline:", deadline);

        vm.startBroadcast(deployerPrivateKey);
        
        // Execute withdrawal with swap
        bank.withdrawAndSwap(
            usdcToWithdraw,     // amount to withdraw
            LINK,               // target token (to receive)
            commands,
            inputsArray,
            minLINKOut,
            deadline
        );
        
        // Check final balances (before stopBroadcast)
        uint256 bankUSDCAfter = bank.getBalanceOf(USDC, deployer);
        
        vm.stopBroadcast();
        
        uint256 linkWalletAfter = IERC20(LINK).balanceOf(deployer);
        
        console.log("\n=== Transaction Complete ===");
        
        console.log("\n=== Final Balances ===");
        console.log("Bank USDC balance:", bankUSDCAfter / 1e6, "USDC");
        console.log("Wallet LINK:", linkWalletAfter / 1e18, "LINK");
        console.log("LINK received:", (linkWalletAfter - linkWalletBefore) / 1e18, "LINK");
        
        // Verify
        console.log("\n=== Verification ===");
        console.log("USDC withdrawn:", usdcToWithdraw / 1e6, "USDC");
        console.log("LINK received:", (linkWalletAfter - linkWalletBefore) / 1e18, "LINK");
        console.log("Bank USDC remaining:", bankUSDCAfter / 1e6, "USDC");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Check total bank USD
        uint256 totalBankUSD = bank.totalBankUsd();
        
        vm.stopBroadcast();
        
        console.log("Total Bank USD (8 decimals):", totalBankUSD / 1e8, "USD");
        
        console.log("\n=== SUCCESS ===");
    }
}
