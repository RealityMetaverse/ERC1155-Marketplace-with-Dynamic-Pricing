/*
Copyright 2024 HB Craft

Licensed under the Apache License, Version 2.0 (the `"License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

SPDX-License-Identifier: GPL-2.0
*/

pragma solidity 0.8.20;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

abstract contract StoreManager {
    IUniswapV3Pool public immutable DEX_POOL;
    IERC20Metadata public immutable QUOTE_TOKEN;

    address internal immutable BASE_TOKEN;

    uint256 internal immutable FIXED_POINT_PRECISION;
    uint256 internal immutable QT_DECIMAL_COUNT;

    /// @dev Listing.btPricePerFraction is converted into QT for purchase calls and listing price checks
    struct Listing {
        address listerAddress;
        address nftContractAddress;
        uint256 nftID;
        uint256 quantity;
        uint256 btPricePerFraction;
        bool isActive;
    }

    Listing[] internal listings;
    mapping(address => mapping(uint256 => uint256)) internal nftListingID;
    uint256 internal activeListingStartIndex = 0;

    bool public isRatePeriodSystemEnabled = true;

    enum RatePeriod {
        LOCK,
        NEW_LOCK,
        FLOATING
    }
    /**
     * @dev
     *     - When a purchased made, the BT/QT rate is locked for rateLockDuration if the rate is not locked yet
     *     - The default is rateLockDuration 15 minutes
     */

    uint256 public rateLockDuration;
    uint256 public lastBTQTRateLockTimestamp;
    uint256 public lockedBTQTRate;
    uint256 internal lastCheckedBTQTRate;
    uint256 public minimumAcceptableRate;
    uint256 public minimumPriceInQT;

    // For getting the rate from Uniswap
    // In seconds
    uint256 public uniswapObservationTime;
    uint256 internal constant MINIMUM_UNISWAP_OBSERVATION_TIME = 60;

    /**
     * @dev
     *     - The BT/QT rate is floating when the rate is not locked, and there is no lastCheckedBTQTRate to lock the rate
     *     - During RatePeriod.FLOATING lastCheckedBTQTRate taken as reference if current BT/QT rate doesn't have ± rateSlippageTolerance % difference to display stable listing prices
     *     - The default rateSlippageTolerance rate is 3%
     */
    uint256 public rateSlippageTolerance;

    constructor(address dexPoolAddress, address btAddress, address qtAddress, uint256 _minimumAcceptableRate) {
        DEX_POOL = IUniswapV3Pool(dexPoolAddress);

        address _token0 = DEX_POOL.token0();
        address _token1 = DEX_POOL.token1();

        require(
            (btAddress == _token0 && qtAddress == _token1) || (btAddress == _token1 && qtAddress == _token0),
            "DEX Pool doesn't feature the pair"
        );

        BASE_TOKEN = btAddress;

        QUOTE_TOKEN = IERC20Metadata(qtAddress);

        QT_DECIMAL_COUNT = uint256(QUOTE_TOKEN.decimals());
        FIXED_POINT_PRECISION = 10 ** QT_DECIMAL_COUNT;

        rateLockDuration = 15 minutes;
        rateSlippageTolerance = 3;
        minimumPriceInQT = FIXED_POINT_PRECISION;
        minimumAcceptableRate = _minimumAcceptableRate;
        uniswapObservationTime = 20 minutes;
    }
}
