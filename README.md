# Foundry NFT项目

这是一个基于Foundry框架开发的NFT生态系统项目，包含了NFT铸造、拍卖、市场交易和代币金库等功能。项目使用Solidity编写，支持以太坊虚拟机(EVM)兼容的区块链网络。
- Sepolia测试网部署地址：https://sepolia.etherscan.io/address/0xc31a683b9a9929589829085fd7cEBE2935C42A7F#code

## 项目结构
projectFoundry/

├── script/ # 部署脚本目录

│ ├── Counter.s.sol # 计数器合约部署脚本

│ ├── NFTAuction.s.sol # NFT拍卖合约部署脚本

│ └── NFThan.s.sol # NFT铸造合约部署脚本

├── src/ # 智能合约源代码目录

│ ├── Counter.sol # 简单计数器合约

│ ├── NFTAuction.sol # NFT拍卖合约

│ ├── NFTMarket.sol # NFT市场合约 

│ ├── NFThan.sol # NFT铸造合约

│ └── TokenVault.sol # 代币金库合约 

├── test/ # 测试合约目录 

│ ├── Counter.t.sol # 计数器合约测试 

│ ├── NFTAuction.t.sol # NFT拍卖合约测试 

│ ├── NFThan.t.sol # NFT铸造合约测试 

│ └── TokenVault.t.sol # 代币金库合约测试 

├── lib/ # 依赖库目录 

├── broadcast/ # 部署记录目录 

├── coverage/ # 代码覆盖率报告目录 

├── foundry.toml # Foundry配置文件 

└── README.md # 项目说明文档


## 功能说明

### 1. NFThan.sol - NFT铸造合约

- **功能**：基础NFT铸造合约，支持创建和管理NFT
- **特点**：
  - 支持自定义NFT名称和符号
  - 最大供应量限制（10000个）
  - 设定铸造价格（0.01 ETH）
  - 铸造时支付费用机制
  - 只有合约拥有者可以修改铸造价格
  - 提供查询总供应量的功能

### 2. NFTAuction.sol - NFT拍卖合约

- **功能**：支持NFT拍卖功能的升级合约
- **特点**：
  - 使用UUPS升级模式
  - 支持ETH和ERC20代币作为支付方式
  - 包含防重入保护
  - 平台手续费机制（默认2.5%）
  - 支持链式价格预言机（Chainlink）
  - 拍卖时间限制和出价验证
  - 完整的拍卖生命周期管理

### 3. NFTMarket.sol - NFT市场合约

- **功能**：支持NFT买卖的去中心化市场
- **特点**：
  - 支持NFT上架销售
  - 版税分配机制（符合ERC2981标准）
  - 平台手续费机制
  - 防重入保护
  - 支持取消上架和修改价格
  - 只有合约拥有者可以修改手续费参数

### 4. TokenVault.sol - 代币金库合约

- **功能**：代币存管服务
- **特点**：
  - 支持多种ERC20代币存取
  - 安全的代币转账机制
  - 用户余额查询功能
  - 使用SafeERC20进行安全转账

## 技术栈

- **开发框架**: Foundry
- **编程语言**: Solidity (版本 0.8.28)
- **EVM版本**: Cancun
- **依赖库**: OpenZeppelin Contracts, Chainlink
- **编译器**: Solc 0.8.28

## 部署步骤

### 环境准备

1. 安装Foundry工具链
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```
2.安装依赖
```bash
cd projectFoundry
forge install
```
## 本地部署
###1.启动本地节点
```bash
anvil
```
### 2.部署合约
```bash
# 部署NFThan合约
forge script script/NFThan.s.sol:NFThanLocalScript --rpc-url http://localhost:8545 --broadcast

# 部署NFTAuction合约
forge script script/NFTAuction.s.sol:NFTAuctionLocalScript --rpc-url http://localhost:8545 --broadcast
```
## 测试网/主网部署
### 1.为部署地址充值足够的ETH用于部署费用
### 2.部署合约
## 部署到Sepolia测试网
```bash
forge script script/NFThan.s.sol:NFThanLocalScript --rpc-url $SEPOLIA_RPC --broadcast --verify

# 部署NFTAuction合约到Sepolia测试网
forge script script/NFTAuction.s.sol:NFTAuctionLocalScript --rpc-url $SEPOLIA_RPC --broadcast --verify
```
## 运行测试
```bash
# 运行所有测试
forge test

# 查看详细输出
forge test -vvv

# 生成代码覆盖率报告
forge coverage
```
## 安全特性
- 防重入保护（Reentrancy Guard）
- 地址零值检查
- 数值范围验证
- 升级合约安全模式（UUPS）
- SafeERC20转账
- 预言机价格验证
