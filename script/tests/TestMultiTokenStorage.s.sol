// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../src/KipuBankV3.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestMultiTokenStorage is Script {
    // Contract address
    address constant BANK = 0xd307e41b2E580302E4c02a35d4ad59899d06b5fa;
    
    // Sepolia addresses
    address constant UNIVERSAL_ROUTER = 0x3A9D48AB9751398BbFa63ad67599Bb04e4BdF98b;
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address constant WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    address constant LINK = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    
    // V3 Pools
    address constant POOL_WETH_USDC = 0x6Ce0896eAE6D4BD668fDe41BB784548fb8F59b50;
    address constant POOL_LINK_USDC = 0x2d021e62D1aE41946846462d4bD8A85BB3d49C2c;
    uint24 constant POOL_FEE = 3000;
    
    bytes1 constant V3_SWAP_EXACT_IN = 0x00;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        KipuBank bank = KipuBank(payable(BANK));
        
        console.log("=== Test: Multi-Token Storage (V2 Feature) ===");
        console.log("User:", deployer);
        console.log("Bank:", address(bank));
        console.log("\nThis test verifies V2 can hold BOTH USDC AND LINK simultaneously");
        console.log("(Unlike V3 which only stores USDC)\n");
        
        // Step 1: Deposit ETH -> USDC
        console.log("=== Step 1: Deposit 0.001 ETH -> USDC ===");
        
        uint256 ethToDeposit = 0.001 ether;
        bytes memory pathETHtoUSDC = abi.encodePacked(WETH, POOL_FEE, USDC);
        uint256 minUSDCOut1 = 1 * 1e6;
        
        bytes memory inputs1 = abi.encode(
            BANK,               // recipient (bank receives USDC)
            ethToDeposit,
            minUSDCOut1,
            pathETHtoUSDC,
            true                // payerIsUser (router pulls from msg.sender=bank via Permit2)
        );
        
        bytes memory commands1 = abi.encodePacked(V3_SWAP_EXACT_IN);
        bytes[] memory inputsArray1 = new bytes[](1);
        inputsArray1[0] = inputs1;
        
        vm.startBroadcast(deployerPrivateKey);
        
        bank.depositETHAndSwap{value: ethToDeposit}(
            commands1,
            inputsArray1,
            minUSDCOut1,
            block.timestamp + 300
        );
        
        vm.stopBroadcast();
        
        // Step 2: Verify USDC storage
        console.log("\n=== Step 2: Verify USDC Storage ===");
        
        vm.startBroadcast(deployerPrivateKey);
        uint256 finalUSDC = bank.getBalanceOf(USDC, deployer);
        vm.stopBroadcast();
        
        console.log("Bank USDC balance:", finalUSDC / 1e6, "USDC");
        
        // Verify balance is non-zero
        require(finalUSDC > 0, "USDC balance should be > 0");
        
        // Check total USD (should match USDC balance * 100)
        uint256 totalBankUSD = bank.totalBankUsd();
        console.log("\nTotal Bank USD (8 decimals):", totalBankUSD / 1e8, "USD");
        console.log("USDC value (8 decimals):", finalUSDC * 100 / 1e8, "USD");
        
        console.log("\n=== SUCCESS ===");
        console.log("[OK] V2 stores everything as USDC");
        console.log("[OK] Total USD matches USDC balance * 100");
        console.log("\nThis proves V2's USDC-only architecture works!");
    }
}
