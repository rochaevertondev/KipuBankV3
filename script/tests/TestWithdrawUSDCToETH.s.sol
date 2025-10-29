// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../src/KipuBankV3.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestWithdrawUSDCToETH is Script {
    // Contract address
    address constant BANK = 0xd307e41b2E580302E4c02a35d4ad59899d06b5fa;
    
    // Sepolia addresses
    address constant UNIVERSAL_ROUTER = 0x3A9D48AB9751398BbFa63ad67599Bb04e4BdF98b;
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address constant WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    address constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    
    // V3 Pool: USDC/WETH
    uint24 constant POOL_FEE = 3000;
    
    // V3_SWAP_EXACT_IN command
    bytes1 constant V3_SWAP_EXACT_IN = 0x00;
    // UNWRAP_WETH command  
    bytes1 constant UNWRAP_WETH = 0x0c;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        KipuBank bank = KipuBank(payable(BANK));
        
        console.log("=== Test: Withdraw USDC and Swap to ETH ===");
        console.log("User:", deployer);
        console.log("Bank:", address(bank));
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Check initial balances
        uint256 bankUSDCBefore = bank.getBalanceOf(USDC, deployer);
        
        vm.stopBroadcast();
        
        uint256 ethBalanceBefore = deployer.balance;
        
        console.log("\n=== Initial Balances ===");
        console.log("Bank USDC balance:", bankUSDCBefore / 1e6, "USDC");
        console.log("Wallet ETH:", ethBalanceBefore / 1e18, "ETH");
        
        require(bankUSDCBefore >= 76 * 1e6, "Need at least 76 USDC in bank");

        // Withdraw ~76 USDC and swap to 0.005 ETH
        uint256 usdcToWithdraw = 76 * 1e6; // 76 USDC should give ~0.005 ETH
        
        console.log("\n=== Preparing Swap ===");
        console.log("Withdrawing:", usdcToWithdraw / 1e6, "USDC");
        console.log("Target: 0.005 WETH (wrapped ETH)");
        console.log("Pool: USDC/WETH (0.3% fee)");
        
        // Build V3 swap path: USDC -> WETH
        bytes memory path = abi.encodePacked(
            USDC,           // tokenIn
            POOL_FEE,       // fee (uint24)
            WETH            // tokenOut
        );
        
        console.log("Path length:", path.length, "bytes (should be 43)");
        
        // Build inputs for V3_SWAP_EXACT_IN
        uint256 minWETHOut = 45 * 1e14; // Minimum 0.0045 WETH
        bytes memory swapInputs = abi.encode(
            BANK,               // recipient (BANK receives WETH, then transfers to user)
            usdcToWithdraw,     // amountIn (USDC from bank)
            minWETHOut,         // minAmountOut
            path,               // path
            true                // payerIsUser (true = router pulls from bank via Permit2)
        );
        
        // Only need SWAP command (WETH goes to user as WETH, not ETH)
        bytes memory commands = abi.encodePacked(V3_SWAP_EXACT_IN);
        bytes[] memory inputsArray = new bytes[](1);
        inputsArray[0] = swapInputs;
        
        uint256 deadline = block.timestamp + 300;
        
        console.log("\n=== Executing Withdrawal + Swap to WETH ===");
        console.log("Min WETH out:", minWETHOut / 1e18, "WETH");
        console.log("Deadline:", deadline);

        vm.startBroadcast(deployerPrivateKey);
        
        // Execute withdrawal with swap
        bank.withdrawAndSwap(
            usdcToWithdraw,     // amount to withdraw
            WETH,               // target token (WETH)
            commands,
            inputsArray,
            minWETHOut,
            deadline
        );
        
        // Check final balances (before stopBroadcast)
        uint256 bankUSDCAfter = bank.getBalanceOf(USDC, deployer);
        uint256 totalBankUsd = bank.totalBankUsd();
        
        vm.stopBroadcast();
        
        uint256 ethBalanceAfter = deployer.balance;
        uint256 wethBalance = IERC20(WETH).balanceOf(deployer);
        
        console.log("\n=== Transaction Complete ===");
        
        console.log("\n=== Final Balances ===");
        console.log("Bank USDC balance:", bankUSDCAfter / 1e6, "USDC");
        console.log("Wallet ETH:", ethBalanceAfter / 1e18, "ETH");
        console.log("Wallet WETH:", wethBalance / 1e18, "WETH");
        
        // Verify
        console.log("\n=== Verification ===");
        console.log("USDC withdrawn:", usdcToWithdraw / 1e6, "USDC");
        console.log("WETH received:", wethBalance / 1e18, "WETH");
        console.log("Bank USDC remaining:", bankUSDCAfter / 1e6, "USDC");
        console.log("Total Bank USD:", totalBankUsd / 1e8, "USD");
        
        console.log("\n=== SUCCESS ===");
        console.log("User can unwrap WETH to ETH manually if desired");
    }
}
