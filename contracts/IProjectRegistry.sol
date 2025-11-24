// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IProjectRegistry {
    struct Animation { string html; string css; string js; }
    struct Project {
        bytes32 name;
        string description;
        bytes32 artist;
        string image;
        address artistAddress;
        uint256 price;
        uint256 supply;
        uint256 maxSupply;
        bool onSale;
        Animation animation;
    }
    function getProject(uint256 projectId) external view returns (Project memory);
    function setProject(uint256 id, Project calldata p) external;
}
