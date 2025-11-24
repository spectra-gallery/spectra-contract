// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./IProjectRegistry.sol";

contract ProjectRegistry is IProjectRegistry {
    address public owner;
    mapping(address => bool) public writers;
    mapping(uint256 => Project) internal projects;

    modifier onlyWriter() {
        require(msg.sender == owner || writers[msg.sender], "not authorized");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function authorize(address who, bool canWrite) external {
        require(msg.sender == owner, "only owner");
        writers[who] = canWrite;
    }

    function setProject(uint256 id, Project calldata p) external onlyWriter {
        projects[id] = p;
    }

    function getProject(uint256 projectId) external view returns (Project memory) {
        return projects[projectId];
    }
}
