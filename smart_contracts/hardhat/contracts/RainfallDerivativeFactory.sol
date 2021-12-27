// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// need to set LINK_ADDRESS depending on network

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

contract RainfallDerivativeProvider is ConfirmedOwner {
    /**
     * @dev RainfallDerivativeProvider contract for general rainfall option contracts
     */
    uint256 private constant ORACLE_PAYMENT = 1 * 10**15;                                                       // 0.001 LINK
    address public constant LINK_ADDRESS = 0xa36085F69e2889c224210F603D836748e7dC0088;                          // Link token address on Matic Mumbai

    mapping(string => RainfallOption) public contracts;
    
    /**
     * @dev Event to log when a contract is created
     */
    event contractCreated(address _contract, string _id);

    /**
     * @dev Sets deploying address as owner
     */
    constructor() ConfirmedOwner(msg.sender) {}

    /**
     * @notice Create a new rainfall options contract
     * @dev Can only be called by the contract owner
     * @param _locations string array of lat-lon coordinate pairs (see examples below)
     * @param _parameters string array of all other contract parameters
     * @param _end uint256 unix timestamp of contract end date
     *
     * _parameters = [id, dataset, optType, start, end, strike, limit, tick]
     * id string ID for the contract to deploy, e.g. "Prasat Bakong PUT, limit: 1.18k"
     * dataset string name of the dataset for the contract, e.g. "chirpsc_final_25-daily"
     * optType string type of option, "CALL" or "PUT"
     * start uint256 unix timestamp of contract start date
     * end uint256 unix timestamp of contract end date
     * strike uint256 contract strike (times 10^20 for solidity)
     * limit uint256 contract limit (times 10^20 for solidity)
     * tick uint256 contract tick (times 10^20 for solidity)
     */
    function newContract(
        string[] memory _locations,         // e.g. ["[12.76727009, 104.01941681]","[12.76727009, 104.26941681]",...,"[13.51727009, 104.26941681]"]
        string[8] memory _parameters,
        uint256 _end
    ) 
        external 
        onlyOwner 
    {
        RainfallOption rainfallContract = new RainfallOption();
        rainfallContract.initialize(ORACLE_PAYMENT, LINK_ADDRESS, _locations, _parameters, _end);
        rainfallContract.addOracleJob(0x7bcfF26a5A05AF38f926715d433c576f9F82f5DC, stringToBytes32("6de976e92c294704b7b2e48358f43396"));
        contracts[_parameters[0]] = rainfallContract;
        // fund the new contract with enough LINK tokens to make at least 1 Oracle request, with a buffer
        LinkTokenInterface link = LinkTokenInterface(LINK_ADDRESS);
        require(link.transfer(address(rainfallContract), ORACLE_PAYMENT * 2), "Unable to fund deployed contract");
        emit contractCreated(address(rainfallContract), _parameters[0]);
    }

    /**
     * @notice Request payout evaluation for a specified contract
     * @dev Can only be called by the contract owner
     * @param _id string contract ID
     */
    function initiateContractEvaluation(
        string memory _id
    ) 
        external 
        onlyOwner 
    {
        contracts[_id].requestPayoutEvaluation();
    }

    /**
     * @notice Returns the contract for a given id
     * @param _id string contract ID
     * @return RainfallOption instance
     */
    function getContract(
        string memory _id
    )
        external
        view
        returns (RainfallOption)
    {
        return contracts[_id];
    }

    /**
     * @notice Returns the address of the contract for a given id
     * @param _id string contract ID
     * @return address of deployed contract
     */
    function getContractAddress(
        string memory _id
    )
        external
        view
        returns (address)
    {
        return address(contracts[_id]);
    }

    /**
     * @notice Returns the payout value for a specified contract
     * @param _id string contract ID
     * @return uint256 payout value
     */
    function getContractPayout(
        string memory _id
    )
        external
        view
        returns (uint256)
    {
        return contracts[_id].getPayout();
    }

    /**
     * @notice Add a new node and associated job ID to the contract execution/evalution set
     * @dev Can only be called by the contract owner
     * @param _id string contract ID
     * @param _oracle address of oracle contract for chainlink node
     * @param _job string ID for associated oracle job
     */
    function addContractJob(
        string memory _id,
        address _oracle,
        string memory _job
    ) 
        external 
        onlyOwner 
    {
       contracts[_id].addOracleJob(_oracle, stringToBytes32(_job));
    }

    /**
     * @notice Remove a job from the contract execution/evaluation set
     * @dev Can only be called by the contract owner
     * @param _id string contract ID
     * @param _job string ID for associated oracle job
     */
    function removeContractJob(
        string memory _id, 
        string memory _job
    )
        external
        onlyOwner
    {
        contracts[_id].removeOracleJob(stringToBytes32(_job));
    }

    /**
     * @notice Get the ETH/matic/gas balance of the provider contract
     * @dev Can only be called by the contract owner
     * @return uint256 ETH balance
     */
    function getETHBalance() 
        external 
        view 
        onlyOwner
        returns (uint256) 
    {
        return address(this).balance;
    }

    /**
     * @notice Get the LINK balance of the provider contract
     * @dev Can only be called by the contract owner
     * @return uint256 LINK balance
     */
    function getLINKBalance() 
        external 
        view 
        onlyOwner
        returns (uint256) 
    {
        LinkTokenInterface link = LinkTokenInterface(LINK_ADDRESS);
        return link.balanceOf(address(this));
    }

    /**
     * @dev Write string to bytes32
     * @param _source string to convert
     * @return _result bytes32 converted string
     */
    function stringToBytes32(
        string memory _source
    )
        private
        pure
        returns (bytes32 _result)
    {
        bytes memory tempEmptyStringTest = bytes(_source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            // solhint-disable-line no-inline-assembly
            _result := mload(add(_source, 32))
        }
    }

    /**
     * @notice Development function to end specified contract, in case of bugs or needing to update logic etc
     * @dev Can only be called by the contract owner
     * @param _id string contract ID
     *
     * REMOVE IN PRODUCTION
     */
    function endContractInstance(
        string memory _id
    ) 
        external 
        onlyOwner 
    {
        contracts[_id].endContractInstance();
    }

    /**
     * @notice Development function to end provider contract, in case of bugs or needing to update logic etc
     * @dev Can only be called by the contract owner
     *
     * REMOVE IN PRODUCTION
     */
    function endProviderContract() 
        external 
        onlyOwner 
    {
        LinkTokenInterface link = LinkTokenInterface(LINK_ADDRESS);
        require(link.transfer(owner(), link.balanceOf(address(this))), "Unable to transfer");
        selfdestruct(payable(owner()));
    }
}


contract RainfallOption is ChainlinkClient, ConfirmedOwner {
    /**
     * @dev RainfallOption contract for rainfall option contracts
     */
    using Chainlink for Chainlink.Request;

    uint256 private oraclePayment;
    mapping(bytes32 => uint256) public oracleMap;
    address[] public oracles;
    bytes32[] public jobs;

    bool public contractActive;
    bool public contractEvaluated;
    uint256 private requestsPending;

    string[] public locations;
    string[8] public parameters;
    uint256 private end;
    uint256 public payout;

    event contractEnded(address _contract, uint256 _time);
    event evaluationRequestSent(address _contract, address _oracle, bytes32 _request, uint256 _time);
    event evaluationRequestFulfilled(address _contract, uint256 _payout, uint256 _time);

    /**
     * @notice Creates a new rainfall option contract
     * @dev Assigns caller address as contract ownert
     */
    constructor() 
        ConfirmedOwner(msg.sender) 
    {
        payout = 0;
        contractActive = false;
        contractEvaluated = false;
        requestsPending = 0;
    }

    /**
     * @notice Initializes rainfall contract terms
     * @dev Can only be called by the contract owner
     * @param _oraclePayment uint256 oracle payment amount
     * @param _link address of LINK token on deployed network
     * @param _locations string array of lat-lon coordinate pairs (see examples below)
     * @param _parameters string array of all other contract parameters: [id, dataset, optType, start, end, strike, limit, tick]
     * @param _end uint256 unix timestamp of contract end date
     */
    function initialize(
        uint256 _oraclePayment,
        address _link,
        string[] memory _locations, 
        string[8] memory _parameters,
        uint256 _end
    ) 
        public 
        onlyOwner 
    {
        oraclePayment = _oraclePayment;
        setChainlinkToken(_link);
        locations = _locations;
        parameters = _parameters;
        end = _end;
        contractActive = true;
    }

    /**
     * @notice Add a new node and associated job ID to the contract evaluator set
     * @dev Can only be called by the contract ownder
     * @param _oracle address of oracle contract for chainlink node
     * @param _job bytes32 ID for associated oracle job
     */
    function addOracleJob(
        address _oracle, 
        bytes32 _job
    )   
        public 
        onlyOwner
    {
        oracles.push(_oracle);
        jobs.push(_job);
        oracleMap[_job] = oracles.length - 1;
    }

    /**
     * @notice Remove a node and associated job ID from the contract evaluator set
     * @dev Can only be called by the contract ownder
     * @param _job bytes32 ID of oracle job to remove
     */
    function removeOracleJob(
        bytes32 _job
    ) 
        public 
        onlyOwner
    {
        uint256 index = oracleMap[_job];
        oracles[index] = oracles[oracles.length - 1];
        oracles.pop();
        jobs[index] = jobs[jobs.length - 1];
        jobs.pop();
        oracleMap[jobs[index]] = index;
    }

    /**
     * @notice Makes a chainlink oracle request to compute a payout evaluation for this contract
     * @dev Can only be called by the contract owner
     */
    function requestPayoutEvaluation() 
        public 
        onlyOwner 
    {
        require(end < block.timestamp && contractActive, "unable to call until coverage period has ended");
        // prevents function from making more than one round of oracle requests
        contractActive = false;
        emit contractEnded(address(this), block.timestamp);
        // do all looped reads from memory instead of storage
        uint256 _oraclePayment = oraclePayment;
        address[] memory _oracles = oracles;
        bytes32[] memory _jobs = jobs;
        string[] memory _locations = locations;
        string[8] memory memParameters = parameters;
        uint256 requests = 0;
        for (uint256 i = 0; i != _oracles.length; i += 1) {
            Chainlink.Request memory req = buildChainlinkRequest(_jobs[i], address(this), this.fulfillPayoutEvaluation.selector);
            req.addStringArray("locations", _locations);
            req.add("dataset", memParameters[1]);
            req.add("opt_type", memParameters[2]);
            req.add("start", memParameters[3]);
            req.add("end", memParameters[4]);
            req.add("strike", memParameters[5]);
            req.add("limit", memParameters[6]);
            req.add("tick", memParameters[7]);
            bytes32 requestId = sendChainlinkRequestTo(_oracles[i], req, _oraclePayment);
            requests += 1;
            emit evaluationRequestSent(address(this), _oracles[i], requestId, block.timestamp);
            }
        requestsPending = requests;
    }

    /**
     * @dev Callback function for chainlink oracle requests, assigns payout
     */
    function fulfillPayoutEvaluation(bytes32 _requestId, uint256 _result)
        public
        recordChainlinkFulfillment(_requestId)
    {
        payout += _result;
        requestsPending -= 1;
        if (requestsPending == 0) {
            payout /= oracles.length;
            contractEvaluated = true;

            LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
            require(link.transfer(owner(), link.balanceOf(address(this))), "Unable to transfer remaining LINK tokens");
        }
        emit evaluationRequestFulfilled(address(this), _result, block.timestamp);
    }

    /**
     * @notice Get the contract payout value, which may not be final
     * @dev Returns the final evaluation or 0 most of the time, and can possibly return an approximate value if currently evaluating on multuiple nodes
     * @return uint256 evaluated payout
     */
    function getPayout() 
        public 
        view 
        returns (uint256) 
    {
        if (contractEvaluated) {
            return payout;
        } else {
            // 0 if contract is active, "close" if contract is currently evaluating, no effect if only one oracle job
            return payout / (oracles.length - requestsPending); 
        }
    }

    /**
     * @notice Get the LINK balance of the contract
     * @dev Can only be called by the contract owner
     * @return uint256 LINK balance
     */
    function getLINKBalance() 
        external 
        view 
        onlyOwner
        returns (uint256) 
    {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        return link.balanceOf(address(this));
    }

    /**
     * @notice Development function to end contract, in case of bugs or needing to update logic etc
     * @dev Can only be called by the contract owner
     *
     * REMOVE IN PRODUCTION
     */
    function endContractInstance() 
        public 
        onlyOwner 
    {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.transfer(owner(), link.balanceOf(address(this))), "Unable to transfer");
        selfdestruct(payable(owner()));
    }
}
