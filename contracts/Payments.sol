//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
struct Payment {
    uint256 id;
    uint8 paymentType; // 0 for eth and 1 for token
    address from;
    bytes32 fromTwitterId;
    bytes32 toTwitterId;
    uint256 amount;
    bool claimed;
    bool refunded;
    bool initialized;
}

contract Payments is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Address for address payable;
    address private signer;
    address private owner;
    IERC20 private token;
    // paymentId => Payment
    mapping(uint256 => Payment) private payments;
    uint256 private paymentIndex;

    // fromTwitterId hash => paymentIndex[]
    mapping(bytes32 => uint256[]) private fromPayments;
    // toTwitterId hash => paymentIndex[]
    mapping(bytes32 => uint256[]) private toPayments;

    uint256 private totalEthBalance;
    uint256 private currentEthBalance;
    uint256 private totalTokenBalance;
    uint256 private currentTokenBalance;

    constructor(address signerAddress, IERC20 _token) {
        signer = signerAddress;
        owner = msg.sender;
        token = _token;
    }

    function setSigner(address to) external {
        require(msg.sender == owner, "Only the owner can call this");
        signer = to;
    }

    function verifyPaymentSignature(
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint8 paymentType,
        address from,
        string calldata fromTwitterId,
        string calldata toTwitterId,
        uint256 amount
    ) public view returns (address) {
        bytes32 domain = getDomainHash();

        bytes32 hashStruct = keccak256(
            abi.encode(
                keccak256(
                    "doc(uint8 paymentType,address from,string fromTwitterId,string toTwitterId,uint256 amount)"
                ),
                keccak256(abi.encode(paymentType)),
                keccak256(abi.encode(from)),
                keccak256(bytes(fromTwitterId)),
                keccak256(bytes(toTwitterId)),
                keccak256(abi.encode(amount))
            )
        );

        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", domain, hashStruct)
        );

        return ecrecover(hash, v, r, s);
    }

    function verifyWithdrawSignature(
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint256 id,
        string calldata toTwitterId,
        address from
    ) public view returns (address) {
        bytes32 domain = getDomainHash();
        bytes32 hashStruct = keccak256(
            abi.encode(
                keccak256("doc(uint256 id,string toTwitterId,address from)"),
                keccak256(abi.encode(id)),
                keccak256(bytes(toTwitterId)),
                keccak256(abi.encode(from))
            )
        );
        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", domain, hashStruct)
        );
        return ecrecover(hash, v, r, s);
    }

    function verifyRefundSignature(
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint256 id,
        string calldata fromTwitterId,
        address from
    ) public view returns (address) {
        bytes32 domain = getDomainHash();
        bytes32 hashStruct = keccak256(
            abi.encode(
                keccak256("doc(uint256 id,string fromTwitterId,address from)"),
                keccak256(abi.encode(id)),
                keccak256(bytes(fromTwitterId)),
                keccak256(abi.encode(from))
            )
        );
        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", domain, hashStruct)
        );
        return ecrecover(hash, v, r, s);
    }

    function payEth(
        uint8 v,
        bytes32 r,
        bytes32 s,
        address from,
        string calldata fromTwitterId,
        string calldata toTwitterId,
        uint256 amount
    ) external payable {
        require(msg.sender == from, "Invalid signature");
        address _signer = verifyPaymentSignature(
            v,
            r,
            s,
            0,
            from,
            fromTwitterId,
            toTwitterId,
            amount
        );
        require(_signer == signer, "Invalid Signer");

        // If I'm paying in ETH
        require(msg.value == amount, "Amount and Value mismatch");
        // The ETH is transfered to this contract
        totalEthBalance += msg.value;
        currentEthBalance += msg.value;
        createPayment(0, from, fromTwitterId, toTwitterId, amount);
    }

    function payToken(
        uint8 v,
        bytes32 r,
        bytes32 s,
        address from,
        string calldata fromTwitterId,
        string calldata toTwitterId,
        uint256 amount
    ) external {
        require(msg.sender == from, "Invalid signature");
        address _signer = verifyPaymentSignature(
            v,
            r,
            s,
            1,
            from,
            fromTwitterId,
            toTwitterId,
            amount
        );
        require(_signer == signer, "Invalid Signer");
        // If I pay with tokens, I transfer those to this contract
        token.safeTransferFrom(from, address(this), amount);
        totalTokenBalance += amount;
        currentTokenBalance += amount;
        createPayment(1, from, fromTwitterId, toTwitterId, amount);
    }

    function createPayment(
        uint8 paymentType,
        address from,
        string calldata fromTwitterId,
        string calldata toTwitterId,
        uint256 amount
    ) internal {
        paymentIndex += 1;
        bytes32 fromTwitterIdHash = keccak256(bytes(fromTwitterId));
        bytes32 toTwitterIdHash = keccak256(bytes(toTwitterId));
        Payment memory payment = Payment({
            id: paymentIndex,
            paymentType: paymentType,
            from: from,
            fromTwitterId: fromTwitterIdHash,
            toTwitterId: toTwitterIdHash,
            amount: amount,
            claimed: false,
            refunded: false,
            initialized: true
        });

        fromPayments[fromTwitterIdHash].push(paymentIndex);
        toPayments[toTwitterIdHash].push(paymentIndex);
        payments[paymentIndex] = payment;
    }

    function withdraw(
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint256 id,
        string calldata toTwitterId,
        address from
    ) external nonReentrant {
        require(msg.sender == from, "Invalid sender");
        address _signer = verifyWithdrawSignature(
            v,
            r,
            s,
            id,
            toTwitterId,
            from
        );
        require(_signer == signer, "Invalid Signer");
        require(payments[id].initialized, "Invalid id");
        require(!payments[id].claimed, "Already Claimed");
        require(!payments[id].refunded, "Already Refunded");
        require(
            payments[id].toTwitterId == keccak256(bytes(toTwitterId)),
            "Invalid TwitterId"
        );

        // Do the withdraw
        payments[id].claimed = true;
        if (payments[id].paymentType == 0) {
            // The contract must have enough balance, this should never throw
            require(
                currentEthBalance >= payments[id].amount,
                "Not enough balance"
            );
            payable(from).sendValue(payments[id].amount);
            currentEthBalance -= payments[id].amount;
        } else {
            require(
                currentTokenBalance >= payments[id].amount,
                "Not enough tokens"
            );
            token.safeTransfer(from, payments[id].amount);
            currentTokenBalance -= payments[id].amount;
        }
    }

    function refund(
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint256 id,
        string calldata fromTwitterId,
        address from
    ) external {
        require(msg.sender == from, "Invalid sender");
        address _signer = verifyRefundSignature(
            v,
            r,
            s,
            id,
            fromTwitterId,
            from
        );
        require(_signer == signer, "Invalid Signer");
        require(payments[id].initialized, "Invalid id");
        require(!payments[id].claimed, "Already Claimed");
        require(!payments[id].refunded, "Already Refunded");
        require(
            payments[id].fromTwitterId == keccak256(bytes(fromTwitterId)),
            "Invalid TwitterId"
        );

        payments[id].refunded = true;

        if (payments[id].paymentType == 0) {
            require(
                currentEthBalance >= payments[id].amount,
                "Not Enough Blance"
            );
            payable(from).sendValue(payments[id].amount);
            currentEthBalance -= payments[id].amount;
        } else {
            require(
                currentTokenBalance >= payments[id].amount,
                "Not enough tokens"
            );
            token.safeTransfer(from, payments[id].amount);
            currentTokenBalance -= payments[id].amount;
        }
    }

    function getDomainHash() internal view returns (bytes32) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return
            keccak256(
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
    }
}
