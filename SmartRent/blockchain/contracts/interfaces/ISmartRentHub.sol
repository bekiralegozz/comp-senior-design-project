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
    
    /**
     * @dev Get the top shareholder (highest balance holder) for an asset
     * @param tokenId The asset token ID
     * @return topHolder The address with the most shares
     * @return topBalance The balance of the top holder
     */
    function getTopShareholder(uint256 tokenId) external view returns (address topHolder, uint256 topBalance);
    
    /**
     * @dev Check if an address is the majority shareholder (has the most shares)
     * @param account The address to check
     * @param tokenId The asset token ID
     * @return True if account has the highest balance, false otherwise
     */
    function isMajorityShareholder(address account, uint256 tokenId) external view returns (bool);
}

