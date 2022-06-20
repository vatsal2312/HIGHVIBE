// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import './interfaces/IVibesFactory.sol';
import './VibesLPPair.sol';

contract VibesFactory is IVibesFactory {
    bytes32 public constant override INIT_CODE_PAIR_HASH = keccak256(abi.encodePacked(type(VibesLPPair).creationCode));



    mapping(address => mapping(address => address)) public  override getPair;
    address[] public override allPairs;


    function allPairsLength() external view  override returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, 'Vibes: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'Vibes: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'Vibes: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(VibesLPPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IVibesPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

}
