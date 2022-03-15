import { expect } from "chai";
import { ethers } from "hardhat";

describe("TheFollowerToken", function () {
  it("Deployment and signatures...", async function () {
    // THE CONTRACT ADDRESS FOR THE FOLLOWER TOKEN (ADDRESS(THIS)) HERE IS : 0x5fbdb2315678afecb367f032d93f642f64180aa3

    const initialSupply = "10000000";
    const maxMinted = "1000000000";
    const TheFollowerToken = await ethers.getContractFactory(
      "TheFollowerToken"
    );
    const thefollowerToken = await TheFollowerToken.deploy(
      ethers.utils.parseEther(initialSupply),
      ethers.utils.parseEther(maxMinted),
      "0x70997970c51812dc3a010c7d01b50e0d17dc79c8"
    );

    await thefollowerToken.deployed();

    console.log("FollowerToken is deployed to:", thefollowerToken.address);

    // wait until the transaction is mined
    const twitterId = "1234567891234";
    const followers = 12;
    const authorizedAddress = "0xDF16399E6F10bbC1C07C88c6c70116182FA2e118";

    const r =
      "0x578298cb3f4f2678387193b5ddc7242f89b879cea2df7961df7e355c37eb392d";
    const s =
      "0x216612e9d005ff9b847abd7e959dc336095c1a95a3eec82ce0b770095ae744b2";
    const v = 27;
    const signerPublicKey = "0x70997970c51812dc3a010c7d01b50e0d17dc79c8";

    const res = await thefollowerToken.verifySignature(
      v,
      r,
      s,
      twitterId,
      followers,
      authorizedAddress
    );
    expect(res.toLowerCase()).to.equal(signerPublicKey.toLowerCase());
  });

  it("Mint token and check balances", async function () {
    // THE CONTRACT ADDRESS FOR THE FOLLOWER TOKEN (ADDRESS(THIS)) HERE IS : 0xe7f1725e7734ce288f8367e1bb143e90bb3f0512

    const [signer1, signer2, signer3] = await ethers.getSigners();
    const initialSupply = "10000000";
    const maxMinted = "1000000000";
    const TheFollowerToken = await ethers.getContractFactory(
      "TheFollowerToken"
    );
    const thefollowerToken = await TheFollowerToken.deploy(
      ethers.utils.parseEther(initialSupply),
      ethers.utils.parseEther(maxMinted),
      "0x70997970c51812dc3a010c7d01b50e0d17dc79c8"
    );
    console.log(signer3.address);
    await thefollowerToken.deployed();

    const r =
      "0x0434ed1179a5688c64c026f54c20115a01a9c5f1074b576a7bca4f23b5337972";
    const s =
      "0x564bfef5f15753f3a5e2b6734c98f9072c909b5c5094b2ee91be32eede59dc53";
    const v = 27;

    const twitterId = "1234567891234";
    const followers = 12;
    const authorizedAddress = "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC";
    console.log(signer3.address);
    const signerPublicKey = "0x70997970c51812dc3a010c7d01b50e0d17dc79c8";
    let errOccured = false;
    console.log("LOGGING THE ERRORS:");
    expect(
      await thefollowerToken.connect(signer3).balanceOf(signer3.address)
    ).to.equal(ethers.utils.parseEther("0"));
    try {
      const res = await thefollowerToken.mintFollowerToken(
        v,
        r,
        s,
        twitterId,
        authorizedAddress,
        followers
      );
    } catch (err: any) {
      // YOU ARE NOT AUTHORIZED ERROR
      console.log(err);
      errOccured = true;
    }

    expect(errOccured).equal(true);

    errOccured = false;

    try {
      await thefollowerToken.mintFollowerToken(
        v,
        r,
        s,
        twitterId,
        signer1.address,
        followers
      );
    } catch (err: any) {
      // INVALID SIGNER ERROR
      console.log(err);
      errOccured = true;
    }

    expect(errOccured).equal(true);

    const res = await thefollowerToken
      .connect(signer3)
      .mintFollowerToken(v, r, s, twitterId, authorizedAddress, followers);

    expect(
      await thefollowerToken.connect(signer3).balanceOf(signer3.address)
    ).to.equal(ethers.utils.parseEther("12"));

    errOccured = false;

    try {
      await thefollowerToken
        .connect(signer3)
        .mintFollowerToken(v, r, s, twitterId, signer1.address, followers);
    } catch (err: any) {
      // The user withdrew the tokens already.
      console.log(err);
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
      const res = await thefollowerToken
        .connect(signer3)
        .mintFollowerToken(
          maxMintedV,
          maxMintedR,
          maxMintedS,
          maxMintedTwittr,
          maxMintedAddress,
          maxMintedFollowers
        );
    } catch (err) {
      console.log(err);
      errOccured = true;
    }
    expect(errOccured).equal(true);
  });
});
