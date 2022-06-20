// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";


contract VibesLPERC20 is ERC20Permit {
    

    constructor() ERC20("Vibes LPs","Empire-LP") ERC20Permit("Vibes LPs"){}


    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public override returns (bool) {
        if (allowance(from,msg.sender) != type(uint256).max) {
            _approve(from,msg.sender, allowance(from,msg.sender)-value);
        }
        _transfer(from, to, value);
        return true;
    }
}
