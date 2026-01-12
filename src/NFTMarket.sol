// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";// 防重入保护
import "@openzeppelin/contracts/access/Ownable.sol";// 合约拥有者

/**
* @title IERC2981
* @dev ERC2981 版税标准接口
*/
interface IERC2981 is IERC165 {
    /**
    * @dev 获取版税信息
    * @param tokenId NFT的ID
    * @param salePrice 售出价格
    * @return receiver 版税接收者
    * @return royaltyAmount 版税金额
    */
    function royaltyInfo(
        uint256 tokenId, 
        uint256 salePrice
        )
        external
        view
        returns (
            address receiver, 
            uint256 royaltyAmount
        );
}

/**
* @title NFTMarket
* @dev NFT市场合约,包含上架、购买、版税功能
* @notice NFTMarket 合约继承了ERC721和ERC2981标准;使用ReentrancyGuard 防重入保护
* @author Shawn Hans
*/

contract NFTMarket is ReentrancyGuard, Ownable{ 
    //挂单
    struct Listing{
        address seller;//卖家地址
        address nftContract;//NFT合约地址
        uint tokenId;//NFT的ID
        uint price;//售出价格(wei)
        bool active;//是否激活
    }


    //挂单列表
    mapping(uint => Listing) public listings;
    uint public listingCount;

    uint public feeContract = 250;//2.5% 合约手续费
    address public feeReceiver;//手续费接收者


    //修饰符验证
    modifier notZeroAddress(address _address){
        require(_address != address(0), "Invalid address");
        _;
    }

    modifier notZeroNum(uint _num){
        require(_num != 0, "Invalid number");
        _;
    }

    /************************事件定义start***********************/
    //挂单事件
    event ListingCreated(
        uint indexed listingId,
        uint indexed tokenId,
        address indexed seller,
        address nftContract,
        uint price
    );
    //下架挂单
    event ListingCancelled(
        uint indexed listingId,
        uint indexed tokenId,
        address indexed seller,
        address nftContract
    );
    //修改挂单价格
    event ListingPriceChanged(
        uint indexed listingId,
        uint indexed tokenId,
        address indexed seller,
        address nftContract,
        uint oldPrice,
        uint newPrice
    );
    //购买NFT事件
    event NFTBought(
        uint indexed listingId,
        uint indexed tokenId,
        address indexed buyer,
        address nftContract,
        uint price
    );
    //版税支付事件
    event RoyaltyPaid(
        uint indexed listingId,
        uint indexed tokenId,
        address indexed royaltyAddress,
        address nftContract,
        uint royaltyAmount
    );
    //多余资金退还事件
    event FundsReturned(
        uint indexed listingId,
        uint indexed tokenId,
        address indexed buyer,
        address nftContract,
        uint amount
    );
    //提取手续费事件
    event FeeWithdrawn(
        address indexed _feeReceiver,
        uint indexed amount,
        uint indexed timestamp
    );
    //修改提取手续费地址事件
    event FeeReceiverChanged(
        address indexed _oldFeeReceiver,
        address indexed _newFeeReceiver,
        uint indexed timestamp
    );
    /***************************事件定义end*********************/

    //构造函数
    constructor(address _feeReceiver)
        Ownable(msg.sender)
    {
        require(_feeReceiver != address(0), "Invalid address");
        feeReceiver = _feeReceiver;//设置手续费接收者
    }

    /**
    * @dev 创建挂单
    * @param _nftContract NFT合约地址
    * @param _tokenId NFT的ID
    * @param _price 售出价格(wei)
    * @notice 只有NFT的拥有者才能创建挂单
    * @return uint 挂单ID
    */

    function createListing(
        address _nftContract,
        uint _tokenId,
        uint _price
    )
        public
        notZeroAddress(_nftContract)
        notZeroNum(_price)
        returns (uint)
    { 
        IERC721 _nft = IERC721(_nftContract);
        //验证NFT的拥有者
        require(
            _nft.ownerOf(_tokenId) == msg.sender,
            "Not owner"
        );
        //验证是否授权
        require(
            _nft.getApproved(_tokenId) == address(this) ||
            _nft.isApprovedForAll(msg.sender, address(this)),
            "Not approved"
        );
        listingCount++;//挂单ID自增
        //构建挂单结构体
        listings[listingCount] = Listing(
            msg.sender,
            _nftContract,
            _tokenId,
            _price,
            true
        );
        //触发挂单事件
        emit ListingCreated(
            listingCount,
            _tokenId,
            msg.sender,
            _nftContract,
            _price
        );
        return listingCount;
    }

    /**
    * @dev 获取挂单信息
    * @param _listingId 挂单ID
    * @return Listing 挂单结构体
    */
    function _getListing(uint _listingId)
        internal
        view
        notZeroNum(_listingId)
        returns (Listing storage)
    {
        return listings[_listingId];
    }

    /**
    * @dev 下架挂单
    * @param _listingId 挂单ID
    * @notice 只有挂单的卖家才能下架挂单
    */

    function cnacelListing(uint _listingId)
        external
    {
        Listing storage listing = _getListing(_listingId);
        //验证是否是卖家
        require(
            listing.seller == msg.sender,
            "you are not the seller"
        );
        //验证是否是激活的
        require(
            listing.active,
            "listing is not active"
        );
        //触发下架挂单事件
        emit ListingCancelled(
            _listingId,
            listing.tokenId,
            listing.seller,
            listing.nftContract
        );
        listing.active = false;
        
    }

    /**
    * @dev 修改挂单价格
    * @param _listingId 挂单ID
    * @param _newPrice 新价格(wei)
    * @notice 只有挂单的卖家才能修改挂单价格
    */
    
    function changedPrice(
        uint _listingId,
        uint _newPrice
    )
        external
        notZeroNum(_newPrice)
    {
        Listing storage listing = _getListing(_listingId);
        //验证是否是卖家
        require(
            listing.seller == msg.sender,
            "you are not the seller"
        );
        //验证是否激活状态
        require(
            listing.active,
            "listing is not active"
        );
        //新价格不能和旧价格相同
        require(
            _newPrice != listing.price,
            "new price is same as old price"
        );
        //触发修改价格事件
        emit ListingPriceChanged(
            _listingId,
            listing.tokenId,
            listing.seller,
            listing.nftContract,
            listing.price,
            _newPrice
        );
        listing.price = _newPrice;
    }

    /**
    * @dev 购买NFT
    * @param _listingId 挂单ID
    * @notice 购买NFT时需要支付价格
    */

    function buyNFT(uint _listingId)
        external
        payable
        nonReentrant
    { 
        Listing storage listing = _getListing(_listingId);
        //验证是否激活状态
        require(
            listing.active,
            "listing is not active"
        );
        //验证价格是否足够
        require(
            listing.price<=msg.value,
            "Insufficient payment"
        );
        //是否是卖家购买自己的NFT
        require(
            msg.sender != listing.seller,
            "you are the seller"
        );
        //计算手续费
        uint fee = (listing.price * feeContract) / 10000;
        //获取版税信息
        (address royaltyReceiver, uint256 royaltyAmount) = _getRoyaltyInfo(
            listing.nftContract,
            listing.tokenId,
            listing.price
        );
        //计算卖家收益
        uint sellerProfit = listing.price - fee - royaltyAmount;

        //转移NFT
        IERC721 _nft = IERC721(listing.nftContract);
        _nft.safeTransferFrom(
            listing.seller,
            msg.sender,
            listing.tokenId
        );
        //分配资金：版税->手续费->卖家
        if(royaltyAmount>0 && royaltyReceiver!=address(0)){
            (bool successRoyalty, ) = payable(royaltyReceiver).call{value: royaltyAmount}("");
            require(
                successRoyalty,
                "royalty transfer failed"
            );
            //触发版税支付事件
            emit RoyaltyPaid(
                _listingId,
                listing.tokenId,
                royaltyReceiver,
                listing.nftContract,
                royaltyAmount
            );
        }
        
        (bool successFee, ) = payable(feeReceiver).call{value: fee}("");
        require(
            successFee,
            "fee transfer failed"
        );

        (bool successSeller, ) = payable(listing.seller).call{value: sellerProfit}("");
        require(
            successSeller,
            "seller transfer failed"
        );
        //如果支付金额大于价格退还多余资金
        if(msg.value>listing.price){
            (bool successRefund, ) = payable(msg.sender).call{value: msg.value - listing.price}("");
            require(
                successRefund,
                "refund transfer failed"
            );
            //触发退回多余资金事件
            emit FundsReturned(
                _listingId,
                listing.tokenId,
                msg.sender,
                listing.nftContract,
                msg.value - listing.price
            );
        }
        //触发购买NFT事件
        emit NFTBought(
            _listingId,
            listing.tokenId,
            msg.sender,
            listing.nftContract,
            listing.price
        );
        
    }

    /**
    * @dev 提取手续费
    * @notice 只有合约创建者才能提取手续费(目前只支持一次性提取所有手续费，后续可升级为提取指定金额)
    */
    function withdrawFee()
        external
        onlyOwner
    {
        uint fee = address(this).balance;
        require(
            fee > 0,
            "No balance to withdraw"
        );
        
        (bool successFee, ) = payable(feeReceiver).call{value: fee}("");
        require(
            successFee,
            "fee transfer failed"
        );
        emit FeeWithdrawn(
            feeReceiver,
            fee,
            block.timestamp
        );
    }
    
    /**
    * @dev 修改手续费接收地址
    * @param _newFeeReceiver 新的接收地址
    * @notice 只有合约创建者才能修改手续费接收地址
    */
    function setFeeReceiver(address _newFeeReceiver)
        external
        notZeroAddress(_newFeeReceiver)
        onlyOwner
    {
        address oldFeeReceiver = feeReceiver;
        feeReceiver = _newFeeReceiver;
        emit FeeReceiverChanged(
            oldFeeReceiver,
            _newFeeReceiver,
            block.timestamp
        );
    }

    /**
    * @dev 获取版税信息
    * @param _nftContract NFT合约地址
    * @param _tokenId NFT的ID
    * @param _price 售出价格(wei)
    * @return royaltyReceiver 版税接收者
    * @return royaltyAmount 版税金额
    * @notice 内部函数，检验NFT是否支持ERC2981标准
    */
    function _getRoyaltyInfo(
        address _nftContract,
        uint _tokenId,
        uint _price
    )
        internal
        view
        returns (address royaltyReceiver, uint256 royaltyAmount)
    {
        IERC721 _nft = IERC721(_nftContract);
        if(_nft.supportsInterface(type(IERC2981).interfaceId)){
            (royaltyReceiver, royaltyAmount) = IERC2981(_nftContract).royaltyInfo(
                _tokenId,
                _price
            );
        }else{
            //版税信息不存在
            royaltyReceiver = address(0);
            royaltyAmount = 0;
        }
    }

}