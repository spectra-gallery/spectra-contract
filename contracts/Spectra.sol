// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "./AccessControl.sol";
import "./MetadataUtils.sol";

contract Spectra is ERC721, ERC2981 {
    MetadataUtils metadataUtils;
    address metadataUtilsAddress;

    AccessControl accessControl;
    address accessControlAddress;
    uint256 private _projectIdCounter;
    uint256 constant ONE_THOUSAND = 1_000;

    uint256 public artistPaymentPercentage = 90;
    using Strings for uint256;

    event Minted(
        address indexed minter,
        uint256 indexed tokenId,
        uint256 indexed projectid,
        uint256 value
    );
    /*
event TokenTransfer(
uint256 indexed token, uint256 indexed value, address indexed triggeredBy
);
event RoyaltySent (
uint256 indexed token, uint256 indexed value, address indexed triggeredBy
); */

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
    struct Animation {
        string html;
        string css;
        string js;
    }

    // Attributes trait types
    struct Attribute {
        bytes32 trait_type;
        bytes32 value;
    }

    mapping(uint256 => Project) projects;
    // mapping(uint256 => Hash) hashes;
    mapping(uint256 => bytes32) hashes;
    mapping(uint256 => string) token_attributes;
    mapping(uint256 => string) images;
    mapping(uint256 => uint256) public tokenIdToProjectId;
    mapping(uint256 => uint256[]) internal projectIdToTokenIds;
    mapping(uint256 => uint256) public tokenIdToPricePerTokenInWei;

    constructor(
        address _accessControl,
        address _metadataUtilsAddress
    ) ERC721("Spectra", "S8") {
        accessControlAddress = _accessControl;
        accessControl = AccessControl(_accessControl);

        metadataUtilsAddress = _metadataUtilsAddress;
        metadataUtils = MetadataUtils(_metadataUtilsAddress);
    }

    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        Project storage _project = projects[tokenIdToProjectId[tokenId]];
        Animation storage _animation = _project.animation;
        // bytes32 hash = hashes[tokenId].hash;
        bytes32 hash = hashes[tokenId];

        string memory animationString = metadataUtils.parseAnimation(
            _animation.css,
            _animation.html,
            _animation.js,
            hash,
            _baseURI()
        );
        string memory _image = images[tokenId];
        string memory attributeString = token_attributes[tokenId];

        bytes memory dataURI = abi.encodePacked(
            "{",
            encodeKeyValue("name", _project.name),
            encodeKeyValue("description", _project.description),
            encodeKeyValue("image", _image),
            encodeKeyValue("animation_url", animationString),
            encodeAttributes(attributeString),
            "}"
        );

        return string(abi.encodePacked(_baseURI(), Base64.encode(dataURI)));
    }

    function encodeKeyValue(
        bytes32 key,
        bytes32 value
    ) internal pure returns (bytes memory) {
        return abi.encodePacked('"', key, '": "', value, '", ');
    }

    function encodeKeyValue(
        string memory key,
        string memory value
    ) internal pure returns (bytes memory) {
        return abi.encodePacked('"', key, '": "', value, '", ');
    }

    function encodeAttributes(
        string memory _attributes
    ) internal pure returns (bytes memory) {
        return abi.encodePacked('"traits": ', _attributes);
    }

    function create(
        address _artistAddress,
        bytes32 _name,
        string memory _description,
        bytes32 _artist,
        string memory _image,
        uint256 price,
        uint256 _maxSupply,
        Animation memory animation
    ) public _requireHasRole(AccessControl.Role.Creator) returns (uint256) {
        uint256 projectId = _projectIdCounter;
        _projectIdCounter += 1;
        Project storage project = projects[projectId];
        Animation memory _animation = Animation({
            html: animation.html,
            css: animation.css,
            js: animation.js
        });
        project.name = _name;
        project.description = _description;
        project.artist = _artist;

        project.image = _image;
        project.supply = 0;
        project.maxSupply = _maxSupply;
        project.onSale = false;
        project.animation = _animation;
        project.artistAddress = _artistAddress;
        project.price = price;
        return projectId;
    }

    function mint(
        address account,
        uint256 projectId
    ) public payable returns (uint256) {
        Project storage project = projects[projectId];

        uint256 value = project.price;
        require(msg.value >= value, "Not enough ETH");

        require(project.supply + 1 <= project.maxSupply, "Max supply reached");
        require(project.onSale == true, "Token not for sale");
        uint256 tokenId = (projectId * ONE_THOUSAND) + project.supply;
        project.supply = project.supply + 1;

        tokenIdToProjectId[tokenId] = projectId;
        projectIdToTokenIds[projectId].push(tokenId);

        _safeMint(account, tokenId);

        uint256 artistPayment = (msg.value * artistPaymentPercentage) / 100;
        // uint256 contractPayment = msg.value - artistPayment;

        // address payable artist = payable(project.artistAddress);
        // payable(artist).transfer(artistPayment);

        // Use call instead of transfer for more flexibility
        (bool successArtist, ) = project.artistAddress.call{
            value: artistPayment
        }("");
        require(successArtist, "Transfer to artist failed");

        emit Minted(account, tokenId, projectId, value);

        return tokenId;
    }

    // assign token hash, image and attributes
    function assign(
        uint256 tokenId,
        string memory _image,
        bytes32 _hash,
        Attribute[] memory attribute
    ) public _requireHasRole(AccessControl.Role.Admin) returns (uint256) {
        _requireMinted(tokenId);

        hashes[tokenId] = _hash;
        token_attributes[tokenId] = parseAttributes(attribute);
        images[tokenId] = _image;

        return tokenId;
    }

    /*
    function mint(
        address account,
        uint256 projectId,
        bytes32 _image,
        bytes32 _hash,
        Attribute[] memory attribute
    ) public payable returns (uint256) {
      
        Project storage project = projects[projectId];
        
        uint256 value = project.price;
        require(msg.value > value, "Not enough ETH");
      
        require(project.supply + 1 <= project.maxSupply, "Max supply reached");
        require(project.onSale = true, "Token not for sale");
        uint256 tokenId = (projectId * ONE_THOUSAND) + project.supply;
        project.supply = project.supply + 1;

        tokenIdToProjectId[tokenId] = projectId;
        projectIdToTokenIds[projectId].push(tokenId);

   
        hashes[tokenId].hash = _hash;


        attributes[tokenId] = parseAttributes(attribute);
        images[tokenId] = _image;

        _safeMint(account, tokenId);
     
        uint256 artistPayment = (msg.value * artistPaymentPercentage) / 100;
        uint256 contractPayment = msg.value - artistPayment;
     
        address payable artist = payable(project.artistAddress);
        payable(artist).transfer(artistPayment);
     
        address payable contractAddress = payable(address(this));
        payable(contractAddress).transfer(contractPayment);

        emit Minted(account, tokenId, projectId, value);
    
        return tokenId;
    }
    */

    function parseAttributes(
        Attribute[] memory attributes
    ) internal pure returns (string memory) {
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

    function mintingHash(uint256 tokenId) internal view returns (bytes32) {
        return
            keccak256(abi.encodePacked(tokenId, block.number, block.timestamp));
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
    function _baseURI() internal view virtual override returns (string memory) {
        return "data: application/json;base64,";
    }
    /*
// override _increaseBalance from ERC721 and ERC721Enumerable
function _increaseBalance(address to, uint128 value) internal override (ERC721) {
super._increaseBalance(to, value);
}
*/
    /*
function _decreaseBalance(address to, uint128 value) internal {
    uint128 _value = value - 1;
super._increaseBalance(to, _value);
}
*/

    // override _update
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721) returns (address) {
        // address from = _ownerOf(tokenId);

        address from = super._update(to, tokenId, auth);

        if (from != address(0) && to != address(0)) {
            // Transfer
            tokenIdToPricePerTokenInWei[tokenId] = 0;

            accessControl.clearTokenRoles(tokenId);
        } else if (from == address(0)) {
            // Mint
            accessControl.grantTokenRole(
                tokenId,
                AccessControl.TokenRoles.Controller,
                to
            );
        } else if (to == address(0)) {
            // Burn
            accessControl.clearTokenRoles(tokenId);
        }

        return from;
    }

    function setTokenValue(
        uint256 projectId,
        uint256 _tokenValue,
        bool onSale
    ) external _requireHasRole(AccessControl.Role.Creator) {
        _requireProjectExists(projectId);
        projects[projectId].onSale = onSale;
        projects[projectId].price = _tokenValue;
    }

    function setTokenRoyalty(
        address to,
        uint256 projectId,
        uint256 tokenId,
        uint96 value
    ) public {
        uint256 _tokenId = projectIdToTokenId(projectId, tokenId);
        require(
            accessControl.hasTokenRole(
                _tokenId,
                AccessControl.TokenRoles.Controller,
                msg.sender
            ),
            "Spectra: must have controller role"
        );
        _requireMinted(_tokenId);
        _setTokenRoyalty(_tokenId, to, value);
    }

    function burn(uint256 projectId, uint256 tokenId) public virtual {
        uint256 _tokenId = projectIdToTokenId(projectId, tokenId);
        require(
            accessControl.hasTokenRole(
                _tokenId,
                AccessControl.TokenRoles.Controller,
                msg.sender
            ),
            "Spectra: must have controller role"
        );
        _requireMinted(_tokenId);

        require(projects[projectId].supply < 1, "Project is already minted");
        super._burn(_tokenId);

        projects[projectId].supply -= 1;

        delete hashes[_tokenId];

        delete token_attributes[_tokenId];

        delete images[_tokenId];
    }
    /*
function deleteProject(uint256 projectId) public virtual _requireHasCollectionRole(projectId, AccessControl.CollectionRoles.Owner) {
_requireProjectExists(projectId);

require(projects[projectId].supply == 0, "Project is not empty");
delete projects[projectId];
delete projectIdToTokenIds[projectId];
_projectIdCounter -= 1;

}
*/

    function transactionNFT(address to, uint256 tokenId) external payable {
        _requireMinted(tokenId);
        address owner = ownerOf(tokenId);
        uint256 price = tokenIdToPricePerTokenInWei[tokenId];
        require(price > 0, "Token is not for sale");
        require(msg.value > price, "Not enough Ether");

        (address receiver, uint256 royaltyAmount) = royaltyInfo(tokenId, price);

        if (royaltyAmount > 0) {
            payable(receiver).transfer(royaltyAmount);
        }

        uint256 paymentPrice = price - royaltyAmount;
        uint256 artistPayment = (paymentPrice * artistPaymentPercentage) / 100;

        payable(owner).transfer(artistPayment);

        payable(address(this)).transfer(paymentPrice - artistPayment);

        _transfer(owner, to, tokenId);

        tokenIdToPricePerTokenInWei[tokenId] = 0;
        // emit the event
        // emit TokenTransfe](tokenId, price, msg. sender) ;
    }

    receive() external payable {}

    fallback() external payable {}

    function withdraw() public _requireHasRole(AccessControl.Role.Admin) {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    /*
// update artist payment percentage
function updateArtistPaymentPercentage(
uint256 _artistPaymentPercentage
)  public _requireHasRole(AccessControl.Role.Admin) {

artistPaymentPercentage = _artistPaymentPercentage;
}
// set token contract address
function setTokenContractAddress (address
_tokenContractAddress) public _requireHasRole(AccessControl.Role.Admin) {

tokenContractAddress = _tokenContractAddress;

}
*/
/*
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        _requireMinted(tokenId);
        tokenIdToPricePerTokenInWei[tokenId] = 0;
        super.safeTransferFrom(from, to, tokenId);
    }
*/
    function updateNftValue(
        address marketContract,
        uint256 tokenId,
        uint256 _tokenValue,
        bool isSettingValue
    )
        public
        _requireHasTokenRole(tokenId, AccessControl.TokenRoles.Controller)
    {
        _requireMinted(tokenId);

        if (isSettingValue) {
            tokenIdToPricePerTokenInWei[tokenId] = _tokenValue;
            approve(marketContract, tokenId);
        } else {
            tokenIdToPricePerTokenInWei[tokenId] = 0;
            approve(address(0), tokenId);
        }
    }
    /*
function getSketches(uint256 projectId) public view returns (Animation memory) {
    _requireProjectExists(projectId);
    return projects[projectId].animation;

}
*/
    /*
// retrieve hash by token id
function getHash(uint256 projectId, uint256 tokenId) public view returns (bytes32) {
_requireProjectExists(projectId);
_requireMinted (projectIdToTokenId (projectId, tokenId)); return hashes[tokenId].hash;

}
// retrieve image by token id
function getImage(uint256 projectId, uint256 tokenId) public view returns (string memory) {
_requireProjectExists(projectId);
_requireMinted(projectIdToTokenId (projectId, tokenId)); return images[tokenId];

}

function getAttributes(uint256 projectId, uint256 tokenId) public view returns (string memory) {
_requireProjectExists(projectId);
_requireMinted(projectIdToTokenId (projectId, tokenId)); 
return attributes[tokenId];
}
*/
    /*
function getTokenValue(uint256 projectId) public view returns (uint256) {
_requireProjectExists(projectId);
return projectIdToPricePerTokenInWei[projectId];
}
*/

    function getNftValue(uint256 tokenId) public view returns (uint256) {
        _requireMinted(tokenId);

        return tokenIdToPricePerTokenInWei[tokenId];
    }

    function getProjectsLength() public view returns (uint256) {
        return _projectIdCounter;
    }

    function getProject(uint256 projectId) public view returns (string memory) {
        _requireProjectExists(projectId);
        Project storage project = projects[projectId];
        return parseProject(project);
    }

    function projectIdToTokenId(
        uint256 projectId,
        uint256 tokenId
    ) public view returns (uint256) {
        return projectIdToTokenIds[projectId][tokenId];
    }
    function parseProject(
        Project storage project
    ) internal view returns (string memory) {
        bytes memory dataURI = abi.encodePacked(
            "{",
            encodeKeyValue("name", project.name),
            encodeKeyValue("description", project.description),
            encodeKeyValue("image", project.image),
            encodeKeyValue("artist", project.artist),
            // encodeKeyValue("price", bytes32(projectIdToPricePerTokenInWei[projectId])),
            encodeKeyValue("price", Strings.toString(project.price)),
            encodeKeyValue("supply", Strings.toString(project.supply)),
            encodeKeyValue(
                "maxSupply",
                Strings.toString(project.maxSupply)
            ),
            encodeKeyValue("onSale", project.onSale ? "true" : "false"),
            "}"
        );

        return string(abi.encodePacked(_baseURI(), Base64.encode(dataURI)));
    }

    function _requireMinted(uint256 tokenId) internal view {
        require(
            ownerOf(tokenId) != address(0),
            "Spectra: operator query for nonexistent token"
        );
    }

    function _requireProjectExists(uint256 projectId) internal view {
        require(
            bytes32(projects[projectId].name).length != 0,
            "Spectra: operator query for nonexistent project"
        );
    }
    modifier _requireHasRole(AccessControl.Role role) {
        require(
            accessControl.hasRole(role, msg.sender),
            "Spectra: must have role"
        );
        _;
    }

    modifier _requireHasCollectionRole(
        uint256 collectionId,
        AccessControl.CollectionRoles role
    ) {
        require(
            accessControl.hasCollectionRole(collectionId, role, msg.sender),
            "Spectra: must have role"
        );
        _;
    }

    modifier _requireHasTokenRole(
        uint256 tokenId,
        AccessControl.TokenRoles role
    ) {
        require(
            accessControl.hasTokenRole(tokenId, role, msg.sender),
            "Spectra: must have role"
        );
        _;
    }
}
