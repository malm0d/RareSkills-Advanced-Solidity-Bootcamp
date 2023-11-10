// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Power} from "./Power.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

interface IBancorBondingCurve {
    function calculatePurchaseReturn(
        uint256 _supply,
        uint256 _reserveBalance,
        uint32 _reserveRatio,
        uint256 _depositAmount
    )
        external
        view
        returns (uint256);

    function calculateSaleReturn(
        uint256 _supply,
        uint256 _reserveBalance,
        uint32 _reserveRatio,
        uint256 _sellAmount
    )
        external
        view
        returns (uint256);
}

/**
 * @dev Bancor Bonding Curve
 * For a linear bonding curve, set the reserve ratio to 0.5e6 (500000 == 50%)
 */
contract BancorBondingCurve is IBancorBondingCurve, Power {
    using Math for uint256;

    //Max possible reserve ratio is 1e6 (1000000 == 100%)
    uint32 private constant MAX_RESERVE_RATIO = 1000000;

    /**
     * @dev given a continuous token supply, reserve token balance, reserve ratio, and a deposit amount (in the reserve token),
     * calculates the return for a given conversion (in the continuous token).
     * The return value is the number of continuous tokens they will receive in exchange for their reserve tokens,
     * and it can be viewed as the price at which they are acquiring the continuous tokens.
     * (represents the price at which a user can buy continuous tokens by depositing a specific amount of reserve tokens)
     *
     *
     * Formula:
     * Return = _supply * ((1 + _depositAmount / _reserveBalance) ^ (_reserveRatio / MAX_RESERVE_RATIO) - 1)
     * Or:
     * PurchaseReturn = ContinuousTokenSupply * ((1 + ReserveTokensReceived / ReserveTokenBalance) ^ (ReserveRatio) - 1)
     *
     * @param _supply              continuous token total supply
     * @param _reserveBalance    total reserve token balance
     * @param _reserveRatio     reserve ratio, represented in ppm, 1-1000000
     * @param _depositAmount       deposit amount, in reserve token
     *
     * @return purchase return amount
     */
    function calculatePurchaseReturn(
        uint256 _supply,
        uint256 _reserveBalance,
        uint32 _reserveRatio,
        uint256 _depositAmount
    )
        public
        view
        override
        returns (uint256)
    {
        //validate input
        require(_supply > 0, "Supply must be greater than zero");
        require(_reserveBalance > 0, "Reserve balance must be greater than zero");
        require(_reserveRatio > 0, "Reserve ratio must be greater than zero");
        require(!(_reserveRatio > MAX_RESERVE_RATIO), "Reserve ratio must be less than or equal to 1000000");
        //special case for 0 deposit amount
        if (_depositAmount == 0) {
            return 0;
        }
        //special case if the ratio = 100%
        if (_reserveRatio == MAX_RESERVE_RATIO) {
            return (_supply * _depositAmount) / _reserveBalance;
        }
        uint256 result;
        uint8 precision;
        uint256 baseN = _depositAmount + _reserveBalance;
        (result, precision) = power(baseN, _reserveBalance, _reserveRatio, MAX_RESERVE_RATIO);
        uint256 newTokenSupply = (_supply * result) >> precision;
        return newTokenSupply - _supply;
    }

    /**
     * @dev given a continuous token supply, reserve token balance, reserve ratio and a sell amount (in the continuous token),
     * calculates the return for a given conversion (in the reserve token).
     * The return value is the number of reserve tokens they will receive in exchange for their continuous tokens,
     * and it can be viewed as the price at which they are selling the continuous tokens.
     * (represents the price at which a user can sell continuous tokens in exchange for a specific amount of reserve tokens)
     *
     * Formula:
     * Return = _reserveBalance * (1 - (1 - _sellAmount / _supply) ^ (1 / (_reserveRatio / MAX_RESERVE_RATIO)))
     * Or:
     * SaleReturn = ReserveTokenBalance * (1 - (1 - ContinuousTokensReceived / ContinuousTokenSupply) ^ (1 / (ReserveRatio)))
     *
     * @param _supply              continuous token total supply
     * @param _reserveBalance    total reserve token balance
     * @param _reserveRatio     constant reserve ratio, represented in ppm, 1-1000000
     * @param _sellAmount          sell amount, in the continuous token itself
     *
     * @return sale return amount
     */
    function calculateSaleReturn(
        uint256 _supply,
        uint256 _reserveBalance,
        uint32 _reserveRatio,
        uint256 _sellAmount
    )
        public
        view
        override
        returns (uint256)
    {
        //validate input
        require(_supply > 0, "Supply must be greater than zero");
        require(_reserveBalance > 0, "Reserve balance must be greater than zero");
        require(_reserveRatio > 0, "Reserve ratio must be greater than zero");
        require(!(_reserveRatio > MAX_RESERVE_RATIO), "Reserve ratio must be less than or equal to 1000000");
        require(!(_sellAmount > _supply), "Sell amount must be less than or equal to supply");
        //special case for 0 sell amount
        if (_sellAmount == 0) {
            return 0;
        }
        //special case for selling the entire supply
        if (_sellAmount == _supply) {
            return _reserveBalance;
        }
        // special case if the ratio = 100%
        if (_reserveRatio == MAX_RESERVE_RATIO) {
            return _reserveBalance * _sellAmount / _supply;
        }
        uint256 result;
        uint8 precision;
        uint256 baseD = _supply - _sellAmount;
        (result, precision) = power(_supply, baseD, MAX_RESERVE_RATIO, _reserveRatio);
        uint256 oldBalance = _reserveBalance * result;
        uint256 newBalance = _reserveBalance << precision;
        return (oldBalance - newBalance) / result;
    }
}
