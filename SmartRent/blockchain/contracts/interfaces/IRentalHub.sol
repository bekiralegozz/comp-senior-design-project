// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IRentalHub
 * @dev Interface for RentalHub contract
 * Used by SmartRentHub to notify about top shareholder changes
 */
interface IRentalHub {
    /**
     * @dev Called when the top shareholder of a token changes
     * Automatically deactivates rental listings by the previous top shareholder
     * @param tokenId The token ID whose top shareholder has changed
     * @param previousTopShareholder The address of the previous top shareholder
     * @param newTopShareholder The address of the new top shareholder
     */
    function onTopShareholderChanged(
        uint256 tokenId,
        address previousTopShareholder,
        address newTopShareholder
    ) external;
}

