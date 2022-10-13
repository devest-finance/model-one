// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/**
 * @dev Interface of first draft of Tangible Stake Token - TST
 */
interface ITangibleStakeToken {

    // Bid a price for shares, (shareholder accepts bid to swap)
    function bid(uint256 price, uint256 amount) payable external;

    // Ask for a price, (shareholder offers share to respective price)
    function ask(uint256 price, uint256 amount) payable external;

    // Accept bid and sell shares
    function accept(address bidder, uint256 amount) external payable returns (uint256);

    // Cancel all orders from this address
    function cancel() external returns (bool);

    // Pay charges or costs
    function pay(uint256 amount) payable external;

    // Disburse funds
    function disburse() external returns (uint256);

    // Terminate
    function terminate() external returns (bool);

    /// @notice A descriptive name of this Tangible Token
    function name() external view returns (string memory);

    /// @notice An abbreviated name expressing the share
    function symbol() external view returns (string memory);

    /// @notice A distinct Uniform Resource Identifier (URI)
    function tokenURI() external view returns (string memory);

}
