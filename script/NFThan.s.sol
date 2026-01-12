// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {NFThan} from "../src/NFThan.sol";

contract NFThanLocalScript is Script {
    NFThan public nfthan;

    function run() public {
        // 使用字符串方式读取私钥
        string memory privateKeyStr = vm.envString("PRIVATE_KEY");
        console.log("Loaded private key string length:", bytes(privateKeyStr).length);
        
        // 检查私钥是否以 0x 开头，如果不是则添加
        bytes memory pkBytes = bytes(privateKeyStr);
        if (pkBytes.length == 64) { // 没有 0x 前缀的 64 字符十六进制
            privateKeyStr = string(abi.encodePacked("0x", privateKeyStr));
        }
        
        // 由于 Forge Std 不支持 parseHexUint，我们使用 try-catch 来处理
        uint256 deployerPrivateKey;
        try vm.envUint("PRIVATE_KEY") returns (uint256 key) {
            deployerPrivateKey = key;
        } catch {
            // 如果直接转换失败，尝试手动处理
            // 在这种情况下，最简单的办法是确保 .env 文件中的 PRIVATE_KEY 有 0x 前缀
            console.log("Failed to parse private key from environment. Make sure your .env PRIVATE_KEY starts with 0x");
            return;
        }
        
        address deployerAddress = vm.addr(deployerPrivateKey);
        
        console.log("Private key loaded successfully from environment");
        console.log("Deployer address:", deployerAddress);
        console.log("Deployer balance:", deployerAddress.balance);
        
        // 检查是否在目标网络上余额不足
        if (deployerAddress.balance == 0) {
            console.log("ERROR: Deployer address has 0 balance.");
            console.log("Your private key corresponds to address: %s", deployerAddress);
            console.log("Make sure this address has ETH on the Sepolia testnet.");
            console.log("Get Sepolia ETH from a faucet: https://sepoliafaucet.com/ or https://faucet.sepolia.dev/");
            return; // 提前退出以避免失败
        }
        
        console.log("Deploying NFThan contract...");
        
        vm.startBroadcast(deployerPrivateKey);
        
        nfthan = new NFThan("NFThan", "HNFT");
        
        vm.stopBroadcast();
        
        // 打印部署成功的合约地址
        console.log("NFThan deployed to:", address(nfthan));
        console.log("Deployment completed successfully!");
    }
}