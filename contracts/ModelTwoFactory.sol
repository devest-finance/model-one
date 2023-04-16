// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import "./ModelTwo.sol";

contract ModelTwoFactory is Ownable {

    event TangibleDeployed(address indexed issuer_address, address indexed contract_address);
    event TokenDeployed(address indexed issuer_address, address indexed contract_address);

    bool private active = false;

    address[] internal tangibles;
    address[] internal tokens;

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

        ModelTwo tst = new ModelTwo(_tokenAddress, name, symbol, _msgSender(), root);

        tangibles.push(address(tst));
        emit TangibleDeployed(_msgSender(), address(tst));

        return address(tst);
    }

    function deploy(string memory name, string memory symbol, uint256 initialSupply) public payable returns (address)
    {
        // check fees and transfer to root
        require(msg.value >= fee, "Please provide the required fees");
        payable(root).transfer(msg.value);

        ERC20PresetFixedSupply token = new ERC20PresetFixedSupply(name, symbol, initialSupply, _msgSender());

        tokens.push(address(token));
        emit TokenDeployed(_msgSender(), address(token));

        return address(token);
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

}
