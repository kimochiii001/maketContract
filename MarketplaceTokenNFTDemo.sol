//SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// Hello

contract MarketplaceTokenNFTDemo is ReentrancyGuard {
    // Variables
    address payable public immutable feeAccount; // the account that receives fees
    uint public immutable feePercent; // the fee percentage on sales
    uint public itemCount;
    uint public itemSold;

    enum ListingStatus {
        Active,
        Sold,
        Cancelled
    }

    struct Item {
        uint itemId;
        IERC721 nft;
        uint tokenId;
        uint price;
        address payable seller;
        bool sold;
    }

    // itemId -> Item
    mapping(uint => Item) public items;
    mapping(uint => address) public ItemToOwner;
    mapping(address => uint) ownerItemCount;

    event Offered(
        uint itemId,
        address indexed nft,
        uint tokenId,
        uint price,
        address indexed seller
    );
    event Bought(
        uint itemId,
        address indexed nft,
        uint tokenId,
        uint price,
        address indexed seller,
        address indexed buyer
    );

    constructor(uint _feePercent) {
        feeAccount = payable(msg.sender);
        feePercent = _feePercent;
    }

    modifier onlyOwnerOf(uint _itemId) {
        require(msg.sender == ItemToOwner[_itemId]);
        _;
    }

    // Make item to offer on the marketplace
    function makeItem(
        IERC721 _nft,
        uint _tokenId,
        uint _price
    ) external nonReentrant {
        require(_price > 0, "Price must be greater than zero");
        // increment itemCount
        itemCount++;

        ItemToOwner[itemCount] = msg.sender;
        ownerItemCount[msg.sender]++;
        // transfer nft
        _nft.transferFrom(msg.sender, address(this), _tokenId);
        // add new item to items mapping
        items[itemCount] = Item(
            itemCount,
            _nft,
            _tokenId,
            _price,
            payable(msg.sender),
            false,
            ListingStatus.Active
        );

        // emit Offered event
        emit Offered(itemCount, address(_nft), _tokenId, _price, msg.sender);
    }

    function changePriceItem(
        uint _itemId,
        uint newPrice
    ) external onlyOwnerOf(_itemId) nonReentrant {
        (items[_itemId].price) = newPrice;
    }

    function cancellItem(
        uint _itemId
    ) external onlyOwnerOf(_itemId) nonReentrant {
        Item storage item = items[_itemId];
        item.status = ListingStatus.Cancelled;
        IERC721(item.nft).transferFrom(address(this), msg.sender, _itemId);
        emit cancellMarket(_itemId, msg.sender);
    }

    function getAllNftsOnSale() public view returns (Item[] memory) {
        uint totalCount = itemCount;
        uint unsoldItemCount = itemCount - itemSold;
        Item[] memory allItemSold = new Item[](unsoldItemCount);
        uint counter = 0;

        for (uint i = 0; i < totalCount; ++i) {
            uint currentId = i + 1;
            Item storage currentItem = items[currentId];
            if (currentItem.sold == false) {
                allItemSold[counter] = currentItem;
                counter++;
            }
        }
        return allItemSold;
    }

    function purchaseItem(uint _itemId) external payable nonReentrant {
        uint _totalPrice = getTotalPrice(_itemId);
        Item storage item = items[_itemId];
        require(_itemId > 0 && _itemId <= itemCount, "item doesn't exist");
        require(
            msg.value >= _totalPrice,
            "not enough ether to cover item price and market fee"
        );
        require(!item.sold, "item already sold");
        // pay seller and feeAccount
        item.seller.transfer(item.price);
        feeAccount.transfer(_totalPrice - item.price);
        // update item to sold
        item.sold = true;
        itemSold++;
        // transfer nft to buyer
        item.nft.transferFrom(address(this), msg.sender, item.tokenId);
        // emit Bought event
        emit Bought(
            _itemId,
            address(item.nft),
            item.tokenId,
            item.price,
            item.seller,
            msg.sender
        );
    }

    function getTotalPrice(uint _itemId) public view returns (uint) {
        return ((items[_itemId].price * (100 + feePercent)) / 100);
    }
}
