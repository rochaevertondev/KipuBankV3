// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../src/KipuBankV3.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestDepositLINKToUSDC is Script {
    // Contract address
    address constant BANK = 0xd307e41b2E580302E4c02a35d4ad59899d06b5fa;
    
    // Sepolia addresses
    address constant UNIVERSAL_ROUTER = 0x3A9D48AB9751398BbFa63ad67599Bb04e4BdF98b;
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address constant LINK = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    
    // V3 Pool: LINK/USDC 0.3% fee
    address constant POOL_LINK_USDC = 0x2d021e62D1aE41946846462d4bD8A85BB3d49C2c;
    uint24 constant POOL_FEE = 3000;
    
    // V3_SWAP_EXACT_IN command
    bytes1 constant V3_SWAP_EXACT_IN = 0x00;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        KipuBank bank = KipuBank(payable(BANK));
        
        console.log("=== Test: Deposit LINK and Swap to USDC ===");
        console.log("User:", deployer);
        console.log("Bank:", address(bank));
        
        // Check initial balances
        uint256 linkBalanceBefore = IERC20(LINK).balanceOf(deployer);
        uint256 usdcBalanceBefore = IERC20(USDC).balanceOf(deployer);
        
        console.log("\n=== Initial Balances ===");
        console.log("Wallet LINK:", linkBalanceBefore / 1e18, "LINK");
        console.log("Wallet USDC:", usdcBalanceBefore / 1e6, "USDC");
        
        try bank.getBalanceOf(USDC, deployer) returns (uint256 bankBal) {
            console.log("Bank USDC balance:", bankBal / 1e6, "USDC");
        } catch {
            console.log("Bank USDC balance: 0 USDC");
        }

        // Deposit amount
        uint256 linkToDeposit = 1 * 1e18; // 1 LINK
        
        require(linkBalanceBefore >= linkToDeposit, "Insufficient LINK balance");
        
        console.log("\n=== Preparing Swap ===");
        console.log("Depositing:", linkToDeposit / 1e18, "LINK");
        console.log("Target token: USDC");
        console.log("Pool: LINK/USDC (0.3% fee)");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Approve LINK to bank contract
        console.log("\n=== Step 1: Approve LINK ===");
        IERC20(LINK).approve(address(bank), linkToDeposit);
        console.log("LINK approved to bank:", linkToDeposit / 1e18, "LINK");
        
        vm.stopBroadcast();
        
        // Build V3 swap path: LINK -> USDC
        bytes memory path = abi.encodePacked(
            LINK,           // tokenIn
            POOL_FEE,       // fee (uint24)
            USDC            // tokenOut
        );
        
        console.log("Path length:", path.length, "bytes (should be 43)");
        
        // Build inputs for V3_SWAP_EXACT_IN
        uint256 minUSDCOut = 5 * 1e6; // Minimum 5 USDC (adjust based on LINK price)
        bytes memory inputs = abi.encode(
            address(bank),      // recipient (contract receives USDC)
            linkToDeposit,      // amountIn
            minUSDCOut,         // minAmountOut
            path,               // path
            true                // payerIsUser (true = router pulls from bank via Permit2)
        );
        
        bytes memory commands = abi.encodePacked(V3_SWAP_EXACT_IN);
        bytes[] memory inputsArray = new bytes[](1);
        inputsArray[0] = inputs;
        
        uint256 deadline = block.timestamp + 300;
        
        console.log("\n=== Step 2: Executing Swap ===");
        console.log("Min USDC out:", minUSDCOut / 1e6, "USDC");
        console.log("Deadline:", deadline);

        vm.startBroadcast(deployerPrivateKey);
        
        // Execute deposit with swap
        bank.depositTokenAndSwap(
            LINK,
            linkToDeposit,
            commands,
            inputsArray,
            minUSDCOut,
            deadline
        );
        
        
        console.log("\n=== Transaction Complete ===");
        
        // Check final balances (need to stay in broadcast for getBalanceOf)
        uint256 bankUSDCBalance = bank.getBalanceOf(USDC, deployer);
        
        vm.stopBroadcast();
        
        uint256 linkBalanceAfter = IERC20(LINK).balanceOf(deployer);
        uint256 usdcBalanceAfter = IERC20(USDC).balanceOf(deployer);
        
        console.log("\n=== Final Balances ===");
        console.log("Wallet LINK:", linkBalanceAfter / 1e18, "LINK");
        console.log("LINK spent:", (linkBalanceBefore - linkBalanceAfter) / 1e18, "LINK");
        console.log("Wallet USDC:", usdcBalanceAfter / 1e6, "USDC (should be unchanged)");
        console.log("Bank USDC balance:", bankUSDCBalance / 1e6, "USDC");
        
        // Verify
        console.log("\n=== Verification ===");
        console.log("USDC credited to bank:", bankUSDCBalance / 1e6, "USDC");
        console.log("LINK deposited:", linkToDeposit / 1e18, "LINK");
        
        // Check total bank USD
        uint256 totalBankUSD = bank.totalBankUsd();
        console.log("Total Bank USD (8 decimals):", totalBankUSD / 1e8, "USD");
        
        console.log("\n=== SUCCESS ===");
    }
}
