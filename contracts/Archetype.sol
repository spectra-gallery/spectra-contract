// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./AccessControl.sol";

contract Archetype is ERC20 {
    AccessControl accessControl; 
    address accessControlAddress;

    constructor(string memory _name, string memory _symbol, address _accessControl) public ERC20(_name, _symbol) { 
        accessControlAddress = _accessControl;
        accessControl = AccessControl(_accessControl);
    }

    function mint(address account, uint256 amount) public _requireHasRole(AccessControl.Role.Admin) {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public _requireHasRole(AccessControl.Role.Admin) {
        _burn(account, amount);
    }

    modifier _requireHasRole (AccessControl.Role role) {
        require(accessControl.hasRole(role, msg.sender), "Spectra: must have role");
        _;
    }
}