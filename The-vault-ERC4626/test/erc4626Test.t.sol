// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/erc4626.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// mock token
contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract VaultTest is Test {
    
    MockUSDC public usdc;
    ERC4626 public vault;

    address alice = makeAddr("alice");
    address attacker = makeAddr("attacker");

    function setUp() public {
        usdc = new MockUSDC();
        vault = new ERC4626(address(usdc));
    }

    function test_deposit() public {
        // mint
        usdc.mint(alice, 1000);

        // act as alice
        vm.startPrank(alice);

        usdc.approve(address(vault), 1000);
        vault.deposit(1000);

        vm.stopPrank();

        // assertions
        uint256 shares = vault.balanceOf(alice);
        uint256 balanceOfVault = usdc.balanceOf(address(vault));

        assertEq(shares, 1000);
        assertEq(balanceOfVault, 1000);
    }

    function test_withdraw() public {
        usdc.mint(alice, 1000);

        vm.startPrank(alice);

        usdc.approve(address(vault), 1000);
        vault.deposit(1000);

        vault.withdraw(1000);

        vm.stopPrank();

        assertEq(usdc.balanceOf(alice), 1000);
        assertEq(vault.balanceOf(alice), 0);
    }
    function test_multipledespoit() public {
        usdc.mint(alice, 1000);
        usdc.mint(attacker, 1000);

        vm.startPrank(alice);
        usdc.approve(address(vault), 1000);
        vault.deposit(1000);
        vm.stopPrank();

        vm.startPrank(attacker);
        usdc.approve(address(vault), 1000);
        vault.deposit(1000);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), 1000);
        assertEq(vault.balanceOf(attacker), 1000);
    }
    function test_multipledespoitandwithdraw() public {
        usdc.mint(alice, 1000);
        usdc.mint(attacker, 1000);

        vm.startPrank(alice);
        usdc.approve(address(vault), 1000);
        vault.deposit(1000);
        vm.stopPrank();

        vm.startPrank(attacker);
        usdc.approve(address(vault), 1000);
        vault.deposit(1000);
        vm.stopPrank();

        vm.startPrank(alice);
        vault.withdraw(500);
        vm.stopPrank();

        assertEq(usdc.balanceOf(alice), 500);
        assertEq(vault.balanceOf(alice), 500);
    }
    function test_convertAssetToShare() public {
        usdc.mint(alice, 1000);

        vm.startPrank(alice);
        usdc.approve(address(vault), 1000);
        vault.deposit(1000);
        vm.stopPrank();

        uint256 shares = vault.convertAssetToShare(500);
        assertEq(shares, 500);
    }
    function test_convertSharesToAsset() public {
        usdc.mint(alice, 1000);

        vm.startPrank(alice);
        usdc.approve(address(vault), 1000);
        vault.deposit(1000);
        vm.stopPrank();

        uint256 assets = vault.convertSharesToAsset(500);
        assertEq(assets, 500);
    }
    // 1. Test Revert: Zero Deposit
    function test_RevertIf_DepositZero() public {
        vm.startPrank(alice);
        vm.expectRevert("not enough amount");
        vault.deposit(0);
        vm.stopPrank();
    }

    // 2. Test Revert: Zero Withdrawal
    function test_RevertIf_WithdrawZero() public {
        usdc.mint(alice, 1000);
        vm.startPrank(alice);
        usdc.approve(address(vault), 1000);
        vault.deposit(1000);
        
        vm.expectRevert("not enough Shares");
        vault.withdraw(0);
        vm.stopPrank();
    }

    // 3. Test Revert: Excessive Withdrawal
    // This tests the assetToReturn <= asset.balanceOf(address(this)) check
    function test_RevertIf_WithdrawMoreThanVaultHas() public {
        usdc.mint(alice, 1000);
        vm.startPrank(alice);
        usdc.approve(address(vault), 1000);
        vault.deposit(1000);

        // Manually burning shares or trying to withdraw more than available assets
        // Since assetToReturn logic is based on shares, we'll try to withdraw 2000 shares
        vm.expectRevert(); // Should revert on _burn or your custom require
        vault.withdraw(2000);
        vm.stopPrank();
    }

    // 4. Fuzz Testing: Deposit any amount
    function testFuzz_Deposit(uint256 amount) public {
        // Limit amount to avoid realistic overflow or minting issues
        vm.assume(amount > 0 && amount < type(uint128).max);
        
        usdc.mint(alice, amount);
        vm.startPrank(alice);
        usdc.approve(address(vault), amount);
        vault.deposit(amount);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), amount);
        assertEq(vault.totalAsset(), amount);
    }

    // 5. Checking the Offset Logic (Math Consistency)
    function test_OffsetConsistency() public {
        // Your formula: (_amount * (totalSupply + 1e18)) / (totalAsset + 1e18)
        // With 0 supply, it should be (amount * 1e18) / 1e18 = amount
        uint256 expectedShares = vault.convertAssetToShare(500);
        assertEq(expectedShares, 500);
    }
    function test_RevertIf_VaultIsUndercollateralized() public {
    // 1. Alice deposits 1000
    usdc.mint(alice, 1000);
    vm.startPrank(alice);
    usdc.approve(address(vault), 1000);
    vault.deposit(1000);
    vm.stopPrank();

    // 2. Simulate the vault losing funds (e.g., a hack or bad strategy)
    // We force the USDC balance of the vault to drop to 500
    deal(address(usdc), address(vault), 500);

    // 3. Alice tries to withdraw her 1000 shares. 
    // The vault should calculate she's owed ~1000 assets, 
    // but the require will fail because 1000 > 500.
    vm.startPrank(alice);
    vm.expectRevert("not enough asset");
    vault.withdraw(1000);
    vm.stopPrank();
}function test_RevertIf_WithdrawFromEmptyVault() public {
    
    vm.startPrank(alice);
    usdc.mint(alice, 1000);
    usdc.approve(address(vault), 1000);
    vault.deposit(1000);
    
    // Drain the vault's USDC completely without burning shares
    deal(address(usdc), address(vault), 0);
    
    vm.expectRevert("not enough asset");
    vault.withdraw(10); 
    vm.stopPrank();
}function test_RevertIf_AssetReturnIsZero() public {
   
    usdc.mint(alice, 1000);
    vm.startPrank(alice);
    usdc.approve(address(vault), 1000);
    vault.deposit(1000);
    vm.stopPrank();

    
    deal(address(usdc), address(vault), 0);

    vm.startPrank(alice);
    vm.expectRevert("not enough asset");
    vault.withdraw(1000);
    vm.stopPrank();
}
}
