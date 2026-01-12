// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";// 防重入保护
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";// 合约拥有者
import "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";//



/**
* @title NFTAuction
* @dev NFT拍卖合约
* @dev 继承自ERC721和ERC721URIStorage，实现NFT拍卖功能
* @dev 本拍卖合约只考虑每次出价单独支付一次费用，不考虑多次出价只补差价问题（后续可升级）
* @author Shawn Hans
*/

contract NFTAuction is Initializable, UUPSUpgradeable,ReentrancyGuard,OwnableUpgradeable{ 

    //拍卖结构体
    struct Auction{ 
        address seller;//卖家地址
        address nftContract;//NFT合约地址
        uint tokenId;//NFT的ID
        uint start_price;//起拍价格
        uint end_time;//拍卖结束时间
        uint heightest_bid;//当前最高价
        address heightest_bidder;//当前最高价竞拍者
        bool active;//是否激活
        address tokenAddress;//参与竞价的资产类型：0地址:ETH other:ERC20代币
    }
    //拍卖ID
    uint public auctionId;
    //拍卖列表映射
    mapping(uint => Auction) public auctions;

    //平台手续费（基点：10000 = 100%）
    uint public platformFee = 250;//默认平台手续费为2.5%
    //平台手续费接收者
    address public feeReceiver;

    mapping(address => AggregatorV3Interface) public priceFeeds;



    /**********************修饰符验证start**********************************/
    modifier notZeroAddress(address _address) {
        require(_address != address(0), "Invalid address");
        _;
    }
    modifier notZeroNum(uint _num) {
        require(_num > 0, "Invalid number,cannot be zero");
        _;
    }
    /**********************修饰符验证end************************************/

    /**********************事件start**********************************/
    //拍卖创建事件
    event AuctionCreated(
        uint indexed auctionId,
        address indexed seller,
        address indexed nftContract,
        uint tokenId,
        uint start_price,
        uint end_time,
        uint create_time
    );
    //出价事件
    event BidPlaced(
        uint indexed auctionId,
        address indexed bidder,
        uint amount,
        uint create_time
    );
    //拍卖结束事件
    event AuctionEnded(
        uint indexed auctionId,
        address indexed winner,
        uint amount,
        uint create_time
    );
    /***********************事件end**********************************/

    function initialize(address _feeReceiver)
        public
        initializer

    {
        require(_feeReceiver != address(0), "Invalid address");
        feeReceiver = _feeReceiver;//设置手续费接收者
    }

   function setPriceFeed(
        address tokenAddress,
        address _priceFeed
    ) public {
        priceFeeds[tokenAddress] = AggregatorV3Interface(_priceFeed);
    }

    // ETH -> USD => 1766 7512 1800 => 1766.75121800
    // USDC -> USD => 9999 4000 => 0.99994000
    function getChainlinkDataFeedLatestAnswer(
        address tokenAddress
    ) public view returns (int) {
        AggregatorV3Interface priceFeed = priceFeeds[tokenAddress];
        // prettier-ignore
        (
            /* uint80 roundId */,
            int256 answer,
            /*uint256 startedAt*/,
            /*uint256 updatedAt*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        return answer;
    }

    /**
    * @dev 创建拍卖
    * @param _nftContract NFT合约地址
    * @param _tokenId NFT的ID
    * @param _start_price 起拍价格
    * @param _end_time 拍卖结束时间
    */

    function createAuction(
        address _nftContract,
        uint _tokenId,
        uint _start_price,
        uint _end_time
    )
        external
        notZeroAddress(_nftContract)
        notZeroNum(_tokenId)
        notZeroNum(_start_price)
        notZeroNum(_end_time)
        returns (uint)
    { 
        IERC721 _nft = IERC721(_nftContract);
        // 验证NFT拥有者
        require(
            _nft.ownerOf(_tokenId) == msg.sender,
            "You are not the owner of this NFT"
        );
        // 验证NFT是否被授权
        require(
            _nft.getApproved(_tokenId) == address(this) ||
            _nft.isApprovedForAll(msg.sender, address(this)),
            "NFT is not approved"
        );
        //验证结束时间
        require(
            _end_time > block.timestamp,
            "End time must be in the future"
        );


        //创建拍卖
        auctionId++;
        Auction memory newAuction = Auction({
            seller: msg.sender,
            nftContract: _nftContract,
            tokenId: _tokenId,
            start_price: _start_price,
            end_time: _end_time,
            heightest_bid: 0,
            heightest_bidder: address(0),
            active: true,
            tokenAddress: address(0)
        });
        auctions[auctionId] = newAuction;
        emit AuctionCreated(
            auctionId,
            msg.sender,
            _nftContract,
            _tokenId,
            _start_price,
            _end_time,
            block.timestamp
        );
        return auctionId;
    }

    /**
    * @dev 获取拍卖信息
    * @param _auctionId 拍卖ID
    */
    function getAuctions(uint _auctionId)
        external
        view
        returns (
            address seller,
            address nftContract,
            uint tokenId,
            uint start_price,
            uint end_time,
            uint heightest_bid,
            address heightest_bidder,
            bool active,
            address tokenAddress
        )
    {
        Auction memory auction = auctions[_auctionId];
        return (
            auction.seller,
            auction.nftContract,
            auction.tokenId,
            auction.start_price,
            auction.end_time,
            auction.heightest_bid,
            auction.heightest_bidder,
            auction.active,
            auction.tokenAddress
        );
    }

    /**
    * @dev 获取当前最大拍卖序号
    * @return uint 当前最大拍卖序号
    */
    function getAuctionCount() external view returns (uint) {
        return auctionId;
    }

    /**
    * @dev 竞拍
    * @param _auctionId 拍卖ID
    * @dev 可以支付eth或者ERC20代币
    */
    function bidNFT(
        uint _auctionId,
        uint _amount,
        address _tokenAddress
    )
        external
        payable
        nonReentrant
    { 
        Auction storage auction = auctions[_auctionId];
        //检查状态
        require(
            auction.active,
            "Auction is not active"
        );
        //检查是否是卖家
        require(
            auction.seller != msg.sender,
            "You are the seller"
        );
        //检查是否是结束
        require(
            block.timestamp < auction.end_time,
            "Auction has ended"
        );
        uint payValue;
        if (_tokenAddress != address(0)) {
            // 处理 ERC20
            // 检查是否是 ERC20 资产
            payValue = _amount * uint(getChainlinkDataFeedLatestAnswer(_tokenAddress));
        } else {
            // 处理 ETH
            _amount = msg.value;

            payValue = _amount * uint(getChainlinkDataFeedLatestAnswer(address(0)));
        }

        uint startPriceValue = auction.start_price *
            uint(getChainlinkDataFeedLatestAnswer(auction.tokenAddress));

        uint highestBidValue = auction.heightest_bid *
            uint(getChainlinkDataFeedLatestAnswer(auction.tokenAddress));

        require(
            payValue >= startPriceValue && payValue > highestBidValue,
            "Bid must be higher than the current highest bid"
        );


        // 转移 ERC20 到合约
        if (_tokenAddress != address(0)) {
            (bool successERC20) =IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _amount);
            require(successERC20, "ERC20 transfer to contracts failed");
        }

        // 退还前最高价
        if (auction.heightest_bid > 0) {
            if (auction.tokenAddress == address(0)) {
                // auction.tokenAddress = _tokenAddress;
                payable(auction.heightest_bidder).transfer(auction.heightest_bid);
            } else {
                // 退回之前的ERC20
                (bool successERC20) = IERC20(auction.tokenAddress).transfer(
                    auction.heightest_bidder,
                    auction.heightest_bid
                );
                require(successERC20, "ERC20 transfer to bidder failed");
            }
        }
        
        auction.tokenAddress = _tokenAddress;
        auction.heightest_bid = _amount;
        auction.heightest_bidder = msg.sender;
        emit BidPlaced(
            _auctionId,
            msg.sender,
            _amount,
            block.timestamp
        );
    }


    /**
    * @dev 结束拍卖
    * @param _auctionId 拍卖ID
    */

    function endAuction(
        uint _auctionId
    )
        external
        nonReentrant
    { 
        Auction storage auction = auctions[_auctionId];
        //检查状态
        require(
            auction.active,
            "Auction is not active"
        );
        //检查是否是卖家
        require(
            auction.seller == msg.sender,
            "You are not the seller"
        );
        //检查是否是结束
        require(
            block.timestamp > auction.end_time,
            "Auction has not ended"
        );
        //如果有竞拍者，转移NFT和资金
        if(auction.heightest_bidder != address(0)){
            IERC721 _nft = IERC721(auction.nftContract);
            //再次确认授权
            require(
                _nft.getApproved(auction.tokenId) == address(this) ||
                _nft.isApprovedForAll(auction.seller, address(this)),
                "NFT is not approved"
            );
            //转移NFT
            _nft.safeTransferFrom(
                auction.seller,
                auction.heightest_bidder,
                auction.tokenId
            );

            //计算手续费
            uint fee = auction.heightest_bid * platformFee / 10000;
            (bool successFee,) = payable(feeReceiver).call{value: fee}("");
            require(successFee, "Failed to send fee.");

            //转账给卖家（后续可以加上版权相关分成）
            (bool successSeller,) = payable(auction.seller).call{value: auction.heightest_bid - fee}("");
            require(successSeller, "Failed to send seller.");
        }
        
        
        //更新状态
        auction.active = false;
        //拍卖结束事件
        emit AuctionEnded(
            _auctionId,
            auction.heightest_bidder,
            auction.heightest_bid,
            block.timestamp
        );
    }

   



    function _authorizeUpgrade(address) internal override view {
        require(msg.sender == owner(), "Only the owner can upgrade the contract.");
    }

}