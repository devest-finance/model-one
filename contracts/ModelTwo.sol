// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "./ITangibleStakeToken.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./VestingToken.sol";

/** errors
E1 : Only owner can initialize tangibles
E2 : Tangible was terminated
E3 : Tangible already initialized
E4 : Only owner can initialize tangibles
E5 : Invalid tax value
E6 : Invalid tax value
E7 : Currently only max 2 decimals supported
E8 : Amount must be bigger than 100
E9 : Invalid amount submitted
E10 : Invalid price submitted
E11 : Active buy order, cancel first
E12 : Invalid amount submitted
E13 : Invalid price submitted
E14 : Insufficient shares
E15 : Active order, cancel first
E16 : Invalid amount submitted
E17 : Invalid order
E18 : Can't accept your own order
E19 : Insufficient shares
E20 : No open bid
E21 : Tangible was not initialized
E22 : Share was terminated
E23 : Invalid amount provided
E24 : Only shareholders can vote for switch tangible
E25 : Only owner can termination
E26 : Only DeVest can update Fees
*/


// DeVest Investment Model One
// Bid & Offer
contract ModelTwo is ITangibleStakeToken, VestingToken, ReentrancyGuard, Context {

    // ---------------------------- EVENTS ------------------------------------

    // When an shareholder exchanged his shares
    event swapped(address indexed from, address indexed to, uint256 share, uint256 totalCost);

    // When dividends been disbursed
    event disbursed(uint256 amount);

    // ---------------------------- ERRORS --------------------------------


    // ---------------------------------------------------------------------

    // Owner of the contract (for admin controls)
    address internal immutable publisher;

    // DeVest DAO address for collecting fee's
    address private devestDAO;
    uint256 public fees = 10000000;

    // contract was terminated and can't be used anymore
    bool public terminated = false;

    // initialized
    bool internal initialized = false;

    // The inital price set by publisher
    uint256 public initalValue = 0;

    // the reserves
    uint256 public reservesShares;
    uint256 public reservesTokens;

    // Shares contribution to the tangible
    uint256 public tangibleTax = 0;

    // Stakes
    mapping (address => uint256) internal shares;                   // shares of shareholder
    mapping (address => uint256) internal shareholdersIndex;        // index of the shareholders address
    address[] internal shareholders;                                // all current shareholders

    // metadata
    string public name;
    string public symbol;
    uint8 public decimal;
    string _tokenURI;

    // voting (termination and tangible)
    mapping (address => address) tangibleVote;

    // ---- assets

    // assets added to this fund
    struct Asset {
        address token;
        uint256 amount;
        uint256 disbursed;
    }
    Asset[] public assets;

    // Set owner and DI OriToken
    constructor(address _tokenAddress, string memory _name, string memory _symbol, address owner, address _devestDAO)
    VestingToken(_tokenAddress) {
        publisher = owner;
        devestDAO = _devestDAO;
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
        require(initialized, 'E1');
        require(!terminated, 'E2');
        _;
    }

    /**
     * Verify enough fee (value) was provided and take
     */
    modifier _takeFee() {
        // check for fee and transfer to owner
        require(msg.value >= fees, "Please provide enough fee");
        payable(devestDAO).transfer(fees);
        _;
    }

    // ----------------------------------------------------------------------------------------------------------
    // ------------------------------------------------ INTERNAL ------------------------------------------------
    // ----------------------------------------------------------------------------------------------------------

    function swapShares(address to, address from, uint256 amount) internal {
        // if shareholder has no shares add him as new
        if (shares[to] == 0) {
            shareholdersIndex[to] = shareholders.length;
            shareholders.push(to);
        }

        shares[to] += amount;
        shares[from] -= amount;

        /*
        // remove shareholder without shares
        if (shares[from] == 0){
            shareholders[shareholdersIndex[from]] = shareholders[shareholders.length-1];
            shareholders.pop();
        }*/
    }

    // ----------------------------------------------------------------------------------------------------------
    // ------------------------------------------------- PUBLIC -------------------------------------------------
    // ----------------------------------------------------------------------------------------------------------

    /**
     *  Initialize TST as tangible
     */
    function initialize(uint256 _initialValue, uint _tax) public virtual returns (bool){
        require(!initialized, 'E3');
        require(publisher == _msgSender(), 'E4');
        require(_tax >= 0 && _tax <= 100, 'E5');

        uint256 totalShares = 1000;
        require(_initialValue >= totalShares, 'E8');

        tangibleTax = _tax;
        initalValue = _initialValue;

        reservesTokens = _initialValue;
        reservesShares = totalShares;

        shareholders.push(_msgSender());
        shares[_msgSender()] = totalShares;

        // start bidding
        initialized = true;

        return true;
    }

    // ----------------------------------------------------------------------------------------------------------
    // ------------------------------------------------ TRADING -------------------------------------------------

    /**
    * Swap shares between owners,
    * Check for same level of disburse !!
    */
    function transfer(address recipient, uint256 amount) external payable _takeFee{
        require(_msgSender() != publisher, 'Publisher cannot transfer shares');

        swapShares(recipient, _msgSender(), amount);
    }

    function sellTest(uint256 amountIn, uint256 amountOutMin) public payable virtual returns (uint256){
        require(amountOutMin > 0 && amountOutMin <= 1000, 'E9');

        // (100 + 50) / (5000 + 50) =
        uint256 _amountOut = (reservesTokens * amountIn) / (reservesShares + amountIn);

        swapShares(publisher, _msgSender(), amountIn);

        return _amountOut;
    }

    /**
    *  Buy Shares
    *  amountIn: How much tokens to Spend
    *  amountOutMin: Minimal amount of shares to accept (according to price-movement)
    */
    function buy(uint256 amountIn, uint256 amountOutMin) public payable virtual override _takeFee nonReentrant _isActive{
        require(amountOutMin > 0 && amountOutMin <= 1000, 'E9');

        uint256 _amountOut = (reservesShares * amountIn) / (reservesTokens + amountIn);
        require(_amountOut > 0, 'PURCHASE QUANTITY TO LOW');
        //require(_amountOut > amountOutMin, 'SLIPPAGE FAILED');

        // calculate tax and charge and pull tokens
        uint256 _taxCharge = (amountIn * tangibleTax) / 1000;
        uint256 _totalCost = amountIn + _taxCharge;
        __transferFrom(_msgSender(), address(this), _totalCost);

        // swap shares from publisher (manager) to new owner
        swapShares(_msgSender(), publisher, _amountOut);

        // pay tax
        __transfer(publisher, _taxCharge);

        // update balances
        reservesShares -= _amountOut;
        reservesTokens += amountIn;
    }

    /**
     *  Sell order
     */
    function sell(uint256 sharesIn, uint256 tokensOutMin) public payable override _takeFee nonReentrant _isActive {
        require(sharesIn > 0 && sharesIn <= 1000, 'E12');
        require(shares[_msgSender()]  > 0, 'E14');

        uint256 _amountOut = (reservesTokens * sharesIn) / (reservesShares + sharesIn);
        //require(_amountOut > tokensOutMin, 'SLIPPAGE FAILED');

        // swap shares from publisher (manager) to new owner
        swapShares(publisher, _msgSender(), sharesIn);

        __transfer(_msgSender(), _amountOut);

        // update balances
        reservesShares += sharesIn;
        reservesTokens -= _amountOut;
    }

    // Terminate this contract, and pay-out all remaining investors
    function terminate() public override _isActive returns (bool) {
        require(publisher == _msgSender(), 'E25');

        terminated = true;

        return terminated;
    }

    // ----------------------------------------------------------------------------------------------------------
    // -------------------------------------------- PUBLIC GETTERS ----------------------------------------------
    // ----------------------------------------------------------------------------------------------------------

    /**
    *  Add a token to the fund
    *  token: address of token to add
    *  amount: amount to add
    */
    function addAsset(address token, uint256 amount) public payable virtual nonReentrant {
        require(token != _vestingToken, "Vesting token cannot be added as Asset");
        require(!initialized, 'Tangible already initialized');
        require(amount >= 0, 'Invalid amount');

        IERC20 _token = IERC20(token);

        // transfer assets to this contract
        _token.transferFrom(_msgSender(), address(this), amount);

        assets.push(Asset(token, amount, 0));
    }

    function withdraw() public payable nonReentrant{
        require(shares[_msgSender()] > 0, 'No shares available');

        require(terminated, 'Withdraw is only possible after termination');

        // publisher also receives trading asset
        if (_msgSender() == publisher){
            uint256 balance = __balanceOf(address(this));
            __transfer(_msgSender(), balance);
        }

        // receive shares of assets
        for(uint256 i=0;i<assets.length;i++){
            IERC20 _token = IERC20(assets[i].token);
            uint256 amount = ((shares[_msgSender()] * assets[i].amount) / 1000);
            _token.transfer(_msgSender(), amount);
        }

        shares[_msgSender()] = 0;
    }


    // ----------------------------------------------------------------------------------------------------------
    // -------------------------------------------- PUBLIC GETTERS ----------------------------------------------
    // ----------------------------------------------------------------------------------------------------------

    struct AssetInfo {
        address token;
        uint256 balance;
    }

    function getAssetBalance() public view returns (AssetInfo[] memory){
        AssetInfo[] memory _assets = new AssetInfo[](assets.length);

        for(uint256 i=0;i<assets.length;i++){
            IERC20 _token = IERC20(assets[i].token);
            _assets[i] = AssetInfo(assets[i].token, _token.balanceOf(address(this)));
        }

        return _assets;
    }

    function setFees(uint256 _fees) public {
        require(_msgSender() == devestDAO, "E26");
        fees = _fees;
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

    // ---
    function accept(address bidder, uint256 amount) external payable returns (uint256){
        return 0;
    }
    function cancel() external returns (bool){
        return false;
    }
    function disburse() external returns (uint256){
        return 0;
    }
    function pay(uint256 amount) payable external {}

// Function to receive Ether only allowed when contract Native Token
    receive() external payable {}

}
