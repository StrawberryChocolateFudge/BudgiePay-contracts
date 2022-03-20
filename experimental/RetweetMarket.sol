//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// The retweet market allows a user to place a bounty on tweets,
// if a user retweeted them, he can withdraw the tokens as reward.
// WIP MAYBE IN THE FUTURE...
struct RetweetBounty {
    uint256 id;
    bool active;
    string tweetId;
    address creator;
    string creatorTwitterUserId;
    uint256 funded;
}

contract RetweetMarket {
    // Use the RetweetBountyId to map a twitterUserId to a boolean to check if tweet was retweeted by a user already with bounty claimed, or not
    mapping(uint256 => mapping(string => bool)) private retweetedBounty;

    mapping(uint256 => RetweetBounty) private bounties;
    uint256 private bountyIndex;
    address private owner;
    address private signer;
    IERC20 private token;

    constructor(IERC20 _token, address _signer) {
        owner = msg.sender;
        signer = _signer;
        token = _token;
    }

    function setSigner(address to) external {
        require(msg.sender == owner, "Only the owner can call this");
        signer = to;
    }

    function verifyCreate(
        uint8 v,
        bytes32 r,
        bytes32 s,
        string calldata tweetId,
        address creator,
        string calldata creatorTwitterUserId
    ) public {}

    function verifyClose() public {}

    function verifyClaim() public {}

    function createBounty(
        uint8 v,
        bytes32 r,
        bytes32 s,
        string calldata tweetId,
        address creator,
        string calldata creatorTwitterUserId
    ) external {}

    function closeBounty() external {}

    function claimBounty() external {}
}
