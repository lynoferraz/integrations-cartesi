// SPDX-License-Identifier: MIT
// An example of a consumer contract that relies on a subscription for funding.
//   Then sends to cartesi rollups IInput
pragma solidity ^0.8.18;

import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@chainlink/contracts/src/v0.8/VRFV2WrapperConsumerBase.sol";
import "@cartesi/rollups/contracts/interfaces/IInput.sol";

/**
 * Based on the VRF chainlink example https://docs.chain.link/vrf/v2/direct-funding/examples/get-a-random-number
 */


contract VRFv2Consumer is VRFV2WrapperConsumerBase, ConfirmedOwner {
    /**
     * HARDCODED FOR GOERLI (https://docs.chain.link/vrf/v2/direct-funding/supported-networks/#goerli-testnet)
     */
    // Address LINK
    address constant linkAddress = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
    // address WRAPPER
    address constant wrapperAddress = 0x708701a1DfF4f478de54383E49a627eD4852C816;

    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(
        uint256 requestId,
        uint256[] randomWords,
        uint256 payment
    );

    struct RequestStatus {
        uint256 paid; // amount paid in link
        bool fulfilled; // whether the request has been successfully fulfilled
        uint256[] randomWords;
    }
    mapping(uint256 => RequestStatus) public s_requests; /* requestId --> requestStatus */
    
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
     *  For direct method
     *   - deploy the contract
     *   - fund the contract with link
     *   - Interact with the contract to requestRandomWords 
     */
     
    constructor() ConfirmedOwner(msg.sender) VRFV2WrapperConsumerBase(linkAddress, wrapperAddress) {
    }

    function requestRandomWords() external returns (uint256 requestId) {
        requestId = requestRandomness(
            callbackGasLimit,
            requestConfirmations,
            numWords
        );
        s_requests[requestId] = RequestStatus({paid: VRF_V2_WRAPPER.calculateRequestPrice(callbackGasLimit),
            randomWords: new uint256[](0), fulfilled: false });
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        require(s_requests[_requestId].paid > 0, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        if (inputContract != address(0)) {
            // string memory hexString = string.concat("{\"lotery\":",request.randomWords,"}");
            // bytes32 memory dataInBytes32 = bytes32(bytes(hexString));
            IInput(inputContract).addInput(abi.encodePacked(_randomWords));
        }
        emit RequestFulfilled(_requestId,_randomWords,s_requests[_requestId].paid);
    }

    function getRequestStatus( uint256 _requestId ) external view returns (uint256 paid, bool fulfilled, uint256[] memory randomWords) {
        require(s_requests[_requestId].paid > 0, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.paid, request.fulfilled, request.randomWords);
    }

    /**
     * Allow withdraw of Link tokens from the contract
     */
    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(linkAddress);
        require(link.transfer(msg.sender, link.balanceOf(address(this))), "Unable to transfer" );
    }

    // set new input contract
    function setInputContract(address _newInputContractAddress) external onlyOwner {
        inputContract = _newInputContractAddress;
    }

}
