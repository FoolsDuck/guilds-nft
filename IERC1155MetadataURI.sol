// SPDX-License-Identifier: MIT
import "./IERC1155.sol";

pragma solidity ^0.8.7;

interface IERC1155MetadataURI is IERC1155 {
    function uri(uint256 id) external view returns (string memory);
}
