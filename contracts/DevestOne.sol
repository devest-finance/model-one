// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "./ITangibleStakeToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ERC20PresetFixedSupply} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

// DeVest Investment Model One
// Bid & Offer
contract DevestOne is ITangibleStakeToken, ReentrancyGuard {

    // ---------------------------- EVENTS ------------------------------------

    // When an shareholder exchanged his shares
    event swapped(address indexed from, address indexed to, uint256 share);

    // When new buy order was submitted and awaits acceptance
    event ordered(address indexed from, uint256 price, uint256 amount, bool bid);

    // When payment was received
    event payment(address indexed from, uint256 amount);

    // When dividends been disbursed
    event disbursed(uint256 amount);

    // ---------------------------------------------------------------------

    // reference to trading token used in TST
    IERC20 internal _token;

    // Owner of the contract (for admin controls)
    address private publisher;

    // DeVest DAO address for collecting fee's
    address private devestDAO;

    // contract was terminated and can't be used anymore
    bool public terminated = false;

    // initialized
    bool internal initialized = false;

    // instantDisburse
    // Disburse received payments instantly to shareholders
    // this could be a problem if the token has a high divider,
    // related to the amount of transactions required !!!
    bool instantDisburse;

    // Last price which was accepted in order book per unit
    uint256 public price = 0;

    // Shares contribution to the tangible
    uint256 public tangibleTax = 0;

    // Address of the tangible
    address public tangibleAddress;

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
    string public name;
    string public symbol;
    string _tokenURI;

    // voting (termination and tangible)
    mapping (address => bool) terminationVote;
    mapping (address => address) tangibleVote;

    // Set owner and DI OriToken
    constructor(address tokenAddress, string memory _name, string memory _symbol, address owner, address _devestDAO) {
        publisher = owner;
        devestDAO = _devestDAO;
        _token = IERC20(tokenAddress);
        symbol = string(abi.encodePacked("% ", _symbol));
        name = _name;
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
            //require(orders[orderOwner].escrow == 0, 'Escrow leftover'); // ????????????? WHAT IS THE PURPOSE OF THIS
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
        price = amount / 100;
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
    function bid(uint256 _price, uint256 amount) public payable virtual override nonReentrant _isActive{
        require(amount > 0 && amount <= 100, 'Invalid amount submitted');
        require(price > 0, 'Invalid price submitted');
        require(orders[_msgSender()].amount == 0, 'Active bid, cancel first');

        // add tax to escrow
        uint256 _escrow = _price * amount;
        _escrow += (_escrow * tangibleTax) / 100;

        // check if enough escrow allowed
        __allowance(_msgSender(), _escrow);

        // store bid
        Order memory _bid = Order(_price, amount, _msgSender(), _escrow, true);
        orders[_msgSender()] = _bid;
        orderAddresses.push(_msgSender());

        // pull escrow
        __transferFrom(_msgSender(), address(this), _escrow);

        emit ordered(_msgSender(), _price, amount, true);
    }

    /**
     *  Ask for sell
     */
    function ask(uint256 _price, uint256 amount) public payable override nonReentrant _isActive {
        require(amount > 0 && amount <= 100, 'Invalid amount submitted');
        require(_price > 0, 'Invalid price submitted');
        require(shares[_msgSender()]  > 0, 'Insufficient shares');
        require(orders[_msgSender()].amount == 0, 'Active order, cancel first');

        // store bid
        Order memory _ask = Order(_price, amount, _msgSender(), 0, false);
        orders[_msgSender()] = _ask;
        orderAddresses.push(_msgSender());

        emit ordered(_msgSender(), _price, amount, false);
    }

    /**
     *  Accept order
     */
    function accept(address orderOwner, uint256 amount) external override payable _isActive returns (uint256) {
        require(amount > 0, "Invalid amount submitted");
        require(orders[orderOwner].amount >= amount, "Invalid order");
        require(_msgSender() != orders[orderOwner].from, "Can't accept your own order");

        // check for fee and transfer to owner
        require(msg.value >= 10000000, "Please provide enough fee");
        if (devestDAO != address(0))
            payable(devestDAO).transfer(10000000);

        Order memory order = orders[orderOwner];

        // In case of bid, check if owner has enough shares
        if (order.bid == true)
            require(shares[_msgSender()] >= amount,"Insufficient shares");

        // calculate taxes
        uint256 cost = order.price * amount;
        uint256 tax = (cost * tangibleTax) / 100;
        uint256 totalCost = cost + tax;

        // accepting on bid order
        if (order.bid == true) {
            // accepting bid order
            // so caller is accepting to sell his share to order owner
            // -> escrow from order can be transferred to owner
            __transfer(_msgSender(), cost);
        } else {
            // what the buyer needs to pay (including taxes)
            __transferFrom(_msgSender(), address(this), totalCost);
            __transfer(order.from, cost);
        }

        // pay tangibles
        if (tax != 0)
            __transfer(tangibleAddress, tax);

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
        price = order.price;

        // TODO cover different event when accepting bid/ask
        emit swapped(_msgSender(), orderOwner, amount);

        return cost;
    }

    // Cancel order and return escrow
    function cancel() public virtual override _isActive() returns (bool) {
        require(orders[_msgSender()].amount > 0, 'No open bid');

        Order memory _order = orders[_msgSender()];
        // return escrow leftover
        if (_order.bid)
            __transfer(_msgSender(), _order.escrow);

        // update bids
        deductAmountfromOrder(_msgSender(), _order.amount);

        return true;
    }

    // Pay usage charges
    function pay(uint256 amount) public payable override _isActive{
        require(initialized, 'Tangible was not initialized');
        require(!terminated, 'Share was terminated');
        require(amount > 0, 'Invalid amount provided');

        // charge fee
        require(msg.value >= 10000000, "Please provide enough fee");
            payable(devestDAO).transfer(10000000);

        // check if enough escrow allowed and pull
        __allowance(_msgSender(), amount);
        __transferFrom(_msgSender(), address(this), amount);

        // pay tangible tax
        uint256 tangible = ((tangibleTax * amount) / 100);
        __transfer(tangibleAddress, tangible);

        // disburse if auto disburse
        if (instantDisburse == true)
            disburse();

        emit payment(_msgSender(), amount);
    }

    // Distribute funds on TST to shareholders
    function disburse() public override _isActive returns (uint256) {
        uint256 balance = __balanceOf(address(this));
        balance -= escrow;

        // distribute to shareholders
        for(uint256 i=0;i<shareholders.length;i++)
            __transfer(shareholders[i], (shares[shareholders[i]] * balance) / 100);

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
        if (totalVotePercentage > 50){
            disburse();
            terminated = true;
        }

        return terminated;
    }


    // ----------------------------------------------------------------------------------------------------------
    // -------------------------------------------- TOKEN MANAGEMENT --------------------------------------------
    // ----------------------------------------------------------------------------------------------------------

    /**
    *  Internal token transfer
    */
    function __transfer(address receiver, uint256 amount) internal virtual {
        _token.transfer(receiver, amount);
    }

    /**
   *  Internal token balance
   */
    function __balanceOf(address account) internal virtual returns (uint256) {
        return _token.balanceOf(account);
    }

    /**
     *  Internal token allowance
     */
    function __allowance(address account, uint256 amount) internal virtual {
        require(_token.allowance(account, address(this)) >= amount, 'Insufficient allowance provided');
    }

    /**
     *  Internal token transferFrom
     */
    function __transferFrom(address sender, address receiver, uint256 amount) internal virtual {
        _token.transferFrom(sender, receiver, amount);
    }

    // ----------------------------------------------------------------------------------------------------------
    // -------------------------------------------- PUBLIC GETTERS ----------------------------------------------
    // ----------------------------------------------------------------------------------------------------------


    // Get orders (open)
    function getOrders() public view returns (Order[] memory) {
        Order[] memory _orders = new Order[](orderAddresses.length);

        for(uint256 i=0;i< orderAddresses.length;i++)
            _orders[i] = orders[orderAddresses[i]];

        return _orders;
    }


    // Get shares of one investor
    function balanceOf(address _owner) public view returns (uint256) {
        return shares[_owner];
    }

    // Get shares of one investor
    function getShares(address _owner) public view returns (uint256) {
        return shares[_owner];
    }

    // Get shareholder addresses
    function getShareholders() public view returns (address[] memory) {
        return shareholders;
    }

    /// @notice A distinct Uniform Resource Identifier (URI)
    function tokenURI() external override view returns (string memory){
        return _tokenURI;
    }

}
