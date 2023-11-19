// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

interface IUniswapFactory {
    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function getPair(bytes32) external view returns (address);
    function allPairs(uint256) external view returns (address);
    function allPairsLength() external view returns (uint256);
    function createPair(address, address) external returns (address);
    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}
