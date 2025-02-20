// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC721, ERC721Enumerable, Ownable {
    uint256 private _nextTokenId;
    uint256 public sellVal = 0.01 ether;

    constructor() ERC721("KeyRealEstate", "KRE") Ownable(msg.sender) {}

    event NFTisListedAsOnSell(uint256 indexed tokenId, address seller);
    event BuyNFTEvent(uint indexed tokenId, address buyer, address seller);
    event BidEvent(uint indexed tokenId); 
    event PlaceBid(uint indexed tokenId, address bidder, uint amount); 

    struct NFTonSale {
        bool onSale;
        uint sellPrice;
        uint tokenId; 
    }

        struct Bid {
        uint startTime; 
        uint endTime;
        uint tokenId;
        address owner; 
        address largestBidder; 
        uint amtOfBids;
        uint currentHighestBid;
        bool available; 
    }

    mapping(uint tokenId => Bid) public getBid;
    mapping(uint => mapping(address => uint)) private balances; 
    mapping(uint tokenId => address[] bidders) private whoBidOnToken;
    mapping(address bidder => bool bidded) private didBid;
    mapping(uint tokenId => NFTonSale) public _nftsOnSale;


    function _baseURI() internal pure override returns(string memory) {
        return "ipfs://bafybeibvbng2adn3iuewroxuple6cy5zbhysigkdo4jvctqd7hga6ijkgi/json/";
    }

    function safeMint() external onlyOwner {
        address to = msg.sender; 
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
    }


    //Can specify a sell price (uint256 sellprice) Not now though just keeping it simple
    function sellNFT(uint256 tokenId) public {
        require(msg.sender == ownerOf(tokenId), "NOT OWNER OF THIS NFT");
        NFTonSale memory _nftOnSale = NFTonSale(true, sellVal, tokenId); 
        _nftsOnSale[tokenId] = _nftOnSale; 
        
        emit NFTisListedAsOnSell(tokenId, msg.sender);
    }

 
    function BuyNFT(uint256 tokenId) external payable {
        address to = msg.sender; //Buyer addr
        address from = ownerOf(tokenId); //seller/owner addr 
        NFTonSale memory _nft = _nftsOnSale[tokenId];

        require(msg.sender != from, "YOU OWN THIS NFT ALREADY");  
        require(_nft.onSale == true, "This NFT is not for sale"); 
        require(msg.value == _nft.sellPrice, "Not correct amount");

        payable(from).transfer(msg.value);
        super._safeTransfer(from, to, tokenId);

        emit BuyNFTEvent(tokenId, to, from);
        
        delete _nftsOnSale[tokenId]; 
    }

    function allowBidding(uint tokenId, uint floorPrice) external {
        require(ownerOf(tokenId) == msg.sender, "You are not the owner of this token"); 
        Bid memory NewBid; 
        
        NewBid.available = true; 
        NewBid.currentHighestBid = floorPrice;
        NewBid.tokenId = tokenId; 
        NewBid.owner = msg.sender;
        NewBid.startTime = block.timestamp; 
        NewBid.endTime = NewBid.startTime + 60; 

        getBid[tokenId] = NewBid;

        emit BidEvent(tokenId); 
    }

    function placeBid(uint tokenId) external payable {        
        require(ownerOf(tokenId) != msg.sender, "You already own this NFT"); 

        Bid storage bid = getBid[tokenId];
        require(bid.available == true, "This token is not available for bidding");

        //Means the bid isn't over (didn't reach time limit)
        if(bid.endTime > block.timestamp)  {
            require(msg.value > bid.currentHighestBid, "Bid is not high enough");
            
            if (!didBid[msg.sender]) {whoBidOnToken[tokenId].push(msg.sender); didBid[msg.sender] = true; } 

            //place a bid   
            balances[tokenId][msg.sender] += msg.value; 
            bid.currentHighestBid = msg.value; 
            bid.largestBidder = msg.sender; 
            bid.amtOfBids++; 

            emit PlaceBid(tokenId, msg.sender, msg.value); 
        }

        else {
            payable(bid.owner).transfer(balances[tokenId][bid.largestBidder]);
            _safeTransfer(bid.owner, bid.largestBidder, tokenId);

            for(uint i = 0; i <= whoBidOnToken[tokenId].length - 1; i++) {
                if (bid.largestBidder != whoBidOnToken[tokenId][i]) {
                    address bidder = whoBidOnToken[tokenId][i]; 

                    (bool success, ) = payable(bidder).call{value: balances[tokenId][bidder]}("");
                    require(success, "Refund Failed"); 

                    delete balances[tokenId][bidder]; 
                    delete didBid[bidder];
                }
            }
             
        delete getBid[tokenId]; 

        }
    }

    function whoBid(uint tokenId) public view returns (address[] memory) {
        return whoBidOnToken[tokenId]; 
    }


    function getCurrentTime() public view returns(uint) {
        return block.timestamp; 
    }

    // The following functions are overrides required by Solidity.

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

