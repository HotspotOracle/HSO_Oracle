// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./HotspotOracle.sol";
import "./interfaces/ENSInterface.sol";
import "./interfaces/HotspotOracleTokenInterface.sol";
import "./interfaces/HotspotOracleRequestInterface.sol";
import "./interfaces/PointerInterface.sol";
import {
    ENSResolver as ENSResolver_HotspotOracle
} from "./vendor/ENSResolver.sol";

/**
 * @title The HotspotOracleClient contract
 * @notice Contract writers can inherit this contract in order to create requests for the
 * HotspotOracle network
 */
contract HotspotOracleClient {
    using HotspotOracle for HotspotOracle.Request;

    uint256 internal constant HSO = 10**18;
    uint256 private constant AMOUNT_OVERRIDE = 0;
    address private constant SENDER_OVERRIDE = address(0);
    uint256 private constant ARGS_VERSION = 1;
    bytes32 private constant ENS_TOKEN_SUBNAME = keccak256("HSO");
    bytes32 private constant ENS_ORACLE_SUBNAME = keccak256("oracle");
    address private constant HSO_TOKEN_POINTER =
        0xC89bD4E1632D3A43CB03AAAd5262cbe4038Bc571;

    ENSInterface private ens;
    bytes32 private ensNode;
    HotspotOracleTokenInterface private HSO;
    HotspotOracleRequestInterface private oracle;
    uint256 private requestCount = 1;
    mapping(bytes32 => address) private pendingRequests;

    event HotspotOracleRequested(bytes32 indexed id);
    event HotspotOracleFulfilled(bytes32 indexed id);
    event HotspotOracleCancelled(bytes32 indexed id);

    /**
     * @notice Creates a request that can hold additional parameters
     * @param _specId The Job Specification ID that the request will be created for
     * @param _callbackAddress The callback address that the response will be sent to
     * @param _callbackFunctionSignature The callback function signature to use for the callback address
     * @return A HotspotOracle Request struct in memory
     */
    function buildHotspotOracleRequest(
        bytes32 _specId,
        address _callbackAddress,
        bytes4 _callbackFunctionSignature
    ) internal pure returns (HotspotOracle.Request memory) {
        HotspotOracle.Request memory req;
        return
            req.initialize(
                _specId,
                _callbackAddress,
                _callbackFunctionSignature
            );
    }

    /**
     * @notice Creates a HotspotOracle request to the stored oracle address
     * @dev Calls `HotspotOracleRequestTo` with the stored oracle address
     * @param _req The initialized HotspotOracle Request
     * @param _payment The amount of HSO to send for the request
     * @return requestId The request ID
     */
    function sendHotspotOracleRequest(
        HotspotOracle.Request memory _req,
        uint256 _payment
    ) internal returns (bytes32) {
        return sendHotspotOracleRequestTo(address(oracle), _req, _payment);
    }

    /**
     * @notice Creates a HotspotOracle request to the specified oracle address
     * @dev Generates and stores a request ID, increments the local nonce, and uses `transferAndCall` to
     * send HSO which creates a request on the target oracle contract.
     * Emits HotspotOracleRequested event.
     * @param _oracle The address of the oracle for the request
     * @param _req The initialized HotspotOracle Request
     * @param _payment The amount of HSO to send for the request
     * @return requestId The request ID
     */
    function sendHotspotOracleRequestTo(
        address _oracle,
        HotspotOracle.Request memory _req,
        uint256 _payment
    ) internal returns (bytes32 requestId) {
        requestId = keccak256(abi.encodePacked(this, requestCount));
        _req.nonce = requestCount;
        pendingRequests[requestId] = _oracle;
        emit HotspotOracleRequested(requestId);
        require(
            HSO.transferAndCall(_oracle, _payment, encodeRequest(_req)),
            "unable to transferAndCall to oracle"
        );
        requestCount += 1;

        return requestId;
    }

    /**
     * @notice Allows a request to be cancelled if it has not been fulfilled
     * @dev Requires keeping track of the expiration value emitted from the oracle contract.
     * Deletes the request from the `pendingRequests` mapping.
     * Emits HotspotOracleCancelled event.
     * @param _requestId The request ID
     * @param _payment The amount of HSO sent for the request
     * @param _callbackFunc The callback function specified for the request
     * @param _expiration The time of the expiration for the request
     */
    function cancelHotspotOracleRequest(
        bytes32 _requestId,
        uint256 _payment,
        bytes4 _callbackFunc,
        uint256 _expiration
    ) internal {
        HotspotOracleRequestInterface requested =
            HotspotOracleRequestInterface(pendingRequests[_requestId]);
        delete pendingRequests[_requestId];
        emit HotspotOracleCancelled(_requestId);
        requested.cancelOracleRequest(
            _requestId,
            _payment,
            _callbackFunc,
            _expiration
        );
    }

    /**
     * @notice Sets the stored oracle address
     * @param _oracle The address of the oracle contract
     */
    function setHotspotOracleOracle(address _oracle) internal {
        oracle = HotspotOracleRequestInterface(_oracle);
    }

    /**
     * @notice Sets the HSO token address
     * @param _HSO The address of the HSO token contract
     */
    function setHotspotOracleToken(address _HSO) internal {
        HSO = HotspotOracleTokenInterface(_HSO);
    }

    /**
     * @notice Sets the HotspotOracle token address for the public
     * network as given by the Pointer contract
     */
    function setPublicHotspotOracleToken() internal {
        setHotspotOracleToken(
            PointerInterface(HSO_TOKEN_POINTER).getAddress()
        );
    }

    /**
     * @notice Retrieves the stored address of the HSO token
     * @return The address of the HSO token
     */
    function HotspotOracleTokenAddress() internal view returns (address) {
        return address(HSO);
    }

    /**
     * @notice Retrieves the stored address of the oracle contract
     * @return The address of the oracle contract
     */
    function HotspotOracleAddress() internal view returns (address) {
        return address(oracle);
    }

    /**
     * @notice Allows for a request which was created on another contract to be fulfilled
     * on this contract
     * @param _oracle The address of the oracle contract that will fulfill the request
     * @param _requestId The request ID used for the response
     */
    function addHotspotOracleExternalRequest(
        address _oracle,
        bytes32 _requestId
    ) internal notPendingRequest(_requestId) {
        pendingRequests[_requestId] = _oracle;
    }

    /**
     * @notice Sets the stored oracle and HSO token contracts with the addresses resolved by ENS
     * @dev Accounts for subnodes having different resolvers
     * @param _ens The address of the ENS contract
     * @param _node The ENS node hash
     */
    function useHotspotOracleWithENS(address _ens, bytes32 _node) internal {
        ens = ENSInterface(_ens);
        ensNode = _node;
        bytes32 HSOSubnode =
            keccak256(abi.encodePacked(ensNode, ENS_TOKEN_SUBNAME));
        ENSResolver_HotspotOracle resolver =
            ENSResolver_HotspotOracle(ens.resolver(HSOSubnode));
        setHotspotOracleToken(resolver.addr(HSOSubnode));
        updateHotspotOracleOracleWithENS();
    }

    /**
     * @notice Sets the stored oracle contract with the address resolved by ENS
     * @dev This may be called on its own as long as `useHotspotOracleWithENS` has been called previously
     */
    function updateHotspotOracleOracleWithENS() internal {
        bytes32 oracleSubnode =
            keccak256(abi.encodePacked(ensNode, ENS_ORACLE_SUBNAME));
        ENSResolver_HotspotOracle resolver =
            ENSResolver_HotspotOracle(ens.resolver(oracleSubnode));
        setHotspotOracleOracle(resolver.addr(oracleSubnode));
    }

    /**
     * @notice Encodes the request to be sent to the oracle contract
     * @dev The HotspotOracle node expects values to be in order for the request to be picked up. Order of types
     * will be validated in the oracle contract.
     * @param _req The initialized HotspotOracle Request
     * @return The bytes payload for the `transferAndCall` method
     */
    function encodeRequest(HotspotOracle.Request memory _req)
        private
        view
        returns (bytes memory)
    {
        return
            abi.encodeWithSelector(
                oracle.oracleRequest.selector,
                SENDER_OVERRIDE, // Sender value - overridden by onTokenTransfer by the requesting contract's address
                AMOUNT_OVERRIDE, // Amount value - overridden by onTokenTransfer by the actual amount of HSO sent
                _req.id,
                _req.callbackAddress,
                _req.callbackFunctionId,
                _req.nonce,
                ARGS_VERSION,
                _req.buf.buf
            );
    }

    /**
     * @notice Ensures that the fulfillment is valid for this contract
     * @dev Use if the contract developer prefers methods instead of modifiers for validation
     * @param _requestId The request ID for fulfillment
     */
    function validateHotspotOracleCallback(bytes32 _requestId)
        internal
        recordHotspotOracleFulfillment(_requestId)
    // solhint-disable-next-line no-empty-blocks
    {

    }

    /**
     * @dev Reverts if the sender is not the oracle of the request.
     * Emits HotspotOracleFulfilled event.
     * @param _requestId The request ID for fulfillment
     */
    modifier recordHotspotOracleFulfillment(bytes32 _requestId) {
        require(
            msg.sender == pendingRequests[_requestId],
            "Source must be the oracle of the request"
        );
        delete pendingRequests[_requestId];
        emit HotspotOracleFulfilled(_requestId);
        _;
    }

    /**
     * @dev Reverts if the request is already pending
     * @param _requestId The request ID for fulfillment
     */
    modifier notPendingRequest(bytes32 _requestId) {
        require(
            pendingRequests[_requestId] == address(0),
            "Request is already pending"
        );
        _;
    }
}
