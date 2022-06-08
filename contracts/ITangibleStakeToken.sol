// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/**
 * @dev Interface of first draft of TST - Tangible Stake Token
 */
interface ITangibleStakeToken {

    // Bid a price for shares, (shareholder accepts bid to swap)
    function bid(uint256 price, uint256 amount) external returns (bool);

    // Ask for a price, (shareholder offers share to respective price)
    function ask(uint256 price, uint256 amount) external;

    // Accept bid and sell shares
    function accept(address bidder, uint256 amount) external payable;

    // Cancel all orders from this address
    function cancel() external returns (bool);

    // Terminate
    function terminate() external returns (bool);

}
