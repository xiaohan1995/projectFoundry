// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
* @title NFThan
* @dev 一个完整的NFT合约，支持铸造、元数据管理、授权、查询、供应量控制
* @author Shawn Hans
* @notice 使用openzeppelin库，继承了ERC721和ERC721URIStorage，实现了NFT的铸造、元数据管理、授权、查询、供应量控制等功能
*/

contract NFThan is  ERC721URIStorage, Ownable { 

    // token Id 的计数器
    uint private _tokenIdCounter;

    // toekn供应量
    uint public constant MAX_SUPPLY = 10000;

    // 铸造价格
    uint public MINT_PRICE = 0.01 ether;

    //修饰符检验
    modifier notAddressZero(address _address) {
        require(_address != address(0), "Address cannot be zero");
        _;
    }

    //事件
    //铸币事件
    event Mint(address indexed minter, uint indexed tokenId , string uri);
    //取款事件
    event Withdraw(address indexed withdrawer, uint amount);

    /**
    * @dev 构造函数，继承了ERC721和ERC721URIStorage的构造函数
    * @param name NFT的名称
    * @param symbol NFT的符号
    */
    constructor(string memory name, string memory symbol) ERC721(name, symbol) Ownable(msg.sender) {}

    /**
    * @dev 铸造NFT
    * @param uri NFT的元数据URI
    * @return tokenId 铸造的NFT的ID
    * @notice 铸造NFT时，会支付铸造价格，并返回铸造的NFT的ID
    */

    function mint(
        string memory uri
    )
        public 
        payable
        notAddressZero(msg.sender)
        returns (uint)
    { 
        // 检查供应量
        require(_tokenIdCounter < MAX_SUPPLY, "Supply exceeded");
        //检查铸造费
        require(msg.value >= MINT_PRICE, "Insufficient payment");
        //检查uri
        require(bytes(uri).length > 0, "URI cannot be empty");

        //生成tokenId
        _tokenIdCounter++;
        uint tokenId = _tokenIdCounter;
        //铸造NFT
        _safeMint(msg.sender, tokenId);
        //设置元数据
        _setTokenURI(tokenId, uri);
        //触发铸造事件
        emit Mint(msg.sender, tokenId, uri);
        return tokenId;
    }

    /**
    * @dev 查询当前铸造量
    * @return uint 当前铸造量
    */
    function totalSupply() public view returns (uint) {
        return _tokenIdCounter;
    }

    /**
    * @dev 修改铸造费
    * @param newPrice 新的铸造费
    * @notice 只有合约拥有者才能修改铸造费
    */
    function setMintPrice(uint newPrice) public onlyOwner {
        require(newPrice != MINT_PRICE, "New price is the same as the current price");
        require(newPrice > 0, "Price cannot be zero");
        MINT_PRICE = newPrice;
    }

    /**
    * @dev 提取铸造费
    * @notice 只有合约拥有者才能提取铸造费
     */
     function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        emit Withdraw(msg.sender, balance);
        (bool successWithdraw,) = payable(owner()).call{value: balance}("");
        require(successWithdraw,"Withdraw failed");
    }

    /**
    * @dev 重写tokenURI函数
    * @param tokenId NFT的ID
    * @return string NFT的元数据URI
    * @notice 需要重写解决继承问题
    */
    function tokenURI(uint tokenId)
        public
        view
        override(ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
    /**
    * @dev 重写supportsInterface函数
    * @param interfaceId 接口ID
    * @return bool 是否支持该接口
    * @notice 需要重写解决继承问题
    */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }


}
