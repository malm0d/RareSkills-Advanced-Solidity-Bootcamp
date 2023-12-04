//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {UniswapPair} from "./Rs_UniswapPair.sol";

contract UniswapFactory {
    //address to which fees will be sent
    address public feeTo;

    //address with authority to set `feeTo`
    address public feeToSetter;

    /**
     * mapping that stores the hash of the two token addresses to the address of the pair.
     * saves gas over nested mapping.
     */
    mapping(bytes32 => address) public getPair;

    //address of all pairs created by Factory
    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint256 lengthAllPairs);

    constructor(address _feeToSetter) {
        require(_feeToSetter != address(0), "UniswapFactory: Cannot set feeToSetter to zero address");
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, "UniswapFactory: Cannot create pair with same token");
        //sorts token addresses to create deterministic pair, ensures uniqueness in contract
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "UniswapFacory: Cannot create pair with zero address");

        bytes32 pairKey = keccak256(abi.encodePacked(token0, token1));
        require(getPair[pairKey] == address(0), "UniswapFactory: Pair already exists in contract");

        bytes memory contractBytecode = type(UniswapPair).creationCode;
        bytes32 create2Salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair :=
                create2(
                    0,
                    add(contractBytecode, 0x20), //advance to skip length in first 32 bytes
                    mload(contractBytecode), //length of contract bytecode
                    create2Salt
                )
        }
        getPair[pairKey] = pair;
        allPairs.push(pair);
        UniswapPair(pair).initialize(token0, token1);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, "UniswapFactory: Not authorized to set feeTo");
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(_feeToSetter != address(0), "UniswapFactory: Cannot set feeToSetter to zero address");
        require(msg.sender == feeToSetter, "UniswapFactory: Not authorized to set feeToSetter");
        feeToSetter = _feeToSetter;
    }

    // Previously, we used a nested mapping to track pairs, but this is not gas efficient.
    // Code is left here just to show an example of using assembly to update the nested mapping
    //  /**
    //  * nested mapping that stores addresses of pairs for the given token addresses
    //  * E.g. token0 => token1 => pair address
    //  */
    // mapping(address => mapping(address => address)) public getPair;
    //
    // function createPair(address tokenA, address tokenB) external returns (address) {
    //     ...
    //     require(getPair[token0][token1] == address(0), "UniswapFactory: Pair already exists in contract");

    //     bytes memory contractBytecode = type(UniswapPair).creationCode;
    //     bytes32 create2Salt = keccak256(abi.encodePacked(token0, token1));
    //     assembly {
    //         pair :=
    //             create2(
    //                 0,
    //                 add(contractBytecode, 0x20), //advance to skip length in first 32 bytes
    //                 mload(contractBytecode), //length of contract bytecode
    //                 create2Salt
    //             )
    //     }
    //     UniswapPair(pair).initialize(token0, token1);

    //     /**
    //      * getPair[token0][token1] = pair;
    //      * getPair[token1][token0] = pair;
    //      */
    //     assembly {
    //         let getPairsSlot := getPairs.slot

    //         let location_0_1 := keccak256(
    //             abi.encodePacked(
    //                 token1,
    //                 keccak256(abi.encodePacked(token0), getPairsSlot)
    //             )
    //         )
    //         sstore(location_0_1, pair)

    //         let location_1_0 := keccak256(
    //             abi.encodePacked(
    //                 token0,
    //                 keccak256(abi.encodePacked(token1), getPairsSlot)
    //                 )
    //         )
    //         sstore(location_1_0, pair)
    //     }

    //     allPairs.push(pair);
    //     emit PairCreated(token0, token1, pair, allPairs.length);
    // }
}
