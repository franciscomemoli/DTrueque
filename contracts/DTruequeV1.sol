pragma solidity ^0.4.4;
contract ERC20 {
    function transfer(address to, uint tokens) public returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);
}
contract Ownable {
    address owner;
    modifier onlyOwner(){
        require(owner == msg.sender);
        _;
    }
    function transferOwner(address newOwner) onlyOwner public{
        owner = newOwner;
    }
}

contract Deprecatable is Ownable {
    bool deprecated;
    modifier notDeprecated(){
        require(!deprecated);
        _;
    }
    function setDeprecated(bool newStatus) onlyOwner public{
        deprecated = newStatus;
    }
    
}
contract ordersManager is Ownable, Deprecatable{
    struct Order{
        uint256 id;
        uint256 createdOn;
        ERC20 tokenSale;
        uint256 amountToSale; //wei
        uint256 price; //price of one token in wei example: to 1 token A = 1 token B price = 1E+18 
        ERC20 tokenBuy;
        bool paused;
        address owner;
        address buyDestination;
    }
    //mapp of the orders groped by tokenSale address tokenBuy address and id
    //mapping(address => mapping(address => mapping(uint256 => Order))) ordersTokenSaleTokenBuyId;
    
    mapping(address => mapping(address => Order[])) public ordersTokenSaleTokenBuyIds;
    bool deprecated;
    event Cancel(address tokenSale, address tokenBuy, uint256 id);
    event Sold(address tokenSale, address tokenBuy, uint256 id, uint amount);
    event SoldOut(address tokenSale, address tokenBuy, uint256 id, uint amount);
    event OrderCreated(address tokenSale, address tokenBuy, uint256 id, uint amount, bool paused);
    event OrderPausedChange(address tokenSale, address tokenBuy, uint256 id, bool paused);
    
    constructor() public{
        owner = msg.sender;
    }
    
    function createOrderAndSendTo(address tokenSale, uint256 amountToSale, uint256 price, address tokenBuy, bool paused, address buyDestination) notDeprecated public returns(uint256){
        require(ERC20(tokenSale).transferFrom(msg.sender, address(this), amountToSale));
        uint256 id = ordersTokenSaleTokenBuyIds[tokenSale][tokenBuy].length;
        var newOrder = Order(id, block.timestamp, ERC20(tokenSale), amountToSale, price, ERC20(tokenBuy), paused, msg.sender, buyDestination);
        ordersTokenSaleTokenBuyIds[tokenSale][tokenBuy].push(newOrder);
        emit OrderCreated(tokenSale, tokenBuy, id, amountToSale, paused);
        return id;
    }
    
    function createOrder(address tokenSale, uint256 amountToSale, uint256 price, address tokenBuy, bool paused) notDeprecated public returns(uint256){
        return createOrderAndSendTo(tokenSale, amountToSale, price, tokenBuy, paused, msg.sender);
    }
    
    function setPausedStatus(address tokenSale, address tokenBuy, uint256 id, bool paused) public {
        Order storage order = ordersTokenSaleTokenBuyIds[tokenSale][tokenBuy][id];
        require(order.owner == msg.sender);
        order.paused = paused;
        emit OrderPausedChange(tokenSale, tokenBuy, id, paused);
    }
    
    // amount: amount of tokens to buy in wei
    function buyAndSendTo(address tokenSale, address tokenBuy, uint256 id, uint256 amount, address destination) public returns(bool){
                // exist id?
        Order storage order = ordersTokenSaleTokenBuyIds[tokenSale][tokenBuy][id];
        require(!order.paused);
        // validate disponibility on Order to sale amount
        require(order.amountToSale >= amount);
        
        // decrement amount
        order.amountToSale -= amount;
        // validate amount on buyer. No sense we get this on transaction.
        // validate allowance on buyer. No sense we get this on transaction.
        uint256 amountForOwner = (amount * order.price) /  10 ** 18; //Check this could fail for tokens with more or less decimal than 18
        // transfer from buyer to buyDestination
        require(order.tokenBuy.transferFrom(msg.sender, order.buyDestination, amountForOwner));
        // transfer from smartcontracto to destination
        require(order.tokenSale.transfer(destination, amount));
        // event sold!
        emit Sold(tokenSale, tokenBuy, id, amount);
        // if no more amount is sold out!
        if(order.amountToSale == 0){
            emit SoldOut(tokenSale, tokenBuy, id, amount);
        }
        return true;
    }
    
    function buy(address tokenSale, address tokenBuy, uint256 id, uint256 amount ) public returns(bool) {
        return buyAndSendTo(tokenSale, tokenBuy, id, amount, msg.sender);
    }
    function withdraw(address tokenSale, address tokenBuy, uint256 id, uint256 amount) public {
        Order storage order = ordersTokenSaleTokenBuyIds[tokenSale][tokenBuy][id];
        require(order.owner == msg.sender);
        uint256 previousAmount = order.amountToSale;
        require(order.amountToSale >= amount);
        order.amountToSale -= amount;
        require(order.tokenSale.transfer(msg.sender, amount));
        if(order.amountToSale == 0){
            emit Cancel(tokenSale, tokenBuy, id);
        }
        require(previousAmount == (order.amountToSale + amount));
    }
}
