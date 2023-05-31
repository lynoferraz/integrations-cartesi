// SPDX-License-Identifier: MIT
// An example of a consumer contract that relies on a subscription for funding.
//   Then sends to cartesi rollups IInput
pragma solidity ^0.8.18;

import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@cartesi/rollups/contracts/interfaces/IInput.sol";

contract RandomnessMethods is ConfirmedOwner {
    // contract to send randomness
    address public inputContract = address(0);

    // commit to future block hash
    mapping(address => uint256) public revealBlock;

    // aggregated inputs
    uint256 public aggregatedInputs;

    constructor() ConfirmedOwner(msg.sender) {
    }

    // set new input contract
    function setInputContract(address _newInputContractAddress) external onlyOwner {
        inputContract = _newInputContractAddress;
    }

    // views to get timestamp, blocknumber, blockhsh, prevrandao
    function getTimestamp() external view returns (uint256) { 
        return block.timestamp;
    }
    function getBlocknumber() external view returns (uint256) { 
        return block.number;
    }
    function getBlockhash() external view returns (uint256) { 
        return uint256(blockhash(block.number - 1));
    }
    function getPrevrandao() external view returns (uint256) { 
        return block.prevrandao;
    }

    /// send timestamp
    function sendTimestamp() external returns (uint256) { 
        // no access to current block hash (available only when mined)
        uint256 bhash = uint256(block.timestamp);
        if (inputContract != address(0)) {
            IInput(inputContract).addInput(abi.encodePacked(bhash));
        }
        return bhash;
    }

    /// send blockhash
    function sendBlockhash() external returns (uint256) { 
        // no access to current block hash (available only when mined)
        uint256 bhash = uint256(blockhash(block.number - 1));
        if (inputContract != address(0)) {
            IInput(inputContract).addInput(abi.encodePacked(bhash));
        }
        return bhash;
    }

    /// User requests randomness for a future block along with a request id
    function commitRandomness(uint256 _revealBlock) external {
        require(_revealBlock > block.number, "Must commit to a future block");
        require(revealBlock[msg.sender] == 0, "Request already submitted");
        revealBlock[msg.sender] = _revealBlock;
    }

    /// User requests randomness for the next block block
    function commitRandomness() external {
        require(revealBlock[msg.sender] == 0, "Request already submitted");
        revealBlock[msg.sender] = block.number + 1;
    }

    /// Reset user commitment
    function resetCommitedRandomness() external {
        require(revealBlock[msg.sender] != 0, "Request not set");
        revealBlock[msg.sender] = 0;
    }

    /// Returns the blockhash of the block after checking that the request's target
    /// block has been reached.
    function sendCommitedBlockhash() external returns (uint256) {
        uint256 randomnessBlock = revealBlock[msg.sender];
        require(block.number > randomnessBlock, "Request not ready");
        require(block.number <= randomnessBlock + 256, "Request expired");
        uint256 bhash = uint256(blockhash(randomnessBlock));
        if (inputContract != address(0)) {
            IInput(inputContract).addInput(abi.encodePacked(bhash));
        }
        // reset reveal block
        revealBlock[msg.sender] = 0;
        return bhash;
    }

    // Send randao value
    function sendRandao() external returns (uint256) { 
        if (inputContract != address(0)) {
            // string memory hexString = string.concat("{\"lotery\":",request.randomWords,"}");
            // bytes32 memory dataInBytes32 = bytes32(bytes(hexString));
            IInput(inputContract).addInput(abi.encodePacked(block.prevrandao));
        }
        return block.prevrandao;
    }

    /// Returns the randao of the block after checking that the request's target
    /// block has been reached.
    function sendCommitedFutureRandao() external returns (uint256) {
        uint256 randomnessBlock = revealBlock[msg.sender];
        // wait a least 4 epochs + epson (4*32 blocks + e)
        require(block.number > randomnessBlock + 128 + 3, "Request not ready");
        uint256 randao = block.prevrandao;
        if (inputContract != address(0)) {
            IInput(inputContract).addInput(abi.encodePacked(randao));
        }
        // reset reveal block
        revealBlock[msg.sender] = 0;
        return randao;
    }

    // Send input mixed with randao value
    function sendAggregatedInputsMixedWithRandao(uint256 _input) external returns (uint256) { 
        uint256 randomness = uint256(keccak256(abi.encodePacked(block.prevrandao^aggregatedInputs)));
        if (inputContract != address(0)) {
            // string memory hexString = string.concat("{\"lotery\":",request.randomWords,"}");
            // bytes32 memory dataInBytes32 = bytes32(bytes(hexString));
            IInput(inputContract).addInput(abi.encodePacked(randomness));
        }
        aggregatedInputs = uint256(keccak256(abi.encodePacked(_input^aggregatedInputs)));
        return aggregatedInputs;
    }

}
