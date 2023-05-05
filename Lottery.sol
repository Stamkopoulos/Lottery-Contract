// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

contract Lottery {

    enum Stage {Init, Reg, Bid, Done}
    Stage public stage = Stage.Init;

    event Winner(address indexed winnerAddress, uint itemNumber, uint lotteryNumber);
    uint lotteryNumber = 1;

    struct Item {
        uint itemId;
        uint itemTokens;
        address winner;

    }

    struct Person {
        uint personId;
        address addr;
        uint remainingTokens;
    }

    address public owner;
    uint public numOfItems;
    uint public bidderCount = 0;
    address[] public winners; 
    mapping(uint => Item) public items;

    mapping(address => Person) public tokenDetails; // bidder's address
    Person[] public bidders; 
    uint public constant MIN_DEPOSIT = 0.005 ether;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only contract owner can call this function");
        _;
    }

    modifier hasEnoughEther() {
            require(msg.value >=  MIN_DEPOSIT, "Insufficient ether balance");
            _;
    }

    modifier notRegistered() {
        require(tokenDetails[msg.sender].addr == address(0), "Bidder is already registered.");
        _;
    }

    modifier bidderHasEnoughBalance(uint _count) {
        require(tokenDetails[msg.sender].remainingTokens >= _count, "Bidder does not have enough balance.");
        _;
    }

    modifier itemExists(uint itemId) {
        require(itemId < numOfItems, "Item does not exist.");
        _;
    }

    constructor(uint _numOfItems) {
        owner = msg.sender;
        numOfItems = _numOfItems;
        
        for (uint i = 0; i < _numOfItems; i++) {
            items[i] = Item({itemId: i , itemTokens: 0, winner: address(0)});
        }
    }
    
    function register() public payable hasEnoughEther notRegistered {
        
        require(stage == Stage.Reg, "Registration is not currently open");

        bidders.push(Person({
            personId: bidderCount,
            addr: msg.sender,
            remainingTokens: 5
        }));
        tokenDetails[msg.sender] = bidders[bidderCount];
        bidderCount++;
    }

    function bid(uint _itemId, uint _count) public payable itemExists(_itemId) bidderHasEnoughBalance(_count) {
        require(stage == Stage.Bid, "Bidding is not open.");
        tokenDetails[msg.sender].remainingTokens -= _count;
        items[_itemId].itemTokens += _count;
        //Auto den douleuei
        //bidders[_itemId].remainingTokens -= _count;
    }

    function getItems() public view returns (uint[] memory, uint[] memory) {
        uint[] memory itemIds = new uint[](numOfItems);
        uint[] memory itemTokens = new uint[](numOfItems);
        for (uint i = 0; i < numOfItems; i++) {
            itemIds[i] = items[i].itemId;
            itemTokens[i] = items[i].itemTokens;
            
        }
        return (itemIds, itemTokens);
    }


    function revealWinners() public onlyOwner returns (uint[] memory, address[] memory) {
        require(stage == Stage.Done, "Bidding is not currently closed");
        require(winners.length == 0, "Winners have already been revealed.");
        
        uint[] memory itemIds = new uint[](numOfItems);
        address[] memory winAddr = new address[](numOfItems);

        uint bal = (address(this).balance / numOfItems);

        for (uint i = 0; i < numOfItems; i++) {
            require(items[i].itemTokens > 0, "No one has bid on this item.");
            
            uint randomIndex = uint(keccak256(abi.encodePacked(block.timestamp, i, items[i].itemTokens))) % bidders.length;
            items[i].winner = bidders[randomIndex].addr;
            winners.push(items[i].winner);

            itemIds[i] = items[i].itemId;
            winAddr[i] = items[i].winner;
            
            payable(items[i].winner).transfer(bal);

            emit Winner(winAddr[i], itemIds[i], lotteryNumber);

        }

        if (winners.length > 0) {
            stage = Stage.Done;
        }
        
        return (itemIds, winAddr);
    }

    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        require(balance > 0, "Contract has no balance to withdraw.");
        payable(msg.sender).transfer(balance);
    }

    function reset(uint newNumOfItems) public onlyOwner {
        // Reset items
        for (uint i = 0; i < numOfItems; i++) {
            items[i].itemTokens = 0;
            items[i].winner = address(0);
        }
        numOfItems = newNumOfItems;
        for (uint i = 0; i < newNumOfItems; i++) {
            items[i] = Item({itemId: i, itemTokens: 0, winner: address(0)});
        }

        // Reset bidders
        for (uint i = 0; i < bidderCount; i++) {
            delete tokenDetails[bidders[i].addr];
        }
        delete bidders;
        bidderCount = 0;

        // Reset winners
        delete winners;

        // Reset Stage
        stage = Stage.Reg;

        lotteryNumber += 1;

    }

    function advanceState() public onlyOwner {
        if (stage == Stage.Init) {
            stage = Stage.Reg;
        } else if (stage == Stage.Reg) {
            stage = Stage.Bid;
        } else if (stage == Stage.Bid) {
            stage = Stage.Done;
        }else {
            revert("You have to reset to go to init stage");
        }
    }


 
}
