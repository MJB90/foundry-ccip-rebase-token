//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {TokenPool} from "@ccip/src/v0.8/ccip/pools/TokenPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Pool} from "@ccip/src/v0.8/ccip/libraries/Pool.sol";

// contract RebaseTokenPool is TokenPool {

//     constructor(IERC20 token, address[] memory _allowList, address _rnmProxy, address _router) TokenPool(token, _allowList, _rnmProxy, _router) {
//         // Constructor logic can be added here if needed
//     }
// }