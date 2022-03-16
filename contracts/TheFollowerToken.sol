//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TheFollowerToken is ERC20 {
    address private signer;
    address private owner;
    uint256 private totalMinted;
    uint256 private maximumMinted;
    mapping(string => bool) private withdrawnAlready;

    constructor(
        uint256 initialSupply,
        uint256 _maximumMinted,
        address signerAddress
    ) ERC20("TFT", "TFT") {
        _mint(msg.sender, initialSupply);
        totalMinted = initialSupply;
        owner = msg.sender;
        maximumMinted = _maximumMinted;
        signer = signerAddress;
    }

    function setSigner(address to) external {
        require(msg.sender == owner, "Only the owner can call this");
        signer = to;
    }

    function verifySignature(
        uint8 v,
        bytes32 r,
        bytes32 s,
        string calldata twitterId,
        uint256 followers,
        address authorizedAddress
    ) public view returns (address) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        bytes32 eip712DomainHash = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes("TheFollowerToken")),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );
        bytes32 hashStruct = keccak256(
            abi.encode(
                keccak256(
                    bytes(
                        "doc(string twitterId,uint256 followers,address authorizedAddress)"
                    )
                ),
                keccak256(bytes(twitterId)),
                keccak256(abi.encode(followers)),
                keccak256(abi.encode(authorizedAddress))
            )
        );
        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", eip712DomainHash, hashStruct)
        );
        return ecrecover(hash, v, r, s);
    }

    function mintFollowerToken(
        uint8 v,
        bytes32 r,
        bytes32 s,
        string calldata twitterId,
        address authorizedAddress,
        uint256 followers
    ) external {
        require(
            withdrawnAlready[twitterId] == false,
            "The user withdrew the tokens already."
        );
        address _signer = verifySignature(
            v,
            r,
            s,
            twitterId,
            followers,
            authorizedAddress
        );
        require(_signer == signer, "Invalid Signer");
        uint256 tokensToMint = followers * 10**uint256(18); // Update total supply with the decimal amount
        require(
            tokensToMint + totalMinted <= maximumMinted,
            "Cannot mint more tokens!"
        );
        require(authorizedAddress == msg.sender, "You are not authorized");
        totalMinted += tokensToMint;
        withdrawnAlready[twitterId] = true;
        _mint(msg.sender, tokensToMint);
    }

    function getWithdrawnAlready(string calldata twitterId)
        external
        view
        returns (bool)
    {
        return withdrawnAlready[twitterId];
    }
}
