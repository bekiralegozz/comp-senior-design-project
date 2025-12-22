// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ISmartRentHub
 * @dev Interface for SmartRentHub contract
 * Used by Building1122 to notify the hub about asset registrations and ownership changes
 */
interface ISmartRentHub {
    /**
     * @dev Register a new asset (called by Building1122 on mint)
     * @param tokenId The token ID being minted
     * @param owner Initial owner of the asset
     * @param totalShares Total supply of shares
     * @param metadataURI IPFS metadata URI
     */
    function registerAsset(
        uint256 tokenId,
        address owner,
        uint256 totalShares,
        string calldata metadataURI
    ) external;

    /**
     * @dev Update ownership on transfer (called by Building1122 on every transfer)
     * @param tokenId The token ID being transferred
     * @param from Sender address (address(0) for mint)
     * @param to Receiver address (address(0) for burn)
     * @param amount Amount of shares transferred
     */
    function updateOwnership(
        uint256 tokenId,
        address from,
        address to,
        uint256 amount
    ) external;
}

