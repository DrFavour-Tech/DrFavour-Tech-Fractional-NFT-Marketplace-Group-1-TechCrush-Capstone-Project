// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @notice Minimal ERC-721 for unit testing.
contract MockERC721 is ERC721 {
    error ZeroAddress();

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {}

    function mint(address to, uint256 tokenId) external {
        if (to == address(0)) revert ZeroAddress();
        _mint(to, tokenId);
    }
}

