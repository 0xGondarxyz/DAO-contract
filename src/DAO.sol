// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./VoteToken.sol";

contract DAO is Ownable2Step, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // Tokens
    IERC20 public immutable usdc;
    VoteToken public immutable voteToken;

    // DAO Parameters
    uint256 public votingPeriod; // Blocks that voting lasts
    uint256 public proposalThreshold; // Min tokens needed to propose
    uint256 public quorumPercentage; // Min % of total supply needed to pass

    // Proposal tracking
    uint256 public proposalCount;

    // Events
    event VotingPeriodUpdated(uint256 newPeriod);
    event ProposalThresholdUpdated(uint256 newThreshold);
    event QuorumPercentageUpdated(uint256 newPercentage);
    event TokensPurchased(address indexed buyer, uint256 usdcAmount, uint256 voteTokenAmount);
    event ProposalCreated(
        uint256 proposalId, address proposer, string description, uint256 starttimestamp, uint256 endtimestamp
    );
    event ProposalCanceled(uint256 proposalId);
    event VoteCast(address indexed voter, uint256 proposalId, bool support, uint256 votes);
    event ProposalExecuted(uint256 proposalId);

    enum ProposalState {
        Pending,
        Active,
        Defeated,
        Succeeded,
        Executed,
        Canceled
    }
    //proposal struct

    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 starttimestamp;
        uint256 endtimestamp;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        bool canceled;
    }

    struct Vote {
        bool hasVoted;
        bool forProposal;
        uint256 votes;
    }

    //mapping of proposal id to proposal
    mapping(uint256 => Proposal) public proposals;
    //mapping of proposal id to user to vote
    mapping(uint256 => mapping(address => Vote)) public votes;

    constructor(
        address _usdc,
        address _voteToken,
        uint256 _votingPeriod,
        uint256 _proposalThreshold,
        uint256 _quorumPercentage
    ) Ownable(msg.sender) {
        require(_usdc != address(0), "Invalid USDC address");
        require(_voteToken != address(0), "Invalid vote token address");
        require(_quorumPercentage > 0 && _quorumPercentage <= 100, "Invalid quorum percentage");

        usdc = IERC20(_usdc);
        voteToken = VoteToken(_voteToken);
        votingPeriod = _votingPeriod;
        proposalThreshold = _proposalThreshold;
        quorumPercentage = _quorumPercentage;
    }

    //pausing functions
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    //update functions
    function updateVotingPeriod(uint256 _newPeriod) external onlyOwner {
        votingPeriod = _newPeriod;
        emit VotingPeriodUpdated(_newPeriod);
    }

    function updateProposalThreshold(uint256 _newThreshold) external onlyOwner {
        proposalThreshold = _newThreshold;
        emit ProposalThresholdUpdated(_newThreshold);
    }

    function updateQuorumPercentage(uint256 _newPercentage) external onlyOwner {
        require(_newPercentage > 0 && _newPercentage <= 100, "Invalid quorum percentage");
        quorumPercentage = _newPercentage;
        emit QuorumPercentageUpdated(_newPercentage);
    }

    //purchase tokens
    function purchaseTokens(uint256 _usdcAmount) external nonReentrant whenNotPaused {
        require(_usdcAmount > 0, "Invalid USDC amount");
        //transfer usdc from user to this contract
        usdc.safeTransferFrom(msg.sender, address(this), _usdcAmount);
        //mint vote tokens to user
        voteToken.mint(msg.sender, _usdcAmount * 1e12); //note we scale here bcs usdc has 6 decs and our vote token has 18 decs
        emit TokensPurchased(msg.sender, _usdcAmount, _usdcAmount * 1e12);
    }

    //propose function
    function createProposal(string memory _description, uint256 _startTime) external nonReentrant whenNotPaused {
        require(voteToken.getVotes(msg.sender) >= proposalThreshold, "Insufficient voting power");
        require(_startTime >= block.timestamp, "Invalid start time");

        proposalCount++;
        proposals[proposalCount] =
            Proposal(proposalCount, msg.sender, _description, _startTime, _startTime + votingPeriod, 0, 0, false, false);
        emit ProposalCreated(proposalCount, msg.sender, _description, _startTime, _startTime + votingPeriod);
    }

    function cancelProposal(uint256 _proposalId) external nonReentrant whenNotPaused {
        //caller should be proposer or owner
        require(msg.sender == proposals[_proposalId].proposer || msg.sender == owner(), "Not authorized");
        require(proposals[_proposalId].id != 0, "Proposal does not exist");
        require(block.timestamp < proposals[_proposalId].starttimestamp, "Voting has started");
        require(!proposals[_proposalId].canceled, "Proposal has been canceled");
        require(!proposals[_proposalId].executed, "Proposal has been executed");

        proposals[_proposalId].canceled = true;
        emit ProposalCanceled(_proposalId);
    }

    function castVote(uint256 _proposalId, bool _support) external nonReentrant whenNotPaused {
        require(proposals[_proposalId].id != 0, "Proposal does not exist");
        require(block.timestamp >= proposals[_proposalId].starttimestamp, "Voting has not started");
        require(block.timestamp < proposals[_proposalId].endtimestamp, "Voting period has ended");
        require(!proposals[_proposalId].canceled, "Proposal has been canceled");
        require(!proposals[_proposalId].executed, "Proposal has been executed");
        require(!votes[_proposalId][msg.sender].hasVoted, "Already voted");

        // Get voting power from delegated votes
        uint256 votingPower = voteToken.getVotes(msg.sender);
        require(votingPower > 0, "No voting power");

        if (_support) {
            proposals[_proposalId].forVotes += votingPower;
        } else {
            proposals[_proposalId].againstVotes += votingPower;
        }

        votes[_proposalId][msg.sender] = Vote(true, _support, votingPower);
        emit VoteCast(msg.sender, _proposalId, _support, votingPower);
    }

    //getter functions
    function getProposal(uint256 _proposalId) external view returns (Proposal memory) {
        return proposals[_proposalId];
    }

    function getUserVote(uint256 _proposalId, address _user) external view returns (Vote memory) {
        return votes[_proposalId][_user];
    }

    /**
     * getProposalState(proposalId)
     * Returns enum or uint representing state:
     *
     * Check if current block < startBlock: return Pending
     * Check if current block <= endBlock: return Active
     * Check if canceled flag: return Canceled
     * Check if executed flag: return Executed
     * Check if didn't reach quorum: return Defeated
     * Check if againstVotes >= forVotes: return Defeated
     * Otherwise: return Succeeded
     */
    function getProposalState(uint256 _proposalId) public view returns (ProposalState) {
        Proposal memory proposal = proposals[_proposalId];
        if (block.timestamp < proposal.starttimestamp) {
            return ProposalState.Pending;
        } else if (block.timestamp <= proposal.endtimestamp) {
            return ProposalState.Active;
        } else if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (!hasReachedQuorum(_proposalId)) {
            return ProposalState.Defeated;
        } else if (proposal.againstVotes >= proposal.forVotes) {
            return ProposalState.Defeated;
        } else {
            return ProposalState.Succeeded;
        }
    }

    function hasReachedQuorum(uint256 _proposalId) public view returns (bool) {
        Proposal memory proposal = proposals[_proposalId];
        uint256 totalSupply = voteToken.totalSupply();
        uint256 quorum = (totalSupply * quorumPercentage) / 100;
        return proposal.forVotes >= quorum;
    }

    function withdrawUSDC(uint256 _amount) external nonReentrant whenNotPaused onlyOwner {
        require(_amount > 0, "Invalid amount");
        require(usdc.balanceOf(address(this)) >= _amount, "Insufficient balance");
        usdc.safeTransfer(msg.sender, _amount);
    }

    /**
     *  executeProposal(proposalId)
     *
     * Require state is Succeeded (use getProposalState)
     * Require not already executed
     * Set executed flag to true
     * Emit ProposalExecuted event
     */
    function executeProposal(uint256 _proposalId) external nonReentrant whenNotPaused onlyOwner {
        require(getProposalState(_proposalId) == ProposalState.Succeeded, "Proposal not succeeded");
        require(!proposals[_proposalId].executed, "Proposal already executed");
        proposals[_proposalId].executed = true;
        emit ProposalExecuted(_proposalId);
    }

    /**
     * useful functions
     * getTotalVotes(proposalId) - returns forVotes + againstVotes
     * getQuorumRequired() - returns the calculated quorum threshold
     * isVotingActive(proposalId) - helper to check if voting is currently open
     */
    function getTotalVotes(uint256 _proposalId) public view returns (uint256) {
        Proposal memory proposal = proposals[_proposalId];
        return proposal.forVotes + proposal.againstVotes;
    }

    function getQuorumRequired() public view returns (uint256) {
        uint256 totalSupply = voteToken.totalSupply();
        uint256 quorum = (totalSupply * quorumPercentage) / 100;
        return quorum;
    }

    function isVotingActive(uint256 _proposalId) public view returns (bool) {
        Proposal memory proposal = proposals[_proposalId];
        return block.timestamp >= proposal.starttimestamp && block.timestamp <= proposal.endtimestamp;
    }
}
