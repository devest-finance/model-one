// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "./DevestOne.sol";
import "./ITangibleStakeToken.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ERC20PresetFixedSupply} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

// DeVest Investment Model One
// Bid & Offer
contract DevestOneNative is DevestOne {

    // Set owner and DI OriToken
    constructor(address tokenAddress, string memory __name, string memory __symbol, address owner)
        DevestOne(tokenAddress ,__name, __symbol, owner) {
    }

    function payNative() public payable _isActive{
        require(initialized, 'Tangible was not initialized');
        require(!terminated, 'Share was terminated');
        require(msg.value > 0, 'Invalid amount provided');

        // pay tangible tax
        uint256 tangible = ((tangibleTax * msg.value) / 100);
        payable(tangibleAddress).transfer(tangible);

        // check if enough
        emit payment(_msgSender(), msg.value);

        if (instantDisburse)
            disburseNative();
    }

    // Distribute the balance in native tokens will be disbursed to all shareholders
    function disburseNative() public _isActive returns (uint256) {
        uint256 balance = payable(address(this)).balance;

        // pay shareholders
        for(uint256 i=0;i<shareholders.length;i++)
            payable(shareholders[i]).transfer((shares[shareholders[i]] * balance) / 100);

        return balance;
    }


}
