// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {VoteToken} from "../src/VoteToken.sol";
import {DAO} from "../src/DAO.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {
        _mint(msg.sender, 1_000_000_000 * 1e6);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract DAOtest is Test {
    MockUSDC public usdc;
    VoteToken public voteToken;
    DAO public dao;

    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");

    function setUp() public {
        usdc = new MockUSDC();
        voteToken = new VoteToken();
        dao = new DAO(
            address(usdc),
            address(voteToken),
            7 days, // ~7 days voting period (assuming 12s blocks)
            100 * 1e18, // 100 tokens to propose
            10 // 10% quorum
        );
        // Transfer VoteToken ownership to DAO so it can mint
        voteToken.transferOwnership(address(dao));

        // Give test users some USDC
        usdc.transfer(user1, 10_000 * 1e6); // 10k USDC
        usdc.transfer(user2, 10_000 * 1e6);
        usdc.transfer(user3, 10_000 * 1e6);

        //users give allowance to dao
        vm.startPrank(user1);
        usdc.approve(address(dao), 10_000 * 1e6);
        dao.purchaseTokens(10_000 * 1e6);
        vm.stopPrank();

        vm.startPrank(user2);
        usdc.approve(address(dao), 10_000 * 1e6);
        dao.purchaseTokens(10_000 * 1e6);
        vm.stopPrank();

        vm.startPrank(user3);
        usdc.approve(address(dao), 10_000 * 1e6);
        // dao.purchaseTokens(10_000 * 1e6);
        vm.stopPrank();

        // Optional: Label addresses for better trace readability
        vm.label(address(dao), "DAO");
        vm.label(address(voteToken), "VoteToken");
        vm.label(address(usdc), "USDC");
    }

    function test_setup() public {
        assertEq(dao.votingPeriod(), 7 days);
        assertEq(dao.proposalThreshold(), 100 * 1e18);
        assertEq(dao.quorumPercentage(), 10);
    }

    function test_user_purchase_tokens() public {
        vm.startPrank(user3); //bcs user3 has not purchased tokens in the setup
        dao.purchaseTokens(10_000 * 1e6);
        assertEq(voteToken.balanceOf(user3), 10_000 * 1e18);
        vm.stopPrank();
    }

    function test_propose() public {
        vm.startPrank(user1);
        // dao.purchaseTokens(10_000 * 1e6);
        // assertEq(voteToken.balanceOf(user1), 10_000 * 1e18);
        dao.propose("Test proposal");
        vm.stopPrank();
    }

    function test_castVote() public {
        vm.startPrank(user1);
        dao.propose("Test proposal");
        vm.stopPrank();
        //user 2 votes
        vm.startPrank(user2);
        dao.castVote(1, true, 5_000 * 1e18);
        vm.stopPrank();
        assertEq(dao.getProposal(1).forVotes, 5_000 * 1e18);
        //get proposal
        dao.getProposal(1);
        //get user votes
        dao.getUserVotes(user2, 1);
    }
}
