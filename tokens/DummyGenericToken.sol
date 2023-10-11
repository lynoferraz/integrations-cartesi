// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract DummyGenericToken is ERC1155 {
    using Counters for Counters.Counter;
    Counters.Counter private currentTokenId;

    constructor() ERC1155("") {}

    function mint(address recipient, uint256 amount, bytes memory data) public returns (uint256) {
        currentTokenId.increment();

        uint256 newItemId = currentTokenId.current();

        _mint(recipient, newItemId, amount, data);

        return newItemId;
    }
}