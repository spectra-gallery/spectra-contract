// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./IRenderer.sol";
import "./MetadataUtils.sol";
import "./GenerativeLib.sol";

interface ISpectraLike {
    function baseURI() external view returns (string memory);
    function getTokenPayload(uint256 tokenId) external view returns (
        bytes32 name,
        string memory description,
        string memory image,
        string memory css,
        string memory html,
        string memory js,
        bytes32 hash
    );
    function getTokenAttributes(uint256 tokenId) external view returns (string memory);
}

contract RendererSpectraV1 is IRenderer {
    MetadataUtils public metadata;

    constructor(address metadataUtils) {
        metadata = MetadataUtils(metadataUtils);
    }

    function tokenURIFor(address spectra, uint256 tokenId) external view returns (string memory) {
        ISpectraLike s = ISpectraLike(spectra);
        (bytes32 name, string memory description, string memory image, string memory css, string memory html, string memory js, bytes32 hash) = s.getTokenPayload(tokenId);
        string memory attrs = s.getTokenAttributes(tokenId);
        string memory animationString = metadata.parseAnimation(css, html, js, hash, s.baseURI());
        return metadata.buildTokenJSON(name, description, image, animationString, attrs, s.baseURI());
    }
}
