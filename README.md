1. Proposal Struct
   Store:

Proposal ID
Proposer address
Description (string)
Start block (when voting begins)
End block (when voting ends)
For votes count
Against votes count
Executed flag
Canceled flag

2. Proposal Storage

Mapping: proposal ID → Proposal struct
Mapping: proposal ID → voter address → has voted (bool)
Maybe mapping: proposal ID → voter address → vote choice (for/against)

3. createProposal()

Check proposer has enough tokens (>= proposalThreshold)
Increment proposal counter
Create new proposal with:

Current block as start
Current block + votingPeriod as end
Zero votes
Not executed, not canceled

Store in mapping
Emit event

4. castVote()

Check proposal exists
Check voting is active (current block between start and end)
Check voter hasn't voted yet
Get voter's token balance (voting power)
Check they have tokens
Add their voting power to forVotes or againstVotes
Mark them as voted
Emit event

5. getProposalState()
   Returns enum: Pending, Active, Defeated, Succeeded, Executed, Canceled
   Logic:

If current block < start: Pending
If current block <= end: Active
If canceled: Canceled
If executed: Executed
If didn't reach quorum OR against > for: Defeated
If reached quorum AND for > against: Succeeded

6. executeProposal()

Check proposal succeeded (use getProposalState)
Check not already executed
Mark as executed
Emit event (in real DAO, this would trigger actual actions)

7. Helper Functions

hasVoted(proposalId, voter) - returns bool
getProposal(proposalId) - returns proposal details
Calculate quorum: (totalSupply \* quorumPercentage) / 100

Key Logic Points:

Use block.number for timing
Quorum = minimum total votes needed
Vote with current balance (or use snapshots for more advanced)
Once voted, can't change vote
