// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/NFThan.sol";
import "forge-std/console.sol";  // 添加console.sol导入

contract NFThanTest is Test {
    NFThan public nft;
    
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    
    string public constant TEST_URI = "ipfs://test-metadata";
    string public constant TEST_URI2 = "ipfs://test-metadata2";
    
    uint public tokenId;
    
    event Mint(address indexed minter, uint indexed tokenId, string uri);
    event Withdraw(address indexed withdrawer, uint amount);

    function setUp() public {
        console.log("Setting up test environment...");
        console.log("Owner address: %s", owner);
        console.log("User1 address: %s", user1);
        console.log("User2 address: %s", user2);
        vm.deal(user1, 1000 ether);
        console.log("Provided 1000 ETH to user1, balance now: %s", user1.balance);
        vm.deal(user2, 2000 ether);
        console.log("Provided 2000 ETH to user2, balance now: %s", user1.balance);
        vm.deal(address(nft), 2000 ether);
        vm.startPrank(owner);
        nft = new NFThan("TestNFT", "TNFT");
        console.log("Contract deployed at: %s", address(nft));
        console.log("Contract owner: %s", nft.owner());
        vm.stopPrank();
    }
    
    function test_CanDeployContract() public view{
        console.log("Testing deployment...");
        console.log("Name: %s", nft.name());
        console.log("Symbol: %s", nft.symbol());
        console.log("Total Supply: %s", nft.totalSupply());
        console.log("Max Supply: %s", nft.MAX_SUPPLY());
        console.log("Mint Price: %s", nft.MINT_PRICE());
        console.log("Owner: %s", nft.owner());
        
        assertEq(nft.name(), "TestNFT");
        assertEq(nft.symbol(), "TNFT");
        assertEq(nft.totalSupply(), 0);
        assertEq(nft.MAX_SUPPLY(), 10000);
        assertEq(nft.MINT_PRICE(), 0.01 ether);
        assertEq(nft.owner(), owner);
    }
    
    function test_CanMintNFT() public {
        console.log("Testing NFT minting...");
        console.log("Before mint - Supply: %s", nft.totalSupply());
        console.log("Before mint - Contract balance: %s", address(nft).balance);
        console.log("User1 balance before: %s", user1.balance);

        

        vm.startPrank(user1);
        
        vm.expectEmit(true, true, false, true);
        emit Mint(user1, 1, TEST_URI);
        
        uint newTokenId = nft.mint{value: 0.01 ether}(TEST_URI);
        
        console.log("After mint - Token ID: %s", newTokenId);
        console.log("After mint - Supply: %s", nft.totalSupply());
        console.log("After mint - Contract balance: %s", address(nft).balance);
        
        vm.stopPrank();
        
        console.log("Verifying mint results...");
        console.log("Expected tokenId: 1, Actual: %s", newTokenId);
        console.log("Owner of token 1: %s", nft.ownerOf(1));
        console.log("Token URI: %s", nft.tokenURI(1));
        
        assertEq(newTokenId, 1);
        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.tokenURI(1), TEST_URI);
        assertEq(nft.totalSupply(), 1);
    }
    function test_RevertIf_InsufficientPayment() public {
        console.log("Testing insufficient payment...");
        console.log("Required payment: %s", nft.MINT_PRICE());
        console.log("Provided payment: 0");
        
        vm.startPrank(user1);
        
        vm.expectRevert("Insufficient payment");
        nft.mint{value: 0}("");
        
        vm.stopPrank();
    }
    
    function test_RevertIf_EmptyURI() public {
        console.log("Testing empty URI...");
        console.log("Required payment: %s", nft.MINT_PRICE());
        console.log("Provided URI: empty");
        
        vm.startPrank(user1);
        
        vm.expectRevert("URI cannot be empty");
        nft.mint{value: 0.01 ether}("");
        
        vm.stopPrank();
    }
    
   
    
    
    function test_CanSetMintPrice() public {
        console.log("Testing mint price change...");
        console.log("Current price: %s", nft.MINT_PRICE());
        
        vm.startPrank(owner);
        
        nft.setMintPrice(0.02 ether);
        
        console.log("New price: %s", nft.MINT_PRICE());
        
        assertEq(nft.MINT_PRICE(), 0.02 ether);
        
        vm.stopPrank();
    }
    
    function test_RevertIf_NonOwnerSetMintPrice() public {
        console.log("Testing non-owner price change...");
        console.log("Caller: %s", user1);
        console.log("Contract owner: %s", nft.owner());
        
        vm.startPrank(user1);
        
        vm.expectRevert();
        nft.setMintPrice(0.02 ether);
        
        vm.stopPrank();
    }
    
    
    function test_RevertIf_SameMintPrice() public {
        console.log("Testing same mint price...");
        console.log("Current price: %s", nft.MINT_PRICE());
        
        vm.startPrank(owner);
        
        vm.expectRevert("New price is the same as the current price");
        nft.setMintPrice(0.01 ether);
        
        vm.stopPrank();
    }
    
    function test_RevertIf_ZeroMintPrice() public {
        console.log("Testing zero mint price...");
        console.log("Attempting to set price to: 0");
        
        vm.startPrank(owner);
        
        vm.expectRevert("Price cannot be zero");
        nft.setMintPrice(0);
        
        vm.stopPrank();
    }

    function test_CanWithdraw() public {
        console.log("Testing withdrawal...");
        
        vm.startPrank(user1);
        nft.mint{value: 0.01 ether}(TEST_URI);
        console.log("Contract balance after mint: %s", address(nft).balance);
        vm.stopPrank();
        
        vm.startPrank(owner);
        
        vm.expectEmit(true, true, false, true);
        emit Withdraw(owner, 0.01 ether);
        
        console.log("Owner calling withdraw...");
        console.log("Owner address: %s", owner);
        console.log("Contract balance before withdraw: %s", address(nft).balance);
        
        nft.withdraw();
        
        console.log("Contract balance after withdraw: %s", address(nft).balance);
        
        vm.stopPrank();
        
        assertEq(address(nft).balance, 0);
    }
    
    function test_RevertIf_NonOwnerWithdraw() public {
        console.log("Testing non-owner withdrawal...");
        
        vm.startPrank(user1);
        nft.mint{value: 0.01 ether}(TEST_URI);
        console.log("Contract balance after mint: %s", address(nft).balance);
        vm.stopPrank();
        
        vm.startPrank(user1);
        console.log("Non-owner (user1) attempting to withdraw...");
        console.log("Caller: %s", user1);
        console.log("Owner: %s", nft.owner());
        
        vm.expectRevert();
        nft.withdraw();
        
        vm.stopPrank();
    }
    
    function test_RevertIf_WithdrawZeroBalance() public {
        console.log("Testing withdraw zero balance...");
        console.log("Contract balance: %s", address(nft).balance);
        
        vm.startPrank(owner);
        
        vm.expectRevert("No balance to withdraw");
        nft.withdraw();
        
        vm.stopPrank();
    }
    
    function test_CanTransferNFT() public {
        console.log("Testing NFT transfer...");
        
        vm.startPrank(user1);
        console.logUint(0.01 ether);
        uint newTokenId = nft.mint{value: 0.01 ether}(TEST_URI);
        console.log("Minted token ID: %s", newTokenId);
        console.log("User1 balance before transfer: %s", nft.balanceOf(user1));
        console.log("User2 balance before transfer: %s", nft.balanceOf(user2));
        vm.stopPrank();
        
        vm.startPrank(user1);
        nft.transferFrom(user1, user2, newTokenId);
        vm.stopPrank();
        
        console.log("After transfer:");
        console.log("Owner of token %s: %s", newTokenId, nft.ownerOf(newTokenId));
        console.log("User2 balance after transfer: %s", nft.balanceOf(user2));
        console.log("User1 balance after transfer: %s", nft.balanceOf(user1));
        
        assertEq(nft.ownerOf(newTokenId), user2);
        assertEq(nft.balanceOf(user2), 1);
        assertEq(nft.balanceOf(user1), 0);
    }
    
    function test_CanGetTokenURI() public {
        console.log("Testing token URI retrieval...");
        
        vm.startPrank(user1);
        uint newTokenId = nft.mint{value: 0.01 ether}(TEST_URI);
        console.log("Minted token ID: %s", newTokenId);
        console.log("Expected URI: %s", TEST_URI);
        vm.stopPrank();
        
        string memory actualURI = nft.tokenURI(newTokenId);
        console.log("Actual URI: %s", actualURI);
        
        assertEq(actualURI, TEST_URI);
    }
    
    function test_SupportsInterface() public view {
        console.log("Testing interface support...");
        console.log("Testing ERC721 interface ID: 0x80ac58cd");
        console.log("Testing ERC721 Metadata interface ID: 0x5b5e139f");
        console.log("Testing random interface ID: 0xffffffff");
        
        assertTrue(nft.supportsInterface(0x80ac58cd));
        assertTrue(nft.supportsInterface(0x5b5e139f));
        assertFalse(nft.supportsInterface(0xffffffff));
    }
    
}