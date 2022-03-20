import { keccak256, ecsign } from "ethereumjs-util";
import abi from "ethereumjs-abi";
export function signAirdrop(
  twitterId: string,
  followers: number,
  authorizedAddress: string,
  chainId: number,
  tokenaddress: string,
  privatekey: string
) {
  const eip712DomainHash = getDomainHash(tokenaddress, chainId);

  const structTypeHash = keccak256(
    Buffer.from(
      "doc(string twitterId,uint256 followers,address authorizedAddress)"
    )
  );
  const twitterIdHash = keccak256(Buffer.from(twitterId));
  const followersHash = keccak256(abi.rawEncode(["uint256"], [followers]));
  const authorizedAddressHash = keccak256(
    abi.rawEncode(["address"], [authorizedAddress])
  );
  const hashStruct = keccak256(
    abi.rawEncode(
      ["bytes32", "bytes32", "bytes32", "bytes32"],
      [structTypeHash, twitterIdHash, followersHash, authorizedAddressHash]
    )
  );

  return concatHashAndSign(eip712DomainHash, hashStruct, privatekey);
}

function concatHashAndSign(
  eip712DomainHash: any,
  hashStruct: any,
  privatekey: any
) {
  const concatedHash = keccak256(
    Buffer.concat([Buffer.from("1901", "hex"), eip712DomainHash, hashStruct])
  );
  const privateKeyBuff = Buffer.from(privatekey.split("0x")[1], "hex");

  const sig = ecsign(concatedHash, privateKeyBuff);

  return sig;
}

export function signPayment(
  from: string,
  fromTwitterId: string,
  toTwitterId: string,
  amount: string,
  chainId: number,
  paymentContractAddress: string,
  privatekey: string
) {
  const eip712DomainHash = getDomainHash(paymentContractAddress, chainId);
  const structTypeHash = keccak256(
    Buffer.from(
      "doc(address from,string fromTwitterId,string toTwitterId,uint256 amount)"
    )
  );
  const fromHash = keccak256(abi.rawEncode(["address"], [from]));
  const fromTwitterIdHash = keccak256(Buffer.from(fromTwitterId));
  const toTwitterIdHash = keccak256(Buffer.from(toTwitterId));
  const amountHash = keccak256(abi.rawEncode(["uint256"], [amount]));
  const hashStruct = keccak256(
    abi.rawEncode(
      ["bytes32", "bytes32", "bytes32", "bytes32", "bytes32"],
      [structTypeHash, fromHash, fromTwitterIdHash, toTwitterIdHash, amountHash]
    )
  );
  return concatHashAndSign(eip712DomainHash, hashStruct, privatekey);
}

export function signWithdraw(
  id: string,
  toTwitterId: string,
  from: string,
  chainId: number,
  paymentContractAddress: string,
  privatekey: string
) {
  const eip712DomainHash = getDomainHash(paymentContractAddress, chainId);
  const structTypeHash = keccak256(
    Buffer.from("doc(uint256 id,string toTwitterId,address from)")
  );
  const idHash = keccak256(abi.rawEncode(["uint256"], [id]));
  const toTwitterIdHash = keccak256(Buffer.from(toTwitterId));
  const fromHash = keccak256(abi.rawEncode(["address"], [from]));
  const hashStruct = keccak256(
    abi.rawEncode(
      ["bytes32", "bytes32", "bytes32", "bytes32"],
      [structTypeHash, idHash, toTwitterIdHash, fromHash]
    )
  );

  return concatHashAndSign(eip712DomainHash, hashStruct, privatekey);
}

export function signRefund(
  id: string,
  fromTwitterId: string,
  from: string,
  chainId: number,
  paymentContractAddress: string,
  privatekey: string
) {
  const eip712DomainHash = getDomainHash(paymentContractAddress, chainId);
  const structTypeHash = keccak256(
    Buffer.from("doc(uint256 id,string fromTwitterId,address from)")
  );
  const idHash = keccak256(abi.rawEncode(["uint256"], [id]));
  const fromTwitterHash = keccak256(Buffer.from(fromTwitterId));
  const fromHash = keccak256(abi.rawEncode(["address"], [from]));
  const hashStruct = keccak256(
    abi.rawEncode(
      ["bytes32", "bytes32", "bytes32", "bytes32"],
      [structTypeHash, idHash, fromTwitterHash, fromHash]
    )
  );

  return concatHashAndSign(eip712DomainHash, hashStruct, privatekey);
}
function getDomainHash(address: any, chainId: any) {
  const domainTypeHash = keccak256(
    Buffer.from(
      "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    )
  );
  const nameHash = keccak256(Buffer.from("BudgiePay"));
  const versionHash = keccak256(Buffer.from("1"));

  return keccak256(
    abi.rawEncode(
      ["bytes32", "bytes32", "bytes32", "uint256", "address"],
      [domainTypeHash, nameHash, versionHash, chainId, address]
    )
  );
}
