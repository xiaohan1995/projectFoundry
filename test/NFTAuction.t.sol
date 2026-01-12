// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/NFTAuction.sol";
import "../src/NFThan.sol"; // 导入NFT合约
import "forge-std/console.sol";  // 添加console.sol导入

// Chainlink价格预言机模拟合约
contract MockV3Aggregator {
    int256 public answer;
    
    constructor(int256 initialAnswer) {
        answer = initialAnswer;
    }
    
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 ans,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (0, answer, block.timestamp, block.timestamp, 0);
    }
}

//测试合约
contract NFTAuctionTest is Test { 
    NFTAuction public nftAuction;
    NFThan public nftContract;// NFT合约实例
    address public owner  = address(0x1);
    address public seller = address(0x2);
    address public buyer1 = address(0x3);
    address public buyer2 = address(0x4);
    address public buyer3 = address(0x5);
    address public feeReceiver = address(0x6);
    uint public listingId;
    uint public listingId2;

    // Mock代币合约
    MockERC20 public mockToken;
    
    // Mock价格预言机
    MockV3Aggregator public ethPriceFeed;
    MockV3Aggregator public tokenPriceFeed;

    event AuctionCreated(
        uint indexed auctionId,
        address indexed seller,
        address indexed nftContract,
        uint tokenId,
        uint start_price,
        uint end_time
    );
    event BidPlaced(
        uint indexed auctionId,
        address indexed bidder,
        uint bidAmount
    );
    event AuctionEnded(
        uint indexed auctionId,
        address indexed winner,
        uint winningBid
    );

    function setUp() public { 
        nftAuction = new NFTAuction();
        nftAuction.initialize(feeReceiver);

        // 创建Mock价格预言机
        ethPriceFeed = new MockV3Aggregator(2000000000000000000); // 2000 USD/ETH (18 decimals)
        tokenPriceFeed = new MockV3Aggregator(100000000); // 1 USD per token (8 decimals for Chainlink)
        
        // 设置价格预言机
        nftAuction.setPriceFeed(address(0), address(ethPriceFeed)); // ETH/USD feed
        nftAuction.setPriceFeed(address(1), address(tokenPriceFeed)); // Token/USD feed (using address(1) as mock token)

        //账户资金初始化
        vm.deal(seller, 100 ether);
        vm.deal(buyer1, 100 ether);
        vm.deal(buyer2, 100 ether);
        vm.deal(buyer3, 100 ether);
      
        //给seller账户提供NFT合约地址和tokenId
        nftContract = new NFThan("TestNFT", "TNFT");
        vm.prank(seller);
        uint tokenId = nftContract.mint{value: 0.01 ether}("ipfs://test-metadata");

        //seller批准NFT拍卖合约可以操作其NFT
        vm.prank(seller);
        nftContract.approve(address(nftAuction), tokenId);
        console.log("Seller approved NFTAuction to manage tokenId: %s", tokenId);

    }
    // 测试初始化合约
    function test_CanInitializeContract() public view {
        console.log("Contract Owner: %s", nftAuction.owner());
        console.log("Fee Receiver: %s", nftAuction.feeReceiver());
        assertEq(nftAuction.feeReceiver(), feeReceiver);
    }
    // 测试：手续费接收者初始化为零地址的情况
    function test_InitializeWithZeroAddressShouldFail() public {
        NFTAuction newAuction = new NFTAuction();
        vm.expectRevert("Invalid address");
        newAuction.initialize(address(0));
    }
    /************测试创建拍卖start***********/
    //场景1：参数正常且功能正常
    function test_CanCreateAuction() public {
        vm.prank(seller);
        (listingId) = nftAuction.createAuction(
            address(nftContract),
            1,
            0.05 ether,
            block.timestamp + 1 days
        );
        (address r_seller, address r_nftContract, uint tokenId, uint start_price, uint end_time, , , ,) = nftAuction.getAuctions(listingId);
        assertEq(seller, r_seller);
        assertEq(address(nftContract), address(r_nftContract));
        assertEq(tokenId, 1);
        assertEq(start_price, 0.05 ether);
        assertEq(end_time, block.timestamp + 1 days);
        assertEq(nftAuction.getAuctionCount(), 1);
    }

    //场景2：测试非所有者无法创建拍卖
    function test_CannotCreateAuctionIfNotOwner() public {
        vm.prank(buyer1);
        vm.expectRevert("You are not the owner of this NFT");
        nftAuction.createAuction(
            address(nftContract),
            1,
            0.05 ether,
            block.timestamp + 1 days
        );
    }

    //场景3：未授权的合约无法创建拍卖
    function test_CannotCreateAuctionIfNotApproved() public {
        vm.prank(seller);
        //铸造新的未授权的NFT
        uint TokenId2 = nftContract.mint{value: 0.01 ether}("ipfs://test-metadata2");

        vm.prank(seller);
        vm.expectRevert("NFT is not approved");
        nftAuction.createAuction(
            address(nftContract),
            TokenId2,
            0.05 ether,
            block.timestamp + 1 days
        );
    }

    //3.1：测试授权所有代币的情况成功创建拍卖
    function test_CanCreateAuctionIfApprovedForAll() public {
        vm.startPrank(seller);
        //铸造新的未授权的NFT
        uint TokenId2 = nftContract.mint{value: 0.01 ether}("ipfs://test-metadata2");

        nftContract.setApprovalForAll(address(nftAuction), true);
        (listingId2) = nftAuction.createAuction(
            address(nftContract),
            TokenId2,
            0.05 ether,
            block.timestamp + 1 days
        );
        (, , uint tokenId, , , , , ,) = nftAuction.getAuctions(listingId2);
        vm.stopPrank();
        assertEq(tokenId, TokenId2);
    }

    //场景4：测试创建拍卖时的结束时间大于当前时间
    function test_CannotCreateAuctionIfEndTimeInvalid() public {
        // 保存当前时间，然后创建一个过去的时间点
        uint currentTime = block.timestamp;
        vm.warp(currentTime + 100); // 快进一些时间
        vm.prank(seller);
        vm.expectRevert("End time must be in the future");
        nftAuction.createAuction(
            address(nftContract),
            1,
            0.05 ether,
            currentTime
        );
    }

    //场景5：测试创建拍卖时的起价大于0
    function test_CannotCreateAuctionIfStartPriceInvalid() public {
        vm.prank(seller);
        vm.expectRevert("Invalid number,cannot be zero");
        nftAuction.createAuction(
            address(nftContract),
            1,
            0 ether,
            block.timestamp + 1 days
        );
    }

    //场景6：测试创建拍卖时NFT合约地址不为0地址
    function test_CannotCreateAuctionIfNFTContractIsZeroAddress() public {
        vm.prank(seller);
        vm.expectRevert("Invalid address");
        nftAuction.createAuction(
            address(0),
            1,
            0.05 ether,
            block.timestamp + 1 days
        );
    }

    //场景7：测试创建拍卖时NFT的ID不为0
    function test_CannotCreateAuctionIfTokenIdIsZero() public {
        vm.prank(seller);
        vm.expectRevert("Invalid number,cannot be zero");
        nftAuction.createAuction(
            address(nftContract),
            0,
            0.05 ether,
            block.timestamp + 1 days
        );
    }

    //场景8：测试创建拍卖时NFT的tokenId不存在
    function test_CannotCreateAuctionIfTokenIdDoesNotExist() public {
        vm.prank(seller);
        vm.expectRevert();
        nftAuction.createAuction(
            address(nftContract),
            200,
            0.05 ether,
            block.timestamp + 1 days
        );
    }

    //场景9：测试创建拍卖时结束时间为0时间
    function test_CannotCreateAuctionIfEndTimeIsZero() public {
        vm.prank(seller);
        vm.expectRevert("Invalid number,cannot be zero");
        nftAuction.createAuction(
            address(nftContract),
            1,
            0.05 ether,
            0
        );
    }


    /************测试创建拍卖end***********/


    /************测试出价start***********/

    // 场景1: 参数正常且功能正常(使用eth结算)
    function test_CanPlaceBid() public { 
        //调用统一封装函数创建拍卖
        listingId = createTestAuction(1, 0.05 ether, block.timestamp + 1 days);

        //出价
        vm.prank(buyer1);
        nftAuction.bidNFT{value: 0.06 ether}(listingId, 0.06 ether,address(0));
    }

    // 场景1.1: 测试出价低于起拍价或者低于当前最高价（eth结算）
    function test_CannotPlaceBidIfPriceTooLow() public {
        //调用统一封装函数创建拍卖
        listingId = createTestAuction(1, 0.05 ether, block.timestamp + 1 days);

        //出价
        vm.prank(buyer1);
        vm.expectRevert("Bid must be higher than the current highest bid");
        nftAuction.bidNFT{value: 0.04 ether}(listingId, 0.04 ether,address(0));
    }

    // 场景1.2: 测试出价时ETH转账失败的情况
    function test_BidNFTWithInsufficientETH() public {
        listingId = createTestAuction(1, 0.05 ether, block.timestamp + 1 days);
        
        vm.prank(buyer1);
        // 发送比实际出价少的ETH，但试图出更高金额
        vm.expectRevert();
        nftAuction.bidNFT{value: 0.01 ether}(listingId, 0.06 ether, address(0));
    }

    // 场景2: 测试使用erc20结算
    function test_CanPlaceBidWithERC20() public { 
        //调用统一封装函数创建拍卖
        listingId = createTestAuction(1, 0.05 ether, block.timestamp + 1 days);

        //部署Mock ERC20代币合约
        mockToken = new MockERC20("MockToken", "MTK", 1000000 * 10**18);
        console.log("Mock ERC20 deployed at: %s", address(mockToken));

        // 设置Mock代币的价格预言机 - 使1代币价值约为1ETH，这样少量代币就能超过起拍价
        MockV3Aggregator tokenPriceFeed2 = new MockV3Aggregator(2000000000000000000); // 2000 USD per token (same as ETH)
        vm.prank(owner);
        nftAuction.setPriceFeed(address(mockToken), address(tokenPriceFeed2));
        
        //给buyer1分发代币
        mockToken.transfer(buyer1, 1000 * 10**18);

        //buyer1批准NFT拍卖合约可以操作其代币
        vm.prank(buyer1);
        mockToken.approve(address(nftAuction), 100 * 10**18);

        //出价 - 使用较小的数量，因为每个代币价值很高
        vm.prank(buyer1);
        nftAuction.bidNFT(listingId, 1 * 10**17,address(mockToken)); // 0.1个代币
    }


    // 场景2.2: 测试余额不足（erc20结算）
    function test_CannotPlaceBidIfERC20BalanceInsufficient() public {
        //调用统一封装函数创建拍卖
        listingId = createTestAuction(1, 0.05 ether, block.timestamp + 1 days);

        //部署Mock ERC20代币合约
        mockToken = new MockERC20("MockToken", "MTK", 1000000 * 10**18);
        // 设置Mock代币的价格预言机 - 使1代币价值约为1ETH，这样少量代币就能超过起拍价
        MockV3Aggregator tokenPriceFeed2 = new MockV3Aggregator(2000000000000000000); // 2000 USD per token (same as ETH)
        vm.prank(owner);
        nftAuction.setPriceFeed(address(mockToken), address(tokenPriceFeed2));
        
        //给buyer1分发很少的代币
        mockToken.transfer(buyer1, 0.04 * 10**18); // 只给0.5个代币
        
        //buyer1批准NFT拍卖合约可以操作其代币
        vm.prank(buyer1);
        mockToken.approve(address(nftAuction), 0.04 * 10**18);  

        // 尝试出价0.2个代币，但只有0.2个代币，transferFrom会失败
        vm.prank(buyer1);
        vm.expectRevert(); 
        nftAuction.bidNFT(listingId, 0.05 * 10**18, address(mockToken)); 
    }

    //场景2.3：测试出价低于起拍价或者低于当前最高价（erc20结算）
    function test_CannotPlaceBidWithERC20IfPriceTooLow() public {
        //调用统一封装函数创建拍卖
        listingId = createTestAuction(1, 0.05 ether, block.timestamp + 1 days);

        //部署Mock ERC20代币合约
        mockToken = new MockERC20("MockToken", "MTK", 1000000 * 10**18);
        // 创建价格预言机，设为1ETH per token
        MockV3Aggregator tokenPriceFeed2 = new MockV3Aggregator(1000000000000000000); // 1 ETH per token
        vm.prank(owner);
        nftAuction.setPriceFeed(address(mockToken), address(tokenPriceFeed2));
        //给buyer1分发代币
        mockToken.transfer(buyer1, 1000 * 10**18);
        // buyer1批准NFT拍卖合约可以操作其代币
        vm.prank(buyer1);
        mockToken.approve(address(nftAuction), 100 * 10**18);
        
        // 出价0.04个代币，价值0.04ETH，低于起拍价0.05ETH
        vm.prank(buyer1);
        vm.expectRevert("Bid must be higher than the current highest bid");
        nftAuction.bidNFT(listingId, 0.04 * 10**18, address(mockToken));
    }
    // 场景3: 测试是否是卖家出价
    function test_CannotPlaceBidIfNotSeller() public {
        //调用统一封装函数创建拍卖
        listingId = createTestAuction(1, 0.05 ether, block.timestamp + 1 days);

        //出价
        vm.prank(seller);
        vm.expectRevert("You are the seller");
        nftAuction.bidNFT{value: 0.06 ether}(listingId, 0.06 ether,address(0));
    }

    //场景4：拍卖时间已经结束
    function test_CannotPlaceBidIfAuctionEnded() public { 
        
        listingId = createTestAuction(1, 0.05 ether, block.timestamp + 1 days);
        //出价
        vm.prank(buyer1);
        nftAuction.bidNFT{value: 0.06 ether}(listingId, 0.06 ether,address(0));
        vm.warp(block.timestamp + 2 days);

        vm.prank(buyer2);
        vm.expectRevert("Auction has ended");
        nftAuction.bidNFT{value: 0.07 ether}(listingId, 0.07 ether, address(0));
    }

    //场景5：测试是否退还上一个最高出价者的出价（eth结算）
    function test_CanRefundPreviousBidder() public {
        //调用统一封装函数创建拍卖
        listingId = createTestAuction(1, 0.05 ether, block.timestamp + 1 days);

        //buy1出价
        uint previousBalance = buyer1.balance;//参与拍卖前的余额
        //console.log("buyer1 balance before bid: %s", previousBalance);
        vm.prank(buyer1);
        nftAuction.bidNFT{value: 0.06 ether}(listingId, 0.06 ether,address(0));
        uint currentBalance = buyer1.balance;
        //console.log("buyer1 balance after bid: %s", currentBalance);
        //console.log("buyer1 balance change: %s", previousBalance - currentBalance);
        assertEq(previousBalance , currentBalance + 0.06 ether);

        //buy2出价
        vm.prank(buyer2);
        nftAuction.bidNFT{value: 0.07 ether}(listingId, 0.07 ether,address(0));
        uint finalBalance = buyer1.balance;
        //console.log("buyer1 balance after bid: %s", finalBalance);
        assertEq(finalBalance, previousBalance);
        
    }

    //场景6：测试是否退还上一个最高出价者的出价（erc20结算）
    function test_CanRefundPreviousBidderERC20() public {
        //调用统一封装函数创建拍卖
        listingId = createTestAuction(1, 0.05 ether, block.timestamp + 1 days);
        
        //部署Mock ERC20代币合约
        mockToken = new MockERC20("MockToken", "MTK", 1000000 * 10**18); 
        // 创建价格预言机，设为1ETH per token
        MockV3Aggregator tokenPriceFeed2 = new MockV3Aggregator(1000000000000000000);
        vm.prank(owner);
        nftAuction.setPriceFeed(address(mockToken), address(tokenPriceFeed2));
        mockToken.transfer(buyer1, 100 * 10**18);
        //授权
        vm.startPrank(buyer1);
        mockToken.approve(address(nftAuction), 100 * 10**18);
        //出价
        uint previousBalance = mockToken.balanceOf(buyer1);
        console.log("buyer1 balance before bid: %s", previousBalance);
        nftAuction.bidNFT(listingId, 0.6 * 10**18, address(mockToken));
        uint currentBalance = mockToken.balanceOf(buyer1);
        console.log("buyer1 balance after bid: %s", currentBalance);
        assertEq(previousBalance, currentBalance + 0.6 * 10**18);
        vm.stopPrank();

        mockToken.transfer(buyer2, 100 * 10**18);
        vm.startPrank(buyer2);
        mockToken.approve(address(nftAuction), 100 * 10**18);
        nftAuction.bidNFT(listingId, 0.7 * 10**18, address(mockToken));
        uint finalBalance = mockToken.balanceOf(buyer1);
        assertEq(finalBalance, previousBalance);
        vm.stopPrank();
    }

    //场景7：测试对已经结束的拍卖出价
    function test_CannotPlaceBidAfterAuctionEnded() public { 
        listingId = createTestAuction(1, 0.05 ether, block.timestamp + 1 days);
        vm.warp(block.timestamp + 2 days);
        vm.prank(seller);
        nftAuction.endAuction(listingId);
        vm.prank(buyer1);
        vm.expectRevert("Auction is not active");
        nftAuction.bidNFT{value: 0.06 ether}(listingId, 0.06 ether,address(0));
    }

    //场景8 ：测试用例来测试ERC20转账失败的情况
    function test_BidNFTWithFailingERC20Transfer() public {


        // 创建一个正常的NFT
        vm.prank(seller);
        uint256 tokenId = nftContract.mint{value: 0.01 ether}("ipfs://test-metadata1");
        
        // 授权NFT给拍卖合约
        vm.prank(seller);
        nftContract.approve(address(nftAuction), tokenId);
        
        // 创建拍卖
        vm.prank(seller);
        uint256 auctionId = nftAuction.createAuction(
            address(nftContract),
            tokenId,
            0.1 ether,
            block.timestamp + 1 days
        );
        
        // 创建一个会故意失败的ERC20代币合约
        MockFailingERC20 failingToken = new MockFailingERC20("FailingToken", "FAIL");
        failingToken.mint(buyer1, 100 ether);
        
        // 为这个ERC20代币设置价格馈送，使用模拟的价格馈送
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(2000000000000000000); // 0.2美元，假设
        vm.prank(owner);
        nftAuction.setPriceFeed(address(failingToken), address(mockPriceFeed));
        // 买家授权拍卖合约使用其代币
        vm.prank(buyer1);
        failingToken.approve(address(nftAuction), 100 ether);
    
        // 尝试出价，由于Mock合约中的特殊逻辑，这将失败
        vm.prank(buyer1);
        vm.expectRevert("ERC20 transfer to contracts failed");
        nftAuction.bidNFT(
            auctionId,
            0.7 ether,  // 这个金额会导致Mock合约返回false
            address(failingToken)
        );
    }

    //场景9：测试ERC20代币退款失败的情况
    function test_RefundPreviousBidderERC20Fails() public {
        // 创建一个正常的NFT
        vm.prank(seller);
        uint256 tokenId = nftContract.mint{value: 0.01 ether}("ipfs://test-metadata23");
        
        // 授权NFT给拍卖合约
        vm.prank(seller);
        nftContract.approve(address(nftAuction), tokenId);
        
        // 创建拍卖
        vm.prank(seller);
        uint256 auctionId = nftAuction.createAuction(
            address(nftContract),
            tokenId,
            0.1 ether,
            block.timestamp + 1 days
        );
        
        // 创建一个会故意在退款时失败的ERC20代币合约
        MockRefundingFailingERC20 failingToken = new MockRefundingFailingERC20("FailingToken", "FAIL");
        failingToken.mint(address(nftAuction), 100 ether); // 给拍卖合约一些代币用于退款
        failingToken.mint(buyer1, 100 ether);
        failingToken.mint(buyer2, 100 ether);
        
        // 为这个ERC20代币设置价格馈送
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(2000000000000000000); // 0.2美元，假设
        vm.prank(owner);
        nftAuction.setPriceFeed(address(failingToken), address(mockPriceFeed));
        
        // buyer1 授权拍卖合约使用其代币
        vm.prank(buyer1);
        failingToken.approve(address(nftAuction), 100 ether);
        
        // buyer1 出价
        vm.prank(buyer1);
        nftAuction.bidNFT(
            auctionId,
            0.2 ether,
            address(failingToken)
        );
        
        // buyer2 也授权拍卖合约使用其代币
        vm.prank(buyer2);
        failingToken.approve(address(nftAuction), 100 ether);
        
        // 设置退款失败标志
        vm.prank(address(nftAuction));
        failingToken.setPreviousBidder(buyer1);
        vm.prank(address(nftAuction));
        failingToken.setShouldFailOnRefund(true);
        
        // 尝试出价，这会导致在退款给buyer1时失败
        vm.prank(buyer2);
        vm.expectRevert("ERC20 transfer to bidder failed");
        nftAuction.bidNFT(
            auctionId,
            0.3 ether,  // 更高的出价，会触发对buyer1的退款
            address(failingToken)
        );
    }

    




    /************测试出价end***********/

    /************测试结束拍卖start**********/

    // 场景1：参数正常且功能正常
    function test_CanEndAuction() public {
        //调用统一封装函数创建拍卖
        listingId = createTestAuction(1, 0.05 ether, block.timestamp + 1 days); 

        vm.prank(buyer1);
        nftAuction.bidNFT{value: 0.06 ether}(listingId, 0.06 ether,address(0));
        vm.warp(block.timestamp + 2 days);
        vm.prank(seller);
        uint sellerBalanceBefore = seller.balance;
        uint feeReceiverBalanceBefore = feeReceiver.balance;
        nftAuction.endAuction(listingId);
        uint sellerBalanceAfter = seller.balance;
        uint feeReceiverBalanceAfter = feeReceiver.balance;

        // 验证拍卖结束
        (, , , , , , , bool ended ,) = nftAuction.getAuctions(listingId);
        assertFalse(ended);
        // 验证NFT转移
        assertEq(nftContract.ownerOf(1), buyer1);
        // 验证手续费结算
        assertEq(feeReceiverBalanceAfter, feeReceiverBalanceBefore +  (0.06 ether*0.025)); // 2.5%手续费
        // 验证出售价格结算
        assertEq(sellerBalanceAfter, sellerBalanceBefore + 0.06 ether - (0.06 ether*0.025));

    }

    // 场景2：测试非卖家结束拍卖shuo
    function test_CannotEndAuctionIfNotSeller() public {
        //调用统一封装函数创建拍卖
        listingId = createTestAuction(1, 0.05 ether, block.timestamp + 1 days); 

        vm.prank(buyer1);
        nftAuction.bidNFT{value: 0.06 ether}(listingId, 0.06 ether,address(0));
        vm.warp(block.timestamp + 2 days);
        vm.prank(buyer2);
        vm.expectRevert("You are not the seller");
        nftAuction.endAuction(listingId);
    }

    // 场景3：测试拍卖未结束无法结束拍卖
    function test_CannotEndAuctionIfNotEnded() public {
        //调用统一封装函数创建拍卖
        listingId = createTestAuction(1, 0.05 ether, block.timestamp + 2 days); 

        vm.prank(buyer1);
        nftAuction.bidNFT{value: 0.06 ether}(listingId, 0.06 ether,address(0));
        vm.warp(block.timestamp + 1 days);
        vm.prank(seller);
        vm.expectRevert("Auction has not ended");
        nftAuction.endAuction(listingId);
        (, , , , , , , bool active ,) = nftAuction.getAuctions(listingId);
        assertTrue(active);
    }

    //场景4：测试无人出价结束拍卖
    function test_CanEndAuctionWithoutBids() public {
        //调用统一封装函数创建拍卖
        listingId = createTestAuction(1, 0.05 ether, block.timestamp + 1 days); 

        vm.warp(block.timestamp + 2 days);
        vm.prank(seller);
        nftAuction.endAuction(listingId);

        // 验证拍卖结束
        (, , , , , , , bool active ,) = nftAuction.getAuctions(listingId);
        assertFalse(active);
    }

    //场景5：测试对已经结束的拍卖进行结束
    function test_CannotEndAuctionTwice() public {
        //调用统一封装函数创建拍卖
        listingId = createTestAuction(1, 0.05 ether, block.timestamp + 1 days); 

        vm.warp(block.timestamp + 2 days);
        vm.prank(seller);
        nftAuction.endAuction(listingId);
        vm.expectRevert("Auction is not active");
        nftAuction.endAuction(listingId);
    }

    //场景6：测试结束拍卖的时候卖家已经取消对于合约的NFT授权
    function test_CanEndAuctionIfSellerRevokesApproval() public {
        //调用统一封装函数创建拍卖
        listingId = createTestAuction(1, 0.05 ether, block.timestamp + 1 days);
        vm.prank(seller);
        nftContract.approve(address(0), 1);
        vm.prank(buyer1);
        nftAuction.bidNFT{value: 0.06 ether}(listingId, 0.06 ether,address(0));
        vm.warp(block.timestamp + 2 days);
        vm.prank(seller);
        vm.expectRevert();
        nftAuction.endAuction(listingId);

    }

    //场景7：测试结束拍卖的时候手续费收益结算失败
    function test_CannotEndAuctionIfFeeTransferFails() public {
        // 创建一个会拒绝接收资金的feeReceiver
        RevertingReceiver revertingFeeReceiver = new RevertingReceiver();
        
        // 重新部署合约并使用拒绝接收资金的地址作为feeReceiver
        NFTAuction revertingNftAuction = new NFTAuction();
        revertingNftAuction.initialize(address(revertingFeeReceiver));
        
        // 设置价格预言机
        MockV3Aggregator ethPriceFeedNew = new MockV3Aggregator(2000000000000000000);
        revertingNftAuction.setPriceFeed(address(0), address(ethPriceFeedNew));
        
        // 账户资金初始化
        vm.deal(seller, 100 ether);
        vm.deal(buyer1, 100 ether);
        
        // 给seller账户提供NFT合约地址和tokenId
        NFThan nftContractLocal = new NFThan("TestNFT", "TNFT");
        vm.prank(seller);
        uint tokenId = nftContractLocal.mint{value: 0.01 ether}("ipfs://test-metadata");

        // seller批准NFT拍卖合约可以操作其NFT
        vm.prank(seller);
        nftContractLocal.approve(address(revertingNftAuction), tokenId);

        // 创建拍卖
        vm.prank(seller);
        uint auctionId = revertingNftAuction.createAuction(
            address(nftContractLocal),
            tokenId,
            0.05 ether,
            block.timestamp + 1 days
        );

        // 有人出价
        vm.prank(buyer1);
        revertingNftAuction.bidNFT{value: 0.06 ether}(auctionId, 0.06 ether, address(0));

        // 时间快进到拍卖结束后
        vm.warp(block.timestamp + 2 days);

        // 尝试结束拍卖，应该因为向feeReceiver转账失败而失败
        vm.prank(seller);
        vm.expectRevert("Failed to send fee.");
        revertingNftAuction.endAuction(auctionId);
    }


    
  
    /************测试结束拍卖end************/

    /************测试升级合约start**********/

    
    /************测试升级合约end**********/


    // 测试预言机功能
    function test_CanSetAndGetPriceFeed() public {
        address tokenAddr = address(0x123);
        MockV3Aggregator newPriceFeed = new MockV3Aggregator(1500000000000000000); // 1500 USD
        
        vm.prank(owner);
        nftAuction.setPriceFeed(tokenAddr, address(newPriceFeed));
        
        int price = nftAuction.getChainlinkDataFeedLatestAnswer(tokenAddr);
        assertEq(price, 1500000000000000000);
    }

    // 辅助函数：创建拍卖
    function createTestAuction(uint tokenId, uint startPrice, uint endTime) internal returns (uint) {
        vm.prank(seller);
        uint id = nftAuction.createAuction(
            address(nftContract),
            tokenId,
            startPrice,
            endTime
        );
        
        (address r_seller, address r_nftContract, uint r_tokenId, uint r_start_price, uint r_end_time, , , ,) = nftAuction.getAuctions(id);
        assertEq(seller, r_seller);
        assertEq(address(nftContract), address(r_nftContract));
        assertEq(r_tokenId, tokenId);
        assertEq(r_start_price, startPrice);
        assertEq(r_end_time, endTime);
        assertTrue(nftAuction.getAuctionCount() > 0);
        
        return id;
    }

    // 测试：价格预言机不存在时的行为
    function test_BidWithNonExistentPriceFeed() public {
        listingId = createTestAuction(1, 0.05 ether, block.timestamp + 1 days);
        
        // 尝试使用未设置的价格预言机
        address nonExistentToken = address(0x999);
        
        vm.prank(buyer1);
        vm.expectRevert();
        nftAuction.bidNFT{value: 0.06 ether}(listingId, 0.06 ether, nonExistentToken);
    }

    


}

// Mock ERC20 Token Contract
contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint public totalSupply;
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);

    constructor(string memory _name, string memory _symbol, uint _totalSupply) {
        name = _name;
        symbol = _symbol;
        decimals = 18;
        totalSupply = _totalSupply;
        balanceOf[msg.sender] = _totalSupply;
    }

    function transfer(address to, uint value) public returns (bool) {
        require(balanceOf[msg.sender] >= value, "Insufficient balance");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint value) public returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) public returns (bool) {
        require(balanceOf[from] >= value, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Allowance exceeded");
        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;
        emit Transfer(from, to, value);
        return true;
    }
}

// Mock ERC20合约用于测试转账失败的情况
contract MockFailingERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        decimals = 18;
    }

    function mint(address to, uint256 amount) public {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        // 故意让转账失败的条件，例如当from地址余额不足时
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        
        // 根据某些条件故意使转账失败
        // 根据特定金额故意使转账失败
        if (amount == 0.7 ether) {  // 0.7 * 10**18 = 700000000000000000
            return false;
        }
        
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        return true;
    }
}

contract MockRefundingFailingERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    // 记录谁是前一个最高出价者，以便在退款时模拟失败
    address public previousBidder;
    bool public shouldFailOnRefund = false;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        decimals = 18;
    }

    function mint(address to, uint256 amount) public {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");

        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        return true;
    }

    // 重写transfer函数，当退款给前一个最高出价者时故意失败
    function transfer(address to, uint256 amount) public returns (bool) {
        // 如果是向之前的出价者转账且设置了退款失败标志，则失败
        if (shouldFailOnRefund && to == previousBidder) {
            return false;
        }
        
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    
    // 设置前出价者地址
    function setPreviousBidder(address _previousBidder) external {
        previousBidder = _previousBidder;
    }
    
    // 设置是否在退款时失败
    function setShouldFailOnRefund(bool _shouldFail) external {
        shouldFailOnRefund = _shouldFail;
    }
}

// 一个会拒绝接收资金的合约，用于测试转账失败的情况
contract RevertingReceiver {
    receive() external payable {
        revert("RevertingReceiver: Reverting on receive");
    }
    
    fallback() external payable {
        revert("RevertingReceiver: Reverting on fallback");
    }
}

