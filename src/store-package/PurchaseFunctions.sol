// SPDX-License-Identifier: GPL-2.0
// Copyright 2024 Reality Metaverse

pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./AuxiliaryFunctions.sol";

abstract contract PurchaseFunctions is AuxiliaryFunctions, ReentrancyGuard {
    function _purchase(Listing memory targetListing, uint256 listingID, uint256 quantity, uint256 priceInQT) private {
        listings[listingID].quantity -= quantity;
        if (listings[listingID].quantity == 0) {
            listings[listingID].isActive = false;
            emit ListingSoldOut(listingID);
        }
        if (isRatePeriodSystemEnabled) _updateStateForCurrentPeriod();
        emit Purchase(msg.sender, listingID, quantity, priceInQT);
        _payTreasury(priceInQT * quantity);
        _transferNFTs(targetListing.listerAddress, targetListing.nftContractAddress, targetListing.nftID, quantity);
    }

    function safePurchase(uint256 listingID, uint256 quantity, uint256 forMaxPriceInQT)
        external
        nonReentrant
        ifPurchaseCallValid(listingID, quantity)
    {
        uint256 referanceRate = getReferenceBTQTRate();
        _checkIfRateOverMinAcceptableRate(referanceRate);

        if (!_checkIfListingValid(listingID, referanceRate)) revert InvalidListing(listingID);

        Listing memory targetListing = listings[listingID];

        uint256 currentPriceInQT = _convertBTPriceToQT(targetListing.btPricePerFraction, referanceRate);
        if (currentPriceInQT > forMaxPriceInQT) revert PriceInQTIncreased(listingID, forMaxPriceInQT, currentPriceInQT);

        _purchase(targetListing, listingID, quantity, currentPriceInQT);
    }
}
