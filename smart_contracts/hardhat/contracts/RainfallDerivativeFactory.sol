// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

contract RainfallDerivativeProvider is ConfirmedOwner {
    /**
     * @notice RainfallDerivativeProvider contract for general rainfall option contracts
     */
    uint256 private constant ORACLE_PAYMENT = 1 * 10**14;                                                        // 0.0001 LINK
    address public constant LINK_ADDRESS = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;                          // Link token address on Matic Mumbai

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
     * @param _id string ID for the contract to deploy
     * @param _dataset string name of the dataset for the contract
     * @param _optType string type of option, "CALL" or "PUT"
     * @param _start uint256 unix timestamp of contract start date
     * @param _end uint256 unix timestamp of contract end date
     * @param _strike uint256 contract strike (times 10^8 for solidity)
     * @param _limit uint256 contract limit (times 10^8 for solidity)
     * @param _tick uint256 contract tick (times 10^8 for solidity)
     */
    function newContract(
        string[] memory _locations,     // e.g. ["[12.76727009, 104.01941681]","[12.76727009, 104.26941681]",...,"[13.51727009, 104.26941681]"]
        string memory _id,              // e.g. "Prasat Bakong PUT, limit: 1.18k"
        string memory _dataset,         // e.g. "chirpsc_final_25-daily"
        string memory _optType,
        uint256 _start,
        uint256 _end,
        uint256 _strike,
        uint256 _limit,
        uint256 _tick
    ) 
        external 
        onlyOwner 
    {
        RainfallOption rainfallContract = new RainfallOption(ORACLE_PAYMENT, LINK_ADDRESS);
        rainfallContract.initialize(_locations, _dataset, _optType, _start, _end, _strike, _limit, _tick)
        rainfallContract.addOracleJob(0x7bcfF26a5A05AF38f926715d433c576f9F82f5DC, stringToBytes32("6de976e92c294704b7b2e48358f43396"));
        contracts[_id] = rainfallContract;
        // fund the new contract with enough LINK tokens to make at least 1 Oracle request, with a buffer
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.transfer(address(i), ORACLE_PAYMENT * 2), "Unable to fund deployed contract");
        emit contractCreated(address(i), _id);
    }

    /**
     * @notice Request payout evaluation for a specified contract
     * @dev Can only be called by the contract owner
     * @param _id string contract ID
     */
    function initiatePayoutEvaluation(
        string memory _id
    ) 
        external 
        onlyOwner 
    {
        contracts[_id].requestPayoutEvaluation();
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
     * @return uint256 ETH baalance
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
     * @return uint256 LINK baalance
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
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.transfer(owner(), link.balanceOf(address(this))), "Unable to transfer");
        selfdestruct(payable(owner()));
    }
}


contract RainfallOption is ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;

    uint256 private oraclePayment;
    mapping(address => uint256) public oracleMap;
    address[] public oracles;
    bytes32[] public jobs;

    bool public contractActive;
    bool public contractEvaluated;
    uint256 private requestsPending;

    string[] private locations;
    string private dataset;
    string private optType;
    uint256 private start;
    uint256 private end;
    uint256 private strike;
    uint256 private limit;
    uint256 private tick;
    uint256 private payout;

    event contractEnded(address _contract, uint256 _time);
    event evaluationRequestSent(address _contract, address _oracle, bytes32 _request, uint256 _time);
    event evaluationRequestFulfilled(address _contract, uint256 _payout, uint256 _time);

    /**
     * @notice Creates a new rainfall option contract
     * @dev Assigns caller address as contract ownert
     * @param _oraclePayment uint256 oracle payment amount
     * @param _link address of LINK token on deployed network
     */
    constructor(
        uint256 _oraclePayment,
        address _link
    ) 
        ConfirmedOwner(msg.sender) 
    {
        oraclePayment = _oraclePayment;
        setChainlinkToken(_link);
        payout = 0;
        contractActive = false;
        contractEvaluated = false;
        requestsPending = 0;
    }

    /**
     * @notice Initializes rainfall contract terms
     * @dev Can only be called by the contract owner
     * @param _locations string array of lat-lon coordinate pairs (see examples below)
     * @param _dataset string name of the dataset for the contract
     * @param _optType string type of option, "CALL" or "PUT"
     * @param _start uint256 unix timestamp of contract start date
     * @param _end uint256 unix timestamp of contract end date
     * @param _strike uint256 contract strike (times 10^8 for solidity)
     * @param _limit uint256 contract limit (times 10^8 for solidity)
     * @param _tick uint256 contract tick (times 10^8 for solidity)
     */
    function initialize(
        string[] memory _locations, 
        string memory _dataset, 
        string memory _opt_type, 
        uint256 _start,
        uint256 _end, 
        uint256 _strike,
        uint256 _limit,
        uint256 _tick
    ) 
        public 
        onlyOwner 
    {
        locations = _locations;
        dataset = _dataset;
        opt_type = _opt_type;
        start = _start;
        end = _end;
        strike = _strike;
        limit = _limit;
        tick = _tick;
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
        emit contractEnded(address(this), end, block.timestamp);
        // do all looped reads from memory instead of storage
        uint256 _oraclePayment = oraclePayment;
        address[] memory _oracles = oracles;
        bytes32[] memory _jobs = jobs;
        string[] memory _locations = locations;
        string memory _dataset = dataset;
        string memory _optType = optType;
        uint256 _start = start;
        uint256 _end = end;
        uint256 _strike = strike;
        uint256 _limit = limit;
        uint256 _tick = tick;
        for (uint256 i = 0; i != _oracles.length; i += 1) {
            Chainlink.Request memory req = buildChainlinkRequest(_jobs[i], address(this), this.fulfillPayoutEvaluation.selector);
            req.add("dataset", _dataset);
            req.add("opt_type", _optType);
            req.addStringArray("locations", _locations);
            req.addUint("start", _start);
            req.addUint("end", _end);
            req.addUint("strike", _strike);
            req.addUint("limit", _limit);
            req.addUint("tick", _tick);
            bytes32 requestId = sendChainlinkRequestTo(_oracles[i], req, _oraclePayment);
            requestsPending += 1;
            emit evaluationRequestSent(address(this), _oracles[i], requestId, block.timestamp);
            }
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
     * @notice Get the contract status
     * @return bool contract evaluation status
     */
    function getStatus() 
        public 
        view 
        returns (bool) 
    {
        return contractEvaluated;
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