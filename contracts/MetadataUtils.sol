// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

contract MetadataUtils {
    using Strings for uint256;

    // Attribute types (string-based) for flexible external callers
    struct Attribute {
        string trait_type;
        string value;
    }
    struct Attributes {
        Attribute[] attributes;
    }

    // Attribute type matching Spectra's bytes32 compact representation
    struct AttributeB32 {
        bytes32 trait_type;
        bytes32 value;
    }

    function parseAnimation(
        string memory css,
        string memory html,
        string memory js,
        bytes32 hash,
        string memory baseURI
    ) public pure returns (string memory) {
        string memory mintingHash = string(
            abi.encodePacked(Strings.toHexString(uint256(hash), 32))
        );

        string memory seed = string(
            abi.encodePacked(
                "'<script>",
                "var injectedSeed = ",
                "'",
                mintingHash,
                "';",
                "</script>'"
            )
        );

        string memory animationString = string(
            abi.encodePacked(
                "<!DOCTYPE html>",
                "<html>",
                "<head>",
                "<style>",
                css,
                "</style>",
                seed,
                "'</head>",
                "<body>",
                html,
                "<script>",
                js,
                "</script>",
                "'</body>",
                "</html>"
            )
        );

        return string(
            abi.encodePacked(baseURI, Base64.encode(bytes(animationString)))
        );
    }

    function buildTokenJSON(
        bytes32 name,
        string memory description,
        string memory image,
        string memory animationUrl,
        string memory attributes,
        string memory baseURI
    ) public pure returns (string memory) {
        bytes memory dataURI = abi.encodePacked(
            "{",
            encodeKeyValue("name", name),
            encodeKeyValue("description", description),
            encodeKeyValue("image", image),
            encodeKeyValue("animation_url", animationUrl),
            encodeAttributes(attributes),
            "}"
        );
        return string(abi.encodePacked(baseURI, Base64.encode(dataURI)));
    }

    function buildProjectJSON(
        bytes32 name,
        string memory description,
        string memory image,
        bytes32 artist,
        uint256 price,
        uint256 supply,
        uint256 maxSupply,
        bool onSale,
        string memory baseURI
    ) public pure returns (string memory) {
        bytes memory dataURI = abi.encodePacked(
            "{",
            encodeKeyValue("name", name),
            encodeKeyValue("description", description),
            encodeKeyValue("image", image),
            encodeKeyValue("artist", artist),
            encodeKeyValue("price", Strings.toString(price)),
            encodeKeyValue("supply", Strings.toString(supply)),
            encodeKeyValue("maxSupply", Strings.toString(maxSupply)),
            encodeKeyValue("onSale", onSale ? "true" : "false"),
            "}"
        );
        return string(abi.encodePacked(baseURI, Base64.encode(dataURI)));
    }

    function encodeKeyValue(
        bytes32 key,
        bytes32 value
    ) public pure returns (bytes memory) {
        return abi.encodePacked('"', key, '": "', value, '", ');
    }

    function encodeKeyValue(
        string memory key,
        string memory value
    ) public pure returns (bytes memory) {
        return abi.encodePacked('"', key, '": "', value, '", ');
    }

    function encodeAttributes(
        string memory _attributes
    ) public pure returns (bytes memory) {
        return abi.encodePacked('"traits": ', _attributes);
    }

    function parseAttributesB32(
        AttributeB32[] memory attributes
    ) public pure returns (string memory) {
        string memory attributesString = "[";
        for (uint256 i = 0; i < attributes.length; i++) {
            attributesString = string(
                abi.encodePacked(
                    attributesString,
                    "{",
                    '"trait_type":"',
                    attributes[i].trait_type,
                    '",',
                    '"value":"',
                    attributes[i].value,
                    '"',
                    "}"
                )
            );

            if (i < attributes.length - 1) {
                attributesString = string(
                    abi.encodePacked(attributesString, ",")
                );
            }
        }

        attributesString = string(abi.encodePacked(attributesString, "]"));
        return attributesString;
    }
}
