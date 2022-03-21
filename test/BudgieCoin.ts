import { expect } from "chai";
import { ECDSASignature } from "ethereumjs-util";
import { ethers } from "hardhat";
// eslint-disable-next-line node/no-missing-import
import { signAirdrop } from "../sign";

// This is the #1 hardhat private key
const signerPrivatekey =
  "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d";
const signerPubkey = "0x70997970c51812dc3a010c7d01b50e0d17dc79c8";

const chainId = 31337;

describe("BudgieCoin", function () {
  it("Deployment and signatures...", async function () {
    const initialSupply = "10000000";
    const maxMinted = "1000000000";
    const TheBudgieCoin = await ethers.getContractFactory("BudgieCoin");
    const budgiecoin = await TheBudgieCoin.deploy(
      ethers.utils.parseEther(initialSupply),
      ethers.utils.parseEther(maxMinted),
      signerPubkey
    );

    await budgiecoin.deployed();

    console.log("Budgie Coin is deployed to:", budgiecoin.address);

    // wait until the transaction is mined
    const twitterId = "1234567891234";
    const followers = 12;
    const authorizedAddress = "0xDF16399E6F10bbC1C07C88c6c70116182FA2e118";
    const signerPublicKey = "0x70997970c51812dc3a010c7d01b50e0d17dc79c8";

    const sign = signAirdrop(
      twitterId,
      followers,
      authorizedAddress,
      chainId,
      budgiecoin.address,
      signerPrivatekey
    );
    const ecdsaSign = sign as ECDSASignature;
    const res = await budgiecoin.verifySignature(
      ecdsaSign.v,
      ecdsaSign.r,
      ecdsaSign.s,
      twitterId,
      followers,
      authorizedAddress
    );
    expect(res.toLowerCase()).to.equal(signerPublicKey.toLowerCase());
  });

  it("Mint token and check balances", async function () {
    // THE CONTRACT ADDRESS FOR BUDGIE COIN (ADDRESS(THIS)) HERE IS : 0xe7f1725e7734ce288f8367e1bb143e90bb3f0512

    // eslint-disable-next-line no-unused-vars
    const [signer1, _, signer3] = await ethers.getSigners();

    const initialSupply = "10000000";
    const maxMinted = "1000000000";
    const TheBudgieCoin = await ethers.getContractFactory("BudgieCoin");
    const budgiecoin = await TheBudgieCoin.deploy(
      ethers.utils.parseEther(initialSupply),
      ethers.utils.parseEther(maxMinted),
      signerPubkey
    );
    console.log(signer3.address);
    await budgiecoin.deployed();

    const twitterId = "1234567891234";
    const followers = 12;
    const authorizedAddress = "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC";
    let errOccured = false;

    const sign = signAirdrop(
      twitterId,
      followers,
      authorizedAddress,
      chainId,
      budgiecoin.address,
      signerPrivatekey
    );
    const ecdsaSign = sign as ECDSASignature;

    expect(
      await budgiecoin.connect(signer3).balanceOf(signer3.address)
    ).to.equal(ethers.utils.parseEther("0"));
    try {
      await budgiecoin.mintBudgieCoin(
        ecdsaSign.v,
        ecdsaSign.r,
        ecdsaSign.s,
        twitterId,
        authorizedAddress,
        followers
      );
    } catch (err: any) {
      // YOU ARE NOT AUTHORIZED ERROR
      // console.log(err);
      errOccured = true;
    }

    expect(errOccured).equal(true);

    errOccured = false;

    try {
      await budgiecoin.mintBudgieCoin(
        ecdsaSign.v,
        ecdsaSign.r,
        ecdsaSign.s,
        twitterId,
        signer1.address,
        followers
      );
    } catch (err: any) {
      // INVALID SIGNER ERROR
      // console.log(err);
      errOccured = true;
    }

    expect(errOccured).equal(true);

    await budgiecoin
      .connect(signer3)
      .mintBudgieCoin(
        ecdsaSign.v,
        ecdsaSign.r,
        ecdsaSign.s,
        twitterId,
        authorizedAddress,
        followers
      );

    expect(
      await budgiecoin.connect(signer3).balanceOf(signer3.address)
    ).to.equal(ethers.utils.parseEther("12"));

    errOccured = false;

    try {
      await budgiecoin
        .connect(signer3)
        .mintBudgieCoin(
          ecdsaSign.v,
          ecdsaSign.r,
          ecdsaSign.s,
          twitterId,
          signer1.address,
          followers
        );
    } catch (err: any) {
      // The user withdrew the tokens already.
      // console.log(err);
      errOccured = true;
    }

    expect(errOccured).equal(true);

    const maxMintedR =
      "0x545eb9814e2b430d8472183ad29a25c7efdae831fa026b5854e5de68a497c486";
    const maxMintedS =
      "0x745b840fbb0ecaf353a8ceda5edfd3583b75439ce3bb04b7a9bd891cd404be39";
    const maxMintedV = 28;

    const maxMintedTwittr = "1234567891212121";
    const maxMintedFollowers = "1000000000";
    const maxMintedAddress = "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC";
    errOccured = false;
    try {
      await budgiecoin
        .connect(signer3)
        .mintBudgieCoin(
          maxMintedV,
          maxMintedR,
          maxMintedS,
          maxMintedTwittr,
          maxMintedAddress,
          maxMintedFollowers
        );
    } catch (err) {
      // console.log(err);
      errOccured = true;
    }
    expect(errOccured).equal(true);
  });
});
