// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TokenVault {
    using SafeERC20 for IERC20;
    
    // 存储每个用户对每种代币的余额
    mapping(address => mapping(address => uint256)) public balances;
    
    // 事件：存款
    event Deposit(address indexed user, address indexed token, uint256 amount);
    
    // 事件：提取
    event Withdraw(address indexed user, address indexed token, uint256 amount);
    
    /**
     * @dev 存入代币
     * @param token 代币合约地址
     * @param amount 存入数量
     */
    function deposit(address token, uint256 amount) external {
        require(token != address(0), "TokenVault: invalid token address");
        require(amount > 0, "TokenVault: amount must be greater than 0");
        
        // 从用户账户转移代币到合约
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        // 更新用户余额
        balances[msg.sender][token] += amount;
        
        // 触发事件
        emit Deposit(msg.sender, token, amount);
    }
    
    /**
     * @dev 提取代币
     * @param token 代币合约地址
     * @param amount 提取数量
     */
    function withdraw(address token, uint256 amount) external {
        require(token != address(0), "TokenVault: invalid token address");
        require(amount > 0, "TokenVault: amount must be greater than 0");
        require(
            balances[msg.sender][token] >= amount,
            "TokenVault: insufficient balance"
        );
        
        // 更新用户余额
        balances[msg.sender][token] -= amount;
        
        // 从合约转移代币到用户账户
        IERC20(token).safeTransfer(msg.sender, amount);
        
        // 触发事件
        emit Withdraw(msg.sender, token, amount);
    }
    
    /**
     * @dev 查询用户余额
     * @param user 用户地址
     * @param token 代币合约地址
     * @return 用户余额
     */
    function getBalance(address user, address token) external view returns (uint256) {
        return balances[user][token];
    }
}