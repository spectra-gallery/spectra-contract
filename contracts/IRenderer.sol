// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IRenderer {
    function tokenURIFor(address spectra, uint256 tokenId) external view returns (string memory);
}

