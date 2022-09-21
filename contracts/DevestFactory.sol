// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "./DevestOne.sol";
import "./DevestOneNative.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DevestFactory is Ownable {

    event TangibleDeployed(address indexed issuer_address, DevestOne indexed contract_address);

    bool private active = false;

    address[] private tangibles;

    uint256 public fee;
    address payable public root = payable(address(0));

    constructor() Ownable() {
        active = true;

    }

    function issue(address _tokenAddress, string memory name, string memory symbol) public payable returns (address)
    {
        // check fees and transfer to root
        require(msg.value >= fee, "Please provide the required fees");
        payable(root).transfer(msg.value);

        DevestOne tst;

        // if no token address submitted, tst will be native.
        if (_tokenAddress == address(0)){
            tst = new DevestOneNative(name, symbol, _msgSender(), root);
        } else {
            tst = new DevestOne(_tokenAddress, name, symbol, _msgSender(), root);
        }

        tangibles.push(address(tst));
        emit TangibleDeployed(_msgSender(), tst);

        return address(tst);
    }

    function history(uint256 offset) public view returns (address[] memory)
    {
        require(offset <= tangibles.length, "Invalid offset");

        //  temp array (from offset)
        address[] memory stores = new address[](10);

        uint count = tangibles.length;

        for (uint a = offset;a < count; a++)
            stores[a] = tangibles[offset + a];

        return stores;
    }

    // update fee
    function setFee(uint256 _fee) public onlyOwner {
        fee = _fee;
    }

    // change the root (TST / DAO) recipient of fees
    function setRoot(address payable _root) public onlyOwner {
        root = _root;
    }

    // disable this deployer for further usage
    function terminate() public onlyOwner {
        active = false;
    }

    /*
    function pay(address payable recipient) public payable {
        payable(recipient).transfer(1);
    }*/

}
