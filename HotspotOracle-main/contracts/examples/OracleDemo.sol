pragma solidity ^0.6.0;

import "../HotspotOracleClient.sol";

contract APIConsumer is HotspotOracleClient {
  
    uint256 public volume;
    
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;

    constructor(address _oracle, address _hso) public {
        setHotspotOracleToken(_hso);
        oracle = _oracle;
        jobId = "29fa9aa13bf1468788b7cc4a500a45b8";
        fee = 0.1 * 10 ** 18; // 0.1 HSO
    }
    
    /**
     * Create a Hotspot request to retrieve API response, find the target
     * data, then multiply by 1000000000000000000 (to remove decimal places from data).
     */
    function requestVolumeData() public returns (bytes32 requestId) 
    {
        HotspotOracle.Request memory request = buildHotspotOracleRequest(jobId, address(this), this.fulfill.selector);
        
        // Set the URL to perform the GET request on
        request.add("get", "https://min-api.cryptocompare.com/data/pricemultifull?fsyms=ETH&tsyms=USD");
        request.add("path", "RAW.ETH.USD.VOLUME24HOUR");

        // Multiply the result by 1000000000000000000 to remove decimals
        int timesAmount = 10**18;
        request.addInt("times", timesAmount);
        
        // Sends the request
        return sendHotspotOracleRequesHotspotOracletTo(oracle, request, fee);
    }
    
    /**
     * Receive the response in the form of uint256
     */ 
    function fulfill(bytes32 _requestId, uint256 _volume) public recordHotspotOracleFulfillment(_requestId)
    {
        volume = _volume;
    }
}