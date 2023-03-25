// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VestTokenHandler {

    address internal token;

    constructor(address tokenAddress){
        token = tokenAddress;
    }

    /**
     *  Internal token transfer
     */
    function __transfer(address receiver, uint256 amount) internal {
        if (token == address(0)){
            payable(receiver).transfer(amount);
        } else {
            IERC20 _token = IERC20(token);
            _token.transfer(receiver, amount);
        }
    }

    /**
     *  Internal token transferFrom
     */
    function __transferFrom(address sender, address receiver, uint256 amount) internal {
        if (token == address(0)){
            require(msg.value >= (amount), "Insufficient funds provided (value)");
        } else {
            IERC20 _token = IERC20(token);
            _token.transferFrom(sender, receiver, amount);
        }
    }

    /**
     *  Internal token balance
    */
    function __balanceOf(address account) internal returns (uint256) {
        if (token == address(0)){
            return address(account).balance;
        } else {
            IERC20 _token = IERC20(token);
            return _token.balanceOf(account);
        }
    }

    /**
     *  Internal token allowance
     */
    function __allowance(address account, uint256 amount) internal {
        if (token == address(0)){
            require(account != address(0), 'Invalid sender');
            require(msg.value >= amount, 'Insufficient token submitted');
        } else {
            IERC20 _token = IERC20(token);
            require(_token.allowance(account, address(this)) >= amount, 'Insufficient allowance provided');
        }
    }

}
