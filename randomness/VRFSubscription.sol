// SPDX-License-Identifier: MIT
// An example of a consumer contract that relies on a subscription for funding.
//   Then sends to cartesi rollups IInput
pragma solidity ^0.8.18;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@cartesi/rollups/contracts/interfaces/IInput.sol";

/**
 * Based on the VRF chainlink example https://docs.chain.link/docs/vrf/v2/subscription/examples/get-a-random-number/#create-and-deploy-a-vrf-v2-compatible-contract
 */

contract VRFv2Consumer is VRFConsumerBaseV2, ConfirmedOwner {
    /**
     * HARDCODED FOR GOERLI (https://docs.chain.link/vrf/v2/direct-funding/supported-networks/#goerli-testnet)
     */
    // Address Coordinator
    address constant coordinator = 0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf/v2/subscription/supported-networks/#configurations
    bytes32 constant keyHash = 0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;

    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }
    mapping(uint256 => RequestStatus) public s_requests; /* requestId --> requestStatus */
    VRFCoordinatorV2Interface COORDINATOR;

    // Your subscription ID.
    uint64 s_subscriptionId;

    // past requests Id.
    uint256[] public requestIds;
    uint256 public lastRequestId;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 callbackGasLimit = 300000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 numWords = 1;

    // contract to send vrf
    address public inputContract = address(0);

    /**
     * Chaninlink instructions
     *   - Get some LINK and ETH (goerli faucet faucets.chain.link and https://goerlifaucet.com/
     *  For subscription method
     *   - Create a subscription, add funds to https://vrf.chain.link/ and get the subscriptionID 
     *   - Deploy the contract with the subscriptionId
     *   - Add the contract address as the consumer at https://vrf.chain.link/
     *   - Interact with the contract to requestRandomWords 
     */
     
    constructor(uint64 subscriptionId) VRFConsumerBaseV2(coordinator) ConfirmedOwner(msg.sender) {
        COORDINATOR = VRFCoordinatorV2Interface(coordinator);
        s_subscriptionId = subscriptionId;
    }

    // Assumes the subscription is funded sufficiently.
    function requestRandomWords() external returns (uint256 requestId) {
        // Will revert if subscription is not set and funded.
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        s_requests[requestId] = RequestStatus({randomWords: new uint256[](0), exists: true, fulfilled: false});
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        if (inputContract != address(0)) {
            // string memory hexString = string.concat("{\"lotery\":",request.randomWords,"}");
            // bytes32 memory dataInBytes32 = bytes32(bytes(hexString));
            IInput(inputContract).addInput(abi.encodePacked(_randomWords));
        }
        emit RequestFulfilled(_requestId, _randomWords);
    }

    function getRequestStatus(uint256 _requestId) external view returns (bool fulfilled, uint256[] memory randomWords) {
        require(s_requests[_requestId].exists, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }

    // set new input contract
    function setInputContract(address _newInputContractAddress) external onlyOwner {
        inputContract = _newInputContractAddress;
    }

}
