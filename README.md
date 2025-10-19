# DAO Voting Protocol

A simple but complete DAO (Decentralized Autonomous Organization) implementation for community-driven decision making. Built as an educational project to demonstrate governance mechanics.

## Overview

This protocol allows users to purchase voting tokens with USDC and participate in governance by creating and voting on proposals. It follows OpenZeppelin's voting standards and implements a quorum-based approval system.

## Architecture

### Core Contracts

**VoteToken.sol**

- ERC20 token with voting capabilities (ERC20Votes)
- 18 decimals (standard)
- Requires delegation to activate voting power
- Uses OpenZeppelin's checkpoint system for vote tracking

**DAO.sol**

- Main governance contract
- Manages proposals, voting, and execution
- Handles USDC → VoteToken conversion (1:1)
- Implements quorum and threshold requirements

## Key Features

### Token Purchase

Users buy VoteTokens with USDC at 1:1 ratio. The contract converts 6-decimal USDC to 18-decimal VoteTokens automatically.

### Proposal Creation

- Requires minimum tokens (proposalThreshold)
- Proposer must have delegated voting power
- Custom start time and 7-day voting period

### Voting Mechanism

- One vote per address per proposal
- Users vote with their full delegated voting power
- Votes are immutable once cast
- Must have active voting power (delegated) to vote

### Proposal States

- **Pending**: Not started yet
- **Active**: Currently accepting votes
- **Defeated**: Failed quorum or more against than for
- **Succeeded**: Passed quorum with majority for
- **Executed**: Successfully executed by owner
- **Canceled**: Canceled by proposer/owner before voting starts

## Governance Parameters

- **Voting Period**: 7 days (604,800 seconds)
- **Proposal Threshold**: 100 tokens minimum to propose
- **Quorum**: 10% of total supply must vote FOR

## Design Decisions

### Why Block.timestamp over Block.number?

More user-friendly. "7 days" is clearer than "50,400 blocks" and doesn't depend on block time assumptions.

### Why 18 Decimals for VoteToken?

Standard ERC20 convention. Provides maximum flexibility for future features. Conversion from USDC (6 decimals) is straightforward: `usdcAmount * 10^12`.

### Why OpenZeppelin ERC20Votes?

- Battle-tested delegation system
- Built-in checkpoint mechanism prevents double-voting
- Standard used by major DAOs (Compound, Uniswap)
- Enables gasless delegation via signatures (delegateBySig)

### Quorum Logic

We check if `forVotes >= quorum`, not `totalVotes >= quorum`. This means:

- Only FOR votes count toward quorum
- Prevents opposition from helping reach quorum
- Common pattern in modern DAOs

## Critical: Delegation Requirement

**Users MUST delegate to themselves before voting:**

```solidity
voteToken.delegate(msg.sender);
```

This is an OpenZeppelin ERC20Votes requirement. Even if you own tokens, you have 0 voting power until delegation. This enables:

- Vote power transfers without token transfers
- Checkpoint system for historical vote tracking
- Representative voting (delegate to others)

## Functions

### User Functions

- `purchaseTokens(uint256 usdcAmount)` - Buy vote tokens
- `createProposal(string description, uint256 startTime)` - Create proposal
- `castVote(uint256 proposalId, bool support)` - Vote on proposal
- `cancelProposal(uint256 proposalId)` - Cancel own proposal

### View Functions

- `getProposal(uint256 proposalId)` - Get proposal details
- `getProposalState(uint256 proposalId)` - Get current state
- `hasReachedQuorum(uint256 proposalId)` - Check quorum status
- `getUserVote(uint256 proposalId, address user)` - Get user's vote
- `getQuorumRequired()` - Current quorum threshold
- `getTotalVotes(uint256 proposalId)` - Total votes cast

### Owner Functions

- `executeProposal(uint256 proposalId)` - Execute successful proposal
- `withdrawUSDC(uint256 amount)` - Withdraw treasury funds
- `pause() / unpause()` - Emergency controls
- `updateVotingPeriod()` - Change voting duration
- `updateProposalThreshold()` - Change minimum tokens to propose
- `updateQuorumPercentage()` - Change quorum requirement

## Testing

Run tests with Foundry:

```bash
forge test -vvvv
```

Key test scenarios:

- Token purchase and delegation
- Proposal creation and voting
- Quorum validation
- State transitions
- Access control

## Security Features

- ReentrancyGuard on state-changing functions
- Pausable for emergency stops
- Ownable2Step for safe ownership transfer
- SafeERC20 for token transfers
- One vote per address per proposal enforcement

## Future Improvements

- Timelock for execution delays
- Abstain voting option
- Vote reason/comment strings
- Snapshot-based voting (block-specific balances)
- Multi-sig owner for decentralization

## License

UNLICENSED
