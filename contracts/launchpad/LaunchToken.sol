// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {ERC20} from "@solady/tokens/ERC20.sol";

contract LaunchToken is ERC20 {
    function name() public pure override returns (string memory) {
        return "Launch Token";
    }

    function symbol() public pure override returns (string memory) {
        return "LAUNCH";
    }
    
    function mint(uint256 amount) external {
        _mint(msg.sender, amount);
    }
}