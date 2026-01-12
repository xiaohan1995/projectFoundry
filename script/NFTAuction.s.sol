// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {NFTAuction} from "../src/NFTAuction.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract NFTAuctionLocalScript is Script {
    NFTAuction public nftAuctionImpl;
    ProxyAdmin public proxyAdmin;
    TransparentUpgradeableProxy public nftAuctionProxy;
    NFTAuction public nftAuction;

    function run() public {
        // 从环境变量获取私钥，如果没有设置则使用anvil默认私钥
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployerAddress = vm.addr(deployerPrivateKey);
        
        // 设置平台手续费接收者地址（可以是部署者的地址或指定的钱包地址）
        address feeReceiver = vm.envOr("FEE_RECEIVER", deployerAddress);
        
        // 为部署者账户注资（仅在本地测试网络有效）
        vm.deal(deployerAddress, 100 ether);
        
        console.log("Deploying NFTAuction contract...");
        console.log("Deployer address:", deployerAddress);
        console.log("Fee receiver address:", feeReceiver);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 部署合约实现
        nftAuctionImpl = new NFTAuction();
        
        // 部署ProxyAdmin
        proxyAdmin = new ProxyAdmin(deployerAddress);
        
        // 部署代理合约
        nftAuctionProxy = new TransparentUpgradeableProxy(
            address(nftAuctionImpl),
            address(proxyAdmin),
            ""
        );
        
        // 将代理合约转换为NFTAuction实例
        nftAuction = NFTAuction(address(nftAuctionProxy));
        
        // 初始化合约
        nftAuction.initialize(feeReceiver);
        
        vm.stopBroadcast();
        
        // 打印部署成功的合约地址
        console.log("NFTAuction implementation deployed to:", address(nftAuctionImpl));
        console.log("Proxy Admin deployed to:", address(proxyAdmin));
        console.log("NFTAuction proxy deployed to:", address(nftAuctionProxy));
        console.log("Initialized NFTAuction address:", address(nftAuction));
        console.log("Deployment completed successfully!");
    }
}