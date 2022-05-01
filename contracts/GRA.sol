// SPDX-License-Identifier: MIT
// @example https://ropsten.etherscan.io/address/0x724285E6B4e57a9F59ED4136930bA7FD053b1746#code
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GRA is ERC20 {
    constructor() ERC20("GRA BY CRYPTO GRAVITY", "GRA") {
        // todo: 1. 是否加入增发token的函数
        // todo: 2. 是否写死供应量
        _mint(msg.sender, 50000000 * 10 ** 18);
    }
}