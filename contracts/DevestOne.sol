// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./libs/IERC20.sol";
import "./ITangibleStakeToken.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ERC721Metadata.sol";

// DeVest Investment Model One
// Bid & Offer
contract DevestOne is ITangibleStakeToken, ReentrancyGuard, ERC721Metadata {

    // When an shareholder exchanged his shares
    event swapped(address indexed from, address indexed to, uint256 share);

    // When new buy order was submitted and awaits acceptance
    event ordered(address indexed from, uint256 price, uint256 amount, bool buy);

    event leftOver(uint256 leftover);

    // reference to deployed $OIR contract
    IERC20 internal _token;

    // Owner of the contract (for admin controls)
    address private publisher;

    // contract was terminated and can't be used anymore
    bool private terminated = false;

    // initialized
    bool private initialized = false;

    // initial value
    uint256 private initialValue = 0;

    // Last price which was accepted in order book per unit
    uint256 private lastPricePerUnit = 0;

    // Shares contributed to the player
    uint256 tangibleTax = 0;
    uint256 constant contributionTax = 50;

    // Address of the tangible
    address private tangibleAddress;

    // Total balance (locked in $ORI)
    uint256 private balance;

    // Offers
    struct Order {
        uint256 price;
        uint256 amount;
        address from;
        uint256 escrow;
        bool buy; // buy = true | sell = false
    }
    mapping (address => Order) private orders;
    address[] private orderAddresses;
    uint256 private escrow;

    // Stakes
    mapping (address => uint256) private shares;
    address[] private shareholders;

    // metadata
    string _name;
    string _symbol;

    // Set owner and DI OriToken
    constructor(address tokenAddress, string memory __name, string memory __symbol) {
        publisher = _msgSender();
        _token = ERC20Token(tokenAddress);
        _name = __name;
        _symbol = __symbol;
    }

    // ----------------------------------------------------------------------------------------------------------
    // ----------------------------------------------- MODIFIERS ------------------------------------------------
    // ----------------------------------------------------------------------------------------------------------

    /**
    *  Verify tangible is active and initialized
    *
    */
    modifier _isActive() {
        require(initialized, 'Tangible was not initialized');
        require(!terminated, 'Tangible was terminated');
        _;
    }

    // ----------------------------------------------------------------------------------------------------------
    // ------------------------------------------------ INTERNAL ------------------------------------------------
    // ----------------------------------------------------------------------------------------------------------

    /**
    *  Update stored bids, if bid was spend, remove from list
    */
    function deductAmountfromOrder(address orderOwner, uint256 amount) internal { 
        require(orders[orderOwner].amount >= amount, "Insufficient funds");

        orders[orderOwner].amount -= amount;
        uint256 totalPrice = orders[orderOwner].price * amount;
        uint256 escrowDeduct = totalPrice + ((totalPrice * tangibleTax) / 100);
        orders[orderOwner].escrow = orders[orderOwner].escrow - escrowDeduct;

        if (orders[orderOwner].amount == 0){
            require(orders[orderOwner].escrow == 0, 'Escrow leftover'); // ????????????? WHAT IS THE PURPOSE OF THIS 
            uint256 index = 0;
            for(uint256 i=0;i< orderAddresses.length;i++){
                if (orderAddresses[i] == orderOwner)
                    index = i;
            }
            orderAddresses[index] = orderAddresses[orderAddresses.length-1];
            orderAddresses.pop();
        }
    }

    function swapShares(address to, address from, uint256 amount) internal {
        // add new owner
        bool found = false;
        for(uint256 i=0;i<shareholders.length;i++)
            found = shareholders[i] == to || found;

        if (!found) shareholders.push(to);
        shares[to] += amount;
        shares[from] -= amount;

        // update from
        if (shares[from] == 0){
            uint256 index = 0;
            for(uint256 i=0;i<shareholders.length;i++){
                if (shareholders[i] == from)
                    index = i;
            }
            shareholders[index] = shareholders[shareholders.length-1];
            shareholders.pop();
        }
    }

    // Safe access to msg.sender
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    // ----------------------------------------------------------------------------------------------------------
    // ------------------------------------------------- PUBLIC -------------------------------------------------
    // ----------------------------------------------------------------------------------------------------------

    function initialize(uint256 amount, uint tax) public returns (bool){
        require(!initialized, 'Tangible already initialized');
        require(tangibleAddress != address(0), 'Please set tangible address first');
        require(publisher == _msgSender(), 'Only owner can initialize tangibles');
        require(amount >= 100, 'Amount must be bigger than 100');
        require(tax >= 0, 'Invalid tax value');
        require(tax <= 100, 'Invalid tax value');

        tangibleTax = tax;
        initialValue = amount;

        lastPricePerUnit = amount / 100;

        shareholders.push(_msgSender());
        shares[_msgSender()] = 100;

        // start bidding
        initialized = true;

        return true;
    }

    function ask(uint256 price, uint256 amount) public override _isActive {
        bool test = true;
    }

/**
    TODO: split tax options:  
        1. buyer pays tax
        2. seller pays
        3. split tax
 */
    // Bid for shares
    function bid(uint256 price, uint256 amount) public virtual override nonReentrant _isActive returns (bool) {
        require(amount > 0, 'Invalid amount submitted');
        require(price > 0, 'Invalid price submitted');
        require(orders[_msgSender()].amount == 0, 'Active bid, cancel first');

        // add tax to escrow
        uint256 _escrow = price * amount;
        _escrow += (_escrow * tangibleTax) / 100;

        // check if enough escrow allowed
        require(_token.allowance(_msgSender(), address(this)) >= _escrow, 'Insufficient allowance provided');

        // store bid
        Order memory _bid = Order(price, amount, _msgSender(), _escrow, true);
        orders[_msgSender()] = _bid;
        orderAddresses.push(_msgSender());

        // pull escrow
        _token.transferFrom(_msgSender(), address(this), _escrow);

        emit ordered(_msgSender(), price, amount, true);

        return true;
    }

    // Offer shares for a specific price
    function offer(uint256 price, uint256 amount) public virtual _isActive {
        require(amount > 0, 'Invalid amount submitted');
        require(price > 0, 'Invalid price submitted');
        require(orders[_msgSender()].amount == 0, 'Active order, cancel first');
        require(getShare(_msgSender()) > 0, 'No shares available');

        // store bid
        Order memory _order = Order(price, amount, _msgSender(), 0, false);
        orders[_msgSender()] = _order;
        orderAddresses.push(_msgSender());

        // pull escrow
        emit ordered(_msgSender(), price, amount, false);
    }

    function accept(address orderOwner, uint256 amount) external payable override _isActive {
        require(amount > 0, "Invalid amount submitted");
        require(orders[orderOwner].amount >= amount, "Invalid order");

        // check for fee and transfer to owner
        require(msg.value > 10000000, "Please provide enough fee");
        payable(publisher).transfer(msg.value);

        Order memory order = orders[orderOwner];

        // calculate taxes
        uint256 cost = order.price * amount;
        uint256 tax = (cost * tangibleTax) / 100;

        uint256 totalCost = cost + tax;
        // accepting on sell order
        if (order.buy == false) {
            // what the buyer needs to pay (including taxes)
            _token.transferFrom(_msgSender(), address(this), totalCost);
            _token.transfer(order.from, cost);
        } else {
            // accepting buy order
            // so caller is accepting to sell his share to order owner -> order owner is paying to caller
            _token.transferFrom(orderOwner, address(this), totalCost);
            _token.transfer(_msgSender(), cost);
        }

        // pay tangible
        // is this even needed? e.g.  _token.transferFrom(_msgSender(), address(this), totalCost); transfers all, then we move cost to user - isnt tax left on our address?
       _token.transfer(tangibleAddress, tax);


        // TODO cover different event when accepting bid/ask
        // msg sender is accepting sell order
        if (order.buy == false) {   
            swapShares(_msgSender(), orderOwner, amount);
        } else {
            // msg sender is accepting buy order
            swapShares(orderOwner, _msgSender(), amount);
        }

        // update offer
        deductAmountfromOrder(orderOwner, amount);

        // TODO cover different event when accepting bid/ask
        emit swapped(_msgSender(), orderOwner, amount);
    }

    // Cancel order and return escrow
    function cancel() public virtual override _isActive() returns (bool) {
        require(orders[_msgSender()].escrow > 0, 'No open bid');

        Order memory _order = orders[_msgSender()];

        if (_order.buy){
            // return escrow leftover
            _token.transfer(_msgSender(), _order.escrow);

            // remove escrow
            orders[_msgSender()].escrow -= _order.escrow;
        }

        // update bids
        deductAmountfromOrder(_msgSender(), _order.amount);

        return true;
    }

    // Set the tangible address (for emergency, if player wallet spoofed)
    function setTangible(address _tangibleAddress) public returns (bool) {
        require(publisher == msg.sender, 'Only owner can set Tangible');

        tangibleAddress = _tangibleAddress;
        return true;
    }

    // Used to add value to tangible
    function disburse(uint256 amount) public _isActive() returns (bool){
        require(initialized, 'Tangible was not initialized');
        require(!terminated, 'Share was terminated');
        require(amount > 0, 'Invalid amount provided');

        // TODO Disburse amount send, and alos amount collected from contributionTax

        // check if enough escrow allowed
        require(_token.allowance(_msgSender(), address(this)) >= amount, 'Insufficient allowance provided');

        // pull escrow
        _token.transferFrom(_msgSender(), address(this), amount);
        balance += amount;

        return true;
    }

    // Terminate this contract, and pay-out all remaining investors
    function terminate() public override _isActive() returns (bool) {
        require(publisher == msg.sender, 'Only owner can terminate');

        uint256 price = getPrice();

        // transfer to all their shares
        for(uint256 i=0;i<shareholders.length;i++)
            _token.transfer(shareholders[i], shares[shareholders[i]] * price);

        // cancel bids
        for(uint256 i=0;i< orderAddresses.length;i++){
            _token.transfer(orderAddresses[i], orders[orderAddresses[i]].escrow);
            escrow -= orders[orderAddresses[i]].escrow;
            orders[orderAddresses[i]].amount = 0;
            orders[orderAddresses[i]].escrow = 0;
        }

        terminated = true;

        return true;
    }

    // Get orders (open)
    function getOrders() public view returns (Order[] memory) {
        Order[] memory _orders = new Order[](orderAddresses.length);

        for(uint256 i=0;i< orderAddresses.length;i++){
            Order memory order = orders[orderAddresses[i]];
            _orders[i] = order;
        }

        return _orders;
    }

    // Get shares of one investor
    function getShare(address _owner) public view returns (uint256) {
        return shares[_owner];
    }

    function balanceOf(address _owner) public view returns (uint256) {
        return shares[_owner];
    }

    // Get total balance of locked $ORI
    function getBalance() public view returns (uint256) {
        return balance;
    }

    // Return current price
    function getPrice() public view returns (uint256) {
      return lastPricePerUnit;
    }

    function getInitialValue() public view returns (uint256){
        return initialValue;
    }

    // Get shareholder addresses
    function getShareholders() public view returns (address[] memory) {
        return shareholders;
    }

    function getTax() public view returns (uint256) {
        return tangibleTax;
    }

    /// @notice A descriptive name for a collection of NFTs in this contract
    function name() external view returns (string memory){
        return _name;
    }

    /// @notice An abbreviated name for NFTs in this contract
    function symbol() external view returns (string memory){
        return _symbol;
    }
}
