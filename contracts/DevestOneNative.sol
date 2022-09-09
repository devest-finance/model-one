// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "./DevestOne.sol";
import "./ITangibleStakeToken.sol";

// DeVest Investment Model One
// Bid & Offer
// Implements Native Token support
contract DevestOneNative is DevestOne {

    // Set owner and DI OriToken
    constructor(address tokenAddress, string memory __name, string memory __symbol, address owner)
        DevestOne(tokenAddress ,__name, __symbol, owner) {
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
        //_token.transferFrom(sender, receiver, amount);
    }

}
