// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../src/KipuBankV3.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestDepositETHToUSDC is Script {
    // Contract address
    address constant BANK = 0xd307e41b2E580302E4c02a35d4ad59899d06b5fa;
    
    // Sepolia addresses
    address constant UNIVERSAL_ROUTER = 0x3A9D48AB9751398BbFa63ad67599Bb04e4BdF98b;
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address constant WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    address constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    
    // V3 Pool: WETH/USDC 0.3% fee
    address constant POOL_WETH_USDC = 0x6Ce0896eAE6D4BD668fDe41BB784548fb8F59b50;
    uint24 constant POOL_FEE = 3000;
    
    // V3_SWAP_EXACT_IN command
    bytes1 constant V3_SWAP_EXACT_IN = 0x00;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        KipuBank bank = KipuBank(payable(BANK));
        
        console.log("=== Test: Deposit ETH and Swap to USDC ===");
        console.log("User:", deployer);
        console.log("Bank:", address(bank));
        
        // Check initial balances
        uint256 ethBalanceBefore = deployer.balance;
        uint256 usdcBalanceBefore = IERC20(USDC).balanceOf(deployer);
        
        console.log("\n=== Initial Balances ===");
        console.log("ETH:", ethBalanceBefore / 1e18, "ETH");
        console.log("USDC:", usdcBalanceBefore / 1e6, "USDC");
        
        try bank.getBalanceOf(USDC, deployer) returns (uint256 bankBal) {
            console.log("Bank USDC balance:", bankBal / 1e6, "USDC");
        } catch {
            console.log("Bank USDC balance: 0 USDC (first deposit)");
        }

        // Deposit amount
        uint256 ethToDeposit = 0.01 ether;
        
        console.log("\n=== Preparing Swap ===");
        console.log("Depositing:", ethToDeposit / 1e18, "ETH");
        console.log("Target token: USDC");
        console.log("Pool: WETH/USDC (0.3% fee)");
        
        // Build V3 swap path: WETH -> USDC
        bytes memory path = abi.encodePacked(
            WETH,           // tokenIn
            POOL_FEE,       // fee (uint24)
            USDC            // tokenOut
        );
        
        console.log("Path length:", path.length, "bytes (should be 43)");
        
        // Build inputs for V3_SWAP_EXACT_IN
        // Format: (address recipient, uint256 amountIn, uint256 minAmountOut, bytes path, bool payerIsUser)
        uint256 minUSDCOut = 1 * 1e6; // Minimum 1 USDC (adjust based on market)
        bytes memory inputs = abi.encode(
            BANK,               // recipient (bank contract receives USDC)
            ethToDeposit,       // amountIn (WETH amount)
            minUSDCOut,         // minAmountOut
            path,               // path
            true                // payerIsUser (true = router pulls from msg.sender via Permit2)
        );
        
        bytes memory commands = abi.encodePacked(V3_SWAP_EXACT_IN);
        bytes[] memory inputsArray = new bytes[](1);
        inputsArray[0] = inputs;
        
        uint256 deadline = block.timestamp + 300; // 5 minutes
        
        console.log("\n=== Executing Swap ===");
        console.log("Min USDC out:", minUSDCOut / 1e6, "USDC");
        console.log("Deadline:", deadline);

        vm.startBroadcast(deployerPrivateKey);
        
        // Execute deposit with swap
        bank.depositETHAndSwap{value: ethToDeposit}(
            commands,
            inputsArray,
            minUSDCOut,
            deadline
        );
        
        vm.stopBroadcast();
        
        console.log("\n=== Transaction Complete ===");
        
        // Check final balances
        uint256 ethBalanceAfter = deployer.balance;
        uint256 usdcBalanceAfter = IERC20(USDC).balanceOf(deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        uint256 bankUSDCBalance = bank.getBalanceOf(USDC, deployer);
        vm.stopBroadcast();
        
        console.log("\n=== Final Balances ===");
        console.log("ETH spent:", (ethBalanceBefore - ethBalanceAfter) / 1e18, "ETH");
        console.log("Wallet USDC:", usdcBalanceAfter / 1e6, "USDC (should be unchanged)");
        console.log("Bank USDC balance:", bankUSDCBalance / 1e6, "USDC");
        
        // Verify USDC credited to bank
        console.log("\n=== Verification ===");
        console.log("USDC credited to bank:", bankUSDCBalance / 1e6, "USDC");
        console.log("ETH deposited:", ethToDeposit / 1e18, "ETH");
        
        // Check total bank USD
        uint256 totalBankUSD = bank.totalBankUsd();
        console.log("Total Bank USD (8 decimals):", totalBankUSD / 1e8, "USD");
        
        console.log("\n=== SUCCESS ===");
    }
}
