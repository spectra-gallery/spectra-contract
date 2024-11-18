/*
Solidity Access Control proxy contract for Spectra Gallery
The contract is used to manage the roles depending on the DAO vote
The roles are: admin, creator, thinker, myself
An admin can add new admin, creator and thinker
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

error MustHaveRole(uint8 role);
error MustHaveCollectionRole(uint8 role);
error MustHaveTokenRole(uint256 tokenId, uint8 role);
error MustHaveAtLeastOneOwner();
error RoleAlreadySet();

contract AccessControl {

    enum Role {
        Contract,
        Admin,
        Creator,
        Thinker,
        Myself
    }

    /**
     * @dev All available collection roles.
     */
    enum CollectionRoles {
        Owner,
        Verifier
    }

    /**
     * @dev All available token roles.
     */
    enum TokenRoles {
        Controller
    }

    event RoleGranted(Role indexed role, address indexed account, address indexed by);

    /**
     * @dev Emitted when a token role is changed.
     */
    event TokenRoleChanged(
        uint256 indexed tokenId,
        TokenRoles indexed role,
        address indexed toAddress,
        bool status,
        address byAddress
    );

    /**
     * @dev Emitted when token roles version is increased and all token roles are cleared.
     */
    event TokenRolesCleared(uint256 indexed tokenId, address byAddress);

    /**
     * @dev Emitted when a collection role is changed.
     */
    event CollectionRoleChanged(
        CollectionRoles indexed role,
        address indexed toAddress,
        bool status,
        address byAddress
    );

    uint256 public userCount;

    mapping(Role => mapping(address => bool)) private _roles;

    /**
     * @dev _collectionRolesCounter[role] is the number of addresses that have the role.
     * This is prevent Owner role to go to 0.
     */
    mapping(CollectionRoles => uint256) private _collectionRolesCounter;

    /**
     * @dev _collectionRoles[collectionId][role][address] is the mapping of addresses that have the role for a collection id.
     */
    // mapping(CollectionRoles => mapping(address => bool)) private _collectionRoles;
    mapping(uint256 => mapping(CollectionRoles => mapping(address => bool))) private _collectionRoles;
    

    /**
     * @dev _tokenRolesVersion[tokenId] is the version of the token roles.
     * The version is incremented every time the token roles are cleared.
     * Should be incremented every token transfer.
     */
    mapping(uint256 => uint256) private _tokenRolesVersion;

    /**
     * @dev _tokenRoles[tokenId][version][role][address] is the mapping of addresses that have the role.
     */
    mapping(uint256 => mapping(uint256 => mapping(TokenRoles => mapping(address => bool)))) private _tokenRoles;

    constructor() {
        _grantRole(Role.Admin, msg.sender);
        _grantRole(Role.Creator, msg.sender);
        _grantRole(Role.Thinker, msg.sender);
        _grantRole(Role.Myself, msg.sender);
        userCount++;
    }

    function grantRoleByDAO(Role role, address account) public {
        _requireRole(Role.Contract);
        _grantRole(role, account);
        userCount++;
    }

    function revokeRoleByDAO(Role role, address account) public {
        _requireRole(Role.Contract);
        _revokeRole(role, account);
    }

    function grantRole(Role role, address account) public {
        _requireRole(Role.Admin);
        _grantRole(role, account);
        userCount++;
    }

    function adminRevokeRole(Role role, address account) public {
        _requireRole(Role.Admin);
        _revokeRole(role, account);
    }

    function grantCollectionRole(uint256 collectionId, CollectionRoles role, address account) public {
        _requireRole(Role.Contract);
        _grantCollectionRole(collectionId, role, account);
    }

    function revokeCollectionRole(uint256 collectionId, CollectionRoles role, address account) public {
        _requireRole(Role.Contract);
        _revokeCollectionRole(collectionId, role, account);
    }

    function grantTokenRole(uint256 tokenId, TokenRoles role, address account) public {
        _requireRole(Role.Contract);
        _grantTokenRole(tokenId, role, account);
    }

    function revokeTokenRole(uint256 tokenId, TokenRoles role, address account) public {
        _requireRole(Role.Contract);
        _revokeTokenRole(tokenId, role, account);
    }

    function clearTokenRoles(uint256 tokenId) public {
        _requireRole(Role.Contract);
        _clearTokenRoles(tokenId);
    }

    function _requireRole(Role role) internal view {
        if (!hasRole(role, msg.sender)) revert MustHaveRole(uint8(role));
    }

    /**
     * @dev Checks if the `msg.sender` has a certain role.
     */
    function _requireCollectionRole(uint256 collectionId, CollectionRoles role) internal view {
        if (!hasCollectionRole(collectionId, role, msg.sender)) revert MustHaveCollectionRole(uint8(role));
    }

    /**
     * @dev Checks if the `msg.sender` has the `Token` role for a certain `tokenId`.
     */
    function _requireTokenRole(uint256 tokenId, TokenRoles role, address account) internal view {
        if (!hasTokenRole(tokenId, role, account)) revert MustHaveTokenRole(tokenId, uint8(role));
    }

    /**
     * @dev Returns `True` if a certain address has a certain role.
     */
    function hasRole(Role role, address account) public view returns (bool) {
        return _roles[role][account];
    }

    /**
     * @dev Returns `True` if a certain address has the collection role.
     */
    function hasCollectionRole(uint256 collectionId, CollectionRoles role, address account) public view returns (bool) {
        return _collectionRoles[collectionId][role][account];
    }

    /**
     * @dev Returns `True` if a certain address has the token role.
     */
    function hasTokenRole(uint256 tokenId, TokenRoles role, address account) public view returns (bool) {
        uint256 currentVersion = _tokenRolesVersion[tokenId];
        return _tokenRoles[tokenId][currentVersion][role][account];
    }

    /**
     * @dev Grants a role to an address.
     */
    function _grantRole(Role role, address account) internal {
        if (hasRole(role, account)) revert RoleAlreadySet();

        _roles[role][account] = true;

        emit RoleGranted(role, account, msg.sender);

    }

    /**
     * @dev Revokes a role of an address.
     */
    function _revokeRole(Role role, address account) internal {
        if (!hasRole(role, account)) revert RoleAlreadySet();

        _roles[role][account] = false;
        userCount -= 1;

        emit RoleGranted(role, account, msg.sender);
    }

    /**
     * @dev Grants the collection role to an address.
     */
    function _grantCollectionRole(uint256 collectionId, CollectionRoles role, address account) internal {
        if (hasCollectionRole(collectionId, role, account)) revert RoleAlreadySet();

        _collectionRoles[collectionId][role][account] = true;
        _collectionRolesCounter[role] += 1;

        emit CollectionRoleChanged(role, account, true, msg.sender);
    }

    /**
     * @dev Revokes the collection role of an address.
     */
    function _revokeCollectionRole(uint256 collectionId, CollectionRoles role, address account) internal {
        if (!hasCollectionRole(collectionId, role, account)) revert RoleAlreadySet();
        if (role == CollectionRoles.Owner && _collectionRolesCounter[role] == 1) revert MustHaveAtLeastOneOwner();

        _collectionRoles[collectionId][role][account] = false;
        _collectionRolesCounter[role] -= 1;

        emit CollectionRoleChanged(role, account, false, msg.sender);
    }

    /**
     * @dev Grants the token role to an address.
     */
    function _grantTokenRole(uint256 tokenId, TokenRoles role, address account) internal {
        if (hasTokenRole(tokenId, role, account)) revert RoleAlreadySet();

        uint256 currentVersion = _tokenRolesVersion[tokenId];
        _tokenRoles[tokenId][currentVersion][role][account] = true;

        emit TokenRoleChanged(tokenId, role, account, true, msg.sender);
    }

    /**
     * @dev Revokes the token role of an address.
     */
    function _revokeTokenRole(uint256 tokenId, TokenRoles role, address account) internal {
        if (!hasTokenRole(tokenId, role, account)) revert RoleAlreadySet();

        uint256 currentVersion = _tokenRolesVersion[tokenId];
        _tokenRoles[tokenId][currentVersion][role][account] = false;

        emit TokenRoleChanged(tokenId, role, account, false, msg.sender);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    function _clearTokenRoles(uint256 tokenId) internal {
        _tokenRolesVersion[tokenId] += 1;
        emit TokenRolesCleared(tokenId, msg.sender);
    }

    // user count 
    function getUserCount() public view returns (uint256) {
        return userCount;
    }

    function setContactAddress(address _dao) public {
        _requireRole(Role.Admin);
        _grantRole(Role.Contract, _dao);
    }
}