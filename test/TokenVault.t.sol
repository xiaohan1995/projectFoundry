// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/TokenVault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// 创建一个简单的ERC20代币用于测试
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**18); // 铸造100万个代币
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract TokenVaultTest is Test {
    TokenVault public vault;
    MockERC20 public token;
    
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    
    // 声明事件以便在测试中使用
    event Deposit(address indexed user, address indexed token, uint256 amount);
    
    // 在每个测试前执行
    function setUp() public {
        // 部署TokenVault合约
        vault = new TokenVault();
        
        // 部署测试代币
        token = new MockERC20("Test Token", "TEST");
        
        // 给user1和user2分配一些代币
        token.mint(user1, 1000 * 10**18);
        token.mint(user2, 1000 * 10**18);
    }
    
    // 测试存款功能
    function testDeposit() public {
        uint256 depositAmount = 100 * 10**18;
        
        // 切换到user1并授权代币
        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        
        // user1存款
        vault.deposit(address(token), depositAmount);
        vm.stopPrank();
        
        // 验证余额
        assertEq(vault.balances(user1, address(token)), depositAmount);
        
        // 验证代币已转移到合约
        assertEq(token.balanceOf(address(vault)), depositAmount);
        assertEq(token.balanceOf(user1), 900 * 10**18);
    }
    
    // 测试提取功能
    function testWithdraw() public {
        uint256 depositAmount = 100 * 10**18;
        uint256 withdrawAmount = 50 * 10**18;
        
        // 先存款
        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        vault.deposit(address(token), depositAmount);
        vm.stopPrank();
        
        // 再提取
        vm.prank(user1);
        vault.withdraw(address(token), withdrawAmount);
        
        // 验证余额
        assertEq(vault.balances(user1, address(token)), depositAmount - withdrawAmount);
        
        // 验证代币已转回用户
        assertEq(token.balanceOf(user1), 950 * 10**18);
        assertEq(token.balanceOf(address(vault)), 50 * 10**18);
    }
    
    // 测试提取超过余额应该失败
    function testWithdrawInsufficientBalance() public {
        uint256 depositAmount = 100 * 10**18;
        uint256 withdrawAmount = 200 * 10**18;
        
        // 先存款
        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        vault.deposit(address(token), depositAmount);
        vm.stopPrank();
        
        // 尝试提取超过余额的数量，应该失败
        vm.prank(user1);
        vm.expectRevert("TokenVault: insufficient balance");
        vault.withdraw(address(token), withdrawAmount);
    }
    
    // 测试多个用户
    function testMultipleUsers() public {
        uint256 user1Deposit = 100 * 10**18;
        uint256 user2Deposit = 200 * 10**18;
        
        // user1存款
        vm.startPrank(user1);
        token.approve(address(vault), user1Deposit);
        vault.deposit(address(token), user1Deposit);
        vm.stopPrank();
        
        // user2存款
        vm.startPrank(user2);
        token.approve(address(vault), user2Deposit);
        vault.deposit(address(token), user2Deposit);
        vm.stopPrank();
        
        // 验证两个用户的余额
        assertEq(vault.balances(user1, address(token)), user1Deposit);
        assertEq(vault.balances(user2, address(token)), user2Deposit);
        
        // 验证合约总余额
        assertEq(token.balanceOf(address(vault)), user1Deposit + user2Deposit);
    }
    
    // 测试事件
    function testDepositEvent() public {
        uint256 depositAmount = 100 * 10**18;
        
        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        
        // 期望触发Deposit事件
        vm.expectEmit(true, true, false, false);
        emit Deposit(user1, address(token), depositAmount);
        
        vault.deposit(address(token), depositAmount);
        vm.stopPrank();
    }
}