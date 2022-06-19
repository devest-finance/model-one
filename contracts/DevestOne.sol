// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./ITangibleStakeToken.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// DeVest Investment Model One
// Bid & Offer
contract DevestOne is ITangibleStakeToken, ReentrancyGuard {

    // When an shareholder exchanged his shares
    event swapped(address indexed from, address indexed to, uint256 share);

    // When new buy order was submitted and awaits acceptance
    event ordered(address indexed from, uint256 price, uint256 amount, bool bid);

    // When payment was received
    event payment(address indexed from, uint256 amount);

    // When dividends been disbursed
    event disbursed(uint256 amount);


    event leftOver(uint256 leftover);

    // reference to trading token used in TST
    ERC20 internal _token;

    // Owner of the contract (for admin controls)
    address private publisher;

    // contract was terminated and can't be used anymore
    bool internal terminated = false;

    // initialized
    bool internal initialized = false;

    // instantDisburse
    // Disburse received payments instantly to shareholders
    // this could be a problem if the token has a high divider,
    // related to the amount of transactions required !!!
    bool instantDisburse;

    // Last price which was accepted in order book per unit
    uint256 private lastPricePerUnit = 0;

    // Shares contributed to the player
    uint256 tangibleTax = 0;

    // Address of the tangible
    address internal tangibleAddress;

    // Offers
    struct Order {
        uint256 price;
        uint256 amount;
        address from;
        uint256 escrow;
        bool bid; // buy = true | sell = false
    }
    mapping (address => Order) private orders;
    address[] private orderAddresses;
    uint256 private escrow;

    // Stakes
    mapping (address => uint256) internal shares;
    address[] internal shareholders;

    // metadata
    string _name;
    string _symbol;
    string _tokenURI;

    // voting (terminatian and tengible)
    mapping (address => bool) terminationVote;
    mapping (address => address) tangibleVote;

    // Set owner and DI OriToken
    constructor(address tokenAddress, string memory __name, string memory __symbol) {
        publisher = _msgSender();
        _token = ERC20(tokenAddress);
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

        // in case of bid deduct escrow
        if (orders[orderOwner].bid == true){
            uint256 escrowDeduct = totalPrice + ((totalPrice * tangibleTax) / 100);
            orders[orderOwner].escrow -= escrowDeduct;
        }

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

    /**
     *  Initialize TST as tangible
     */
    function initialize(uint256 amount, uint tax, bool _instantDisburse) public returns (bool){
        require(!initialized, 'Tangible already initialized');
        require(publisher == _msgSender(), 'Only owner can initialize tangibles');
        require(amount >= 100, 'Amount must be bigger than 100');
        require(tax >= 0, 'Invalid tax value');
        require(tax <= 100, 'Invalid tax value');

        tangibleTax = tax;
        lastPricePerUnit = amount / 100;
        instantDisburse = _instantDisburse;

        shareholders.push(_msgSender());
        shares[_msgSender()] = 100;

        // start bidding
        initialized = true;

        return true;
    }

    // ----------------------------------------------------------------------------------------------------------
    // ------------------------------------------------ TRADING -------------------------------------------------

    /**
    *  Bid for purchase
    */
    function bid(uint256 price, uint256 amount) public virtual override nonReentrant _isActive {
        require(amount > 0 && amount <= 100, 'Invalid amount submitted');
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
    }

    /**
     *  Ask for sell
     */
    function ask(uint256 price, uint256 amount) public override nonReentrant _isActive {
        require(amount > 0 && amount <= 100, 'Invalid amount submitted');
        require(price > 0, 'Invalid price submitted');
        require(shares[_msgSender()]  > 0, 'Insufficient shares');
        require(orders[_msgSender()].amount == 0, 'Active order, cancel first');

        // store bid
        Order memory _ask = Order(price, amount, _msgSender(), 0, false);
        orders[_msgSender()] = _ask;
        orderAddresses.push(_msgSender());

        emit ordered(_msgSender(), price, amount, false);
    }

    /**
     *  Accept order
     */
    function accept(address orderOwner, uint256 amount) external payable override _isActive returns (uint256) {
        require(amount > 0, "Invalid amount submitted");
        require(orders[orderOwner].amount >= amount, "Invalid order");
        require(_msgSender() != orders[orderOwner].from, "Can't accept your own order");

        // check for fee and transfer to owner
        //require(msg.value > 10000000, "Please provide enough fee");
        //payable(publisher).transfer(msg.value);

        Order memory order = orders[orderOwner];

        // calculate taxes
        uint256 cost = order.price * amount;
        uint256 tax = (cost * tangibleTax) / 100;

        uint256 totalCost = cost + tax;

        // accepting on sell order
        if (order.bid == false) {
            // what the buyer needs to pay (including taxes)
            _token.transferFrom(_msgSender(), address(this), totalCost);
            _token.transfer(order.from, cost);
        } else {
            // accepting bid order
            // so caller is accepting to sell his share to order owner
            // -> escrow from order can be transferred to owner
            _token.transfer(_msgSender(), cost);
        }

        // pay tangible
       _token.transfer(tangibleAddress, tax);

        // TODO cover different event when accepting bid/ask
        // msg sender is accepting sell order
        if (order.bid == false) {
            swapShares(_msgSender(), orderOwner, amount);
        } else {
            // msg sender is accepting buy order
            swapShares(orderOwner, _msgSender(), amount);
        }

        // update offer
        deductAmountfromOrder(orderOwner, amount);

        // update last transaction price (uint)
        lastPricePerUnit = order.price;

        // TODO cover different event when accepting bid/ask
        emit swapped(_msgSender(), orderOwner, amount);

        return 1;
    }

    // Cancel order and return escrow
    function cancel() public virtual override _isActive() returns (bool) {
        require(orders[_msgSender()].amount > 0, 'No open bid');

        Order memory _order = orders[_msgSender()];

        if (_order.bid){
            // return escrow leftover
            _token.transfer(_msgSender(), _order.escrow);
        }

        // update bids
        deductAmountfromOrder(_msgSender(), _order.amount);

        return true;
    }

    // Pay usage charges
    function pay(uint256 amount) public override _isActive{
        require(initialized, 'Tangible was not initialized');
        require(!terminated, 'Share was terminated');
        require(amount > 0, 'Invalid amount provided');

        // check if enough escrow allowed and pull
        require(_token.allowance(_msgSender(), address(this)) >= amount, 'Insufficient allowance provided');
        _token.transferFrom(_msgSender(), address(this), amount);

        // pay tangible tax
        uint256 tangible = ((tangibleTax * amount) / 100);
        _token.transfer(tangibleAddress, tangible);

        // disburse if auto disburse
        if (instantDisburse == true)
            disburse();

        emit payment(_msgSender(), amount);
    }

    // Distribute funds on TST to shareholders
    function disburse () public override _isActive returns (uint256) {
        uint256 balance = _token.balanceOf(address(this));

        // distribute to shareholders
        for(uint256 i=0;i<shareholders.length;i++)
            _token.transfer(shareholders[i], (shares[shareholders[i]] * balance) / 100);

        return balance;
    }

    // Vote for another tangible address (receiver)
    function setTangible(address _newTangibleAddress) public _isActive returns (address) {
        require(shares[_msgSender()] > 0, 'Only shareholders can vote for switch tangible');

        // set senders vote
        tangibleVote[_msgSender()] = _newTangibleAddress;

        // calculate current amount of votes based on shareholders share
        uint256 totalVotePercentage = 0;
        for(uint256 i=0;i<shareholders.length;i++){
            if (tangibleVote[shareholders[i]] == _newTangibleAddress){
                totalVotePercentage += shares[shareholders[i]];
            }
        }

        // terminate contract
        if (totalVotePercentage > 50)
            tangibleAddress = _newTangibleAddress;

        return tangibleAddress;
    }

    // Terminate this contract, and pay-out all remaining investors
    function terminate() public override _isActive() returns (bool) {
        require(shares[_msgSender()] > 0, 'Only shareholders can vote for termination');

        // set senders vote
        terminationVote[_msgSender()] = true;

        // calculate current amount of votes based on shareholders share
        uint256 totalVotePercentage = 0;
        for(uint256 i=0;i<shareholders.length;i++){
            if (terminationVote[shareholders[i]]){
                totalVotePercentage += shares[shareholders[i]];
            }
        }

        // terminate contract
        if (totalVotePercentage > 50)
            terminated = true;

        return terminated;
    }


    // ----------------------------------------------------------------------------------------------------------
    // -------------------------------------------- PUBLIC GETTERS ----------------------------------------------
    // ----------------------------------------------------------------------------------------------------------


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
    function getShares(address _owner) public view returns (uint256) {
        return shares[_owner];
    }

    // wrapper for ERC20 / ERC721 wallet support
    function balanceOf(address _owner) public view returns (uint256) {
        return getShares(_owner);
    }

    function getTangible() public view returns (address){
        return tangibleAddress;
    }

    function isTerminated() public view returns (bool){
        return terminated;
    }

    // Return current price
    function getPrice() public view returns (uint256) {
      return lastPricePerUnit;
    }

    // Get shareholder addresses
    function getShareholders() public view returns (address[] memory) {
        return shareholders;
    }

    function getTax() public view returns (uint256) {
        return tangibleTax;
    }

    /// @notice A descriptive name of this Tangible Token
    function name() external override view returns (string memory){
        return _name;
    }

    /// @notice An abbreviated name expressing the share
    function symbol() external override view returns (string memory){
        return string.concat("% ", _symbol);
    }

    /// @notice A distinct Uniform Resource Identifier (URI)
    function tokenURI() external override view returns (string memory){
        return _tokenURI;
    }
}
