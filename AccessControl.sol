// SPDX-License-Identifier: MIT
import "./Ownable.sol";

pragma solidity ^0.8.7;

contract AccessControl is Ownable {
    event GrantRole(
        bytes32 indexed role,
        address indexed account,
        uint256 indexed id
    );
    event RevokeRole(
        bytes32 indexed role,
        address indexed account,
        uint256 indexed id
    );

    mapping(bytes32 => mapping(address => mapping(uint256 => bool)))
        public roles;

    bytes32 public constant ADMIN = keccak256(abi.encodePacked("ADMIN"));
    bytes32 public constant MODERATOR =
        keccak256(abi.encodePacked("MODERATOR"));

    modifier onlyRole(bytes32 _role, uint256 _id) {
        require(roles[_role][msg.sender][_id], "Not authorized");
        _;
    }

    function _grantRole(
        bytes32 _role,
        address _account,
        uint256 _id
    ) internal {
        roles[_role][_account][_id] = true;
        emit GrantRole(_role, _account, _id);
    }

    function _revokeRole(
        bytes32 _role,
        address _account,
        uint256 _id
    ) internal {
        roles[_role][_account][_id] = false;
        emit RevokeRole(_role, _account, _id);
    }
}
