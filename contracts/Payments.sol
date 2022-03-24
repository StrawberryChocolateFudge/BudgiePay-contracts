//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
struct Payment {
    uint256 id;
    address from;
    bytes32 fromTwitterId;
    bytes32 toTwitterId;
    uint256 amount;
    bool claimed;
    bool refunded;
    bool initialized;
}

contract Payments is ReentrancyGuard {
    using Address for address payable;
    using SafeMath for uint256;
    address private signer;
    address private owner;
    // paymentId => Payment
    mapping(uint256 => Payment) private payments;
    uint256 private paymentIndex;

    // fromTwitterId hash => paymentIndex[]
    mapping(bytes32 => uint256[]) private fromPayments;
    // toTwitterId hash => paymentIndex[]
    mapping(bytes32 => uint256[]) private toPayments;

    uint256 private totalEthBalance;
    uint256 private currentEthBalance;
    uint256 private constant FEEBASE = 10000;
    uint256 private constant FEE = 20;
    event Pay(uint256 paymentId);
    event Withdraw(uint256 paymentId);
    event Refund(uint256 paymentId);

    constructor(address signerAddress) {
        signer = signerAddress;
        owner = msg.sender;
    }

    function setSigner(address to) external {
        require(msg.sender == owner, "Only the owner can call this");
        signer = to;
    }

    function verifyPaymentSignature(
        uint8 v,
        bytes32 r,
        bytes32 s,
        address from,
        string calldata fromTwitterId,
        string calldata toTwitterId,
        uint256 amount
    ) public view returns (address) {
        bytes32 domain = getDomainHash();
        bytes32 hashStruct = keccak256(
            abi.encode(
                keccak256(
                    "doc(address from,string fromTwitterId,string toTwitterId,uint256 amount)"
                ),
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
        createPayment(from, fromTwitterId, toTwitterId, amount);
        emit Pay(paymentIndex);
    }

    function createPayment(
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

        // The contract must have enough balance, this should never throw
        require(currentEthBalance >= payments[id].amount, "Not enough balance");
        (uint256 _amount, uint256 _fee) = calculateFee(payments[id].amount);
        payable(from).sendValue(_amount);
        payable(signer).sendValue(_fee);
        currentEthBalance -= payments[id].amount;
        emit Withdraw(paymentIndex);
    }

    function refund(
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint256 id,
        string calldata fromTwitterId,
        address from
    ) external nonReentrant {
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

        require(currentEthBalance >= payments[id].amount, "Not Enough Blance");
        (uint256 _amount, uint256 _fee) = calculateFee(payments[id].amount);
        payable(from).sendValue(_amount);
        payable(signer).sendValue(_fee);
        currentEthBalance -= payments[id].amount;
        emit Refund(paymentIndex);
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
                    keccak256(bytes("BudgiePay")),
                    keccak256(bytes("1")),
                    chainId,
                    address(this)
                )
            );
    }

    function calculateFee(uint256 amount)
        public
        pure
        returns (uint256, uint256)
    {
        uint256 fee = (amount.mul(FEE)).div(FEEBASE);
        return (amount.sub(fee), fee);
    }

    function getPaymentIdsFrom(string calldata fromTwitterId)
        external
        view
        returns (uint256[] memory)
    {
        return fromPayments[keccak256(bytes(fromTwitterId))];
    }

    function getPaymentIdsTo(string calldata toTwitterId)
        external
        view
        returns (uint256[] memory)
    {
        return toPayments[keccak256(bytes(toTwitterId))];
    }

    function getPaymentById(uint256 id) external view returns (Payment memory) {
        return payments[id];
    }

    function getLastPaymentId() external view returns (uint256) {
        return paymentIndex;
    }

    function getTotalAndCurrentBalance()
        external
        view
        returns (uint256, uint256)
    {
        return (totalEthBalance, currentEthBalance);
    }

    function getPaymentsPaginated(
        uint256 first,
        uint256 second,
        uint256 third,
        uint256 fourth,
        uint256 fifth
    )
        external
        view
        returns (
            Payment memory,
            Payment memory,
            Payment memory,
            Payment memory,
            Payment memory
        )
    {
        return (
            payments[first],
            payments[second],
            payments[third],
            payments[fourth],
            payments[fifth]
        );
    }
}
