// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "./DevestOne.sol";
import "./ITangibleStakeToken.sol";

// DeVest Investment Model One
// Bid & Offer
// Implements Native Token support
contract DevestOneNative is DevestOne {

    // Set owner and DI OriToken
    constructor(string memory __name, string memory __symbol, address owner, address devestDAO)
        DevestOne(address(0) ,__name, __symbol, owner, devestDAO) {
    }

    /**
     *  Internal token transfer helper
     */
    function __transfer(address receiver, uint256 amount) override internal {
        payable(receiver).transfer(amount);
    }

    /**
     *  Internal token transfer helper
     *  In case of native transaction the amount was submitted with
     *  the transaction is available on the contract
     *  => no action required
     */
    function __transferFrom(address sender, address receiver, uint256 amount) override internal {
        require(msg.value >= (amount), "Insufficent funds provided (value)");
    }

    /**
     *  Internal token balance
     */
    function __balanceOf(address account) override internal virtual returns (uint256) {
        return address(account).balance;
    }

    /**
     *  Internal token allowance
     *  In case of native token, there is now allowance but we need to verify
     *  the sender submitted enough tokens with the transaction (value)
     */
    function  __allowance(address sender, uint256 amount) override internal virtual {
        require(sender != address(0), 'Invalid sender');
        require(msg.value >= amount, 'Insufficient token submitted');
    }

    // Function to receive Ether only allowed when contract Native Token
    receive() external payable {}

}
