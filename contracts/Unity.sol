// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./AccessControl.sol";

contract Unity {
    AccessControl accessControl;
    address accessControlAddress;

    mapping(address => uint256) private balances;

    mapping(address => bool) private isUser;

    address[] private users;

    mapping(address => uint256) private lastDividendPerShare;

    uint256 private dividendPerShare;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event DividendDistributed(uint256 amount);
    event DividendClaimed(address indexed user, uint256 amount);

    constructor(address _accessControl, address _metadataUtilsAddress) {
        accessControlAddress = _accessControl;
        accessControl = AccessControl(_accessControl);
    }

    function deposit() public payable {
        require(msg.value > 0, "Deposit amount must be greater than zero");

        // If the sender is a new user, add them to the users array
        if (!isUser[msg.sender]) {
            isUser[msg.sender] = true;
            users.push(msg.sender);

            accessControl.grantRoleByDAO(AccessControl.Role.Myself, msg.sender);
        }

        uint256 numberOfUsers = users.length;
        require(numberOfUsers > 0, "No users to distribute to");

        // Update dividend per share
        dividendPerShare += (msg.value / numberOfUsers);
        emit DividendDistributed(msg.value);
    }

    // Function for users to claim their dividends
    function claimDividend() external _requireHasRole(AccessControl.Role.Myself) {
        require(isUser[msg.sender], "Not a user");

        uint256 owed = dividendPerShare - lastDividendPerShare[msg.sender];
        require(owed > 0, "No dividends to claim");

        lastDividendPerShare[msg.sender] = dividendPerShare;

        // Update the user's balance
        balances[msg.sender] += owed;

        emit DividendClaimed(msg.sender, owed);
    }

    // Withdraw function to retrieve Ether from the contract
    function withdraw(uint256 _amount) external _requireHasRole(AccessControl.Role.Myself) {
        require(_amount > 0, "Withdraw amount must be greater than zero");
        require(balances[msg.sender] >= _amount, "Insufficient balance");

        // Update the user's balance before transferring to prevent reentrancy
        balances[msg.sender] -= _amount;

        // Transfer the Ether to the user
        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success, "Transfer failed");

        emit Withdrawn(msg.sender, _amount);
    }

    // View function to check the user's balance
    function getBalance() external view returns (uint256) {
        return balances[msg.sender];
    }

    // View function to check pending dividends
    function pendingDividend(address user) external view returns (uint256) {
        if (!isUser[user]) return 0;
        return dividendPerShare - lastDividendPerShare[user];
    }

    // Get the total number of users
    function getTotalUsers() external view returns (uint256) {
        return users.length;
    }

    // Get a user address by index
    function getUser(uint256 index) external view returns (address) {
        require(index < users.length, "Index out of bounds");
        return users[index];
    }

    function setAccessControl(address _accessControl) public {
        require(
            accessControl.hasRole(AccessControl.Role.Admin, msg.sender),
            "You are not an admin"
        );
        accessControl = AccessControl(_accessControl);
    }

    // Fallback and receive functions to handle direct Ether transfers
    receive() external payable {
        deposit();
    }

    fallback() external payable {
        deposit();
    }

    modifier _requireHasRole(AccessControl.Role role) {
        require(
            accessControl.hasRole(role, msg.sender),
            "Spectra: must have role"
        );
        _;
    }
}
