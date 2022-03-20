import { expect } from "chai";
import { ethers } from "hardhat";
// eslint-disable-next-line node/no-missing-import
import { signPayment, signRefund, signWithdraw } from "../sign";

// This is the #1 hardhat private key
const signerPrivatekey =
  "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d";
const signerPubkey = "0x70997970c51812dc3a010c7d01b50e0d17dc79c8";

const chainId = 31337;

describe("Payments", function () {
  it("Create a payment and withdraw it.", async function () {
    // eslint-disable-next-line no-unused-vars
    const [_, signer2, signer3] = await ethers.getSigners();
    const ThePayments = await ethers.getContractFactory("Payments");
    const payments = await ThePayments.deploy(signerPubkey);

    await payments.deployed();

    console.log("Payments are deployed to:", payments.address);

    const fromTwitterId = "12121212";
    const toTwitterId = "9999999";
    const amount = ethers.utils.parseEther("10");
    expect(await payments.getLastPaymentId()).to.equal(0);
    const sign = await signPayment(
      signer2.address,
      fromTwitterId,
      toTwitterId,
      amount.toString(),
      chainId,
      payments.address,
      signerPrivatekey
    );
    console.log("                       \n");
    const overrides = { value: amount };
    await payments
      .connect(signer2)
      .payEth(
        sign.v,
        sign.r,
        sign.s,
        signer2.address,
        fromTwitterId,
        toTwitterId,
        amount,
        overrides
      );

    expect(await payments.getLastPaymentId()).to.equal(1);

    expect(
      await (
        await payments.getPaymentIdsFrom(fromTwitterId)
      ).length
    ).equal(1);
    expect(await (await payments.getPaymentIdsTo(toTwitterId)).length).equal(1);

    const [totalBalance, currentBanace] =
      await payments.getTotalAndCurrentBalance();
    expect(totalBalance).to.equal(ethers.utils.parseEther("10"));
    expect(currentBanace).to.equal(ethers.utils.parseEther("10"));

    // signing the withdraw

    const withdrawSig = await signWithdraw(
      "1",
      toTwitterId,
      signer3.address,
      chainId,
      payments.address,
      signerPrivatekey
    );
    let weibalance = await signer3.getBalance();
    let balance = ethers.utils.formatEther(weibalance);
    expect(balance).to.equal("9999.999762044839885952");
    await payments
      .connect(signer3)
      .withdraw(
        withdrawSig.v,
        withdrawSig.r,
        withdrawSig.s,
        "1",
        toTwitterId,
        signer3.address
      );
    weibalance = await signer3.getBalance();
    balance = ethers.utils.formatEther(weibalance);
    expect(balance).to.equal("10009.999691643371670292");

    // Try to do the refund, should throw

    const refundSignature = await signRefund(
      "1",
      fromTwitterId,
      signer3.address,
      chainId,
      payments.address,
      signerPrivatekey
    );
    let hasError = false;
    try {
      await payments
        .connect(signer3)
        .refund(
          refundSignature.v,
          refundSignature.r,
          refundSignature.s,
          "1",
          fromTwitterId,
          signer3.address
        );
    } catch (err) {
      // already claimed error
      hasError = true;
    }
    expect(hasError).to.equal(true);
  });
  it("Create a payment and refund it.", async function () {
    // eslint-disable-next-line no-unused-vars
    const [signer1, signer2, signer3] = await ethers.getSigners();
    const ThePayments = await ethers.getContractFactory("Payments");
    const payments = await ThePayments.deploy(signerPubkey);

    await payments.deployed();

    console.log("Payments are deployed to:", payments.address);

    const fromTwitterId = "12121212";
    const toTwitterId = "9999999";
    const amount = ethers.utils.parseEther("10");
    expect(await payments.getLastPaymentId()).to.equal(0);
    const sign = await signPayment(
      signer2.address,
      fromTwitterId,
      toTwitterId,
      amount.toString(),
      chainId,
      payments.address,
      signerPrivatekey
    );
    console.log("                       \n");
    const overrides = { value: amount };
    await payments
      .connect(signer2)
      .payEth(
        sign.v,
        sign.r,
        sign.s,
        signer2.address,
        fromTwitterId,
        toTwitterId,
        amount,
        overrides
      );

    // REFUND IT

    const sig = signRefund(
      "1",
      fromTwitterId,
      signer2.address,
      chainId,
      payments.address,
      signerPrivatekey
    );

    await payments
      .connect(signer2)
      .refund(sig.v, sig.r, sig.s, "1", fromTwitterId, signer2.address);

    const payment = await payments.getPaymentById("1");
    expect(payment.refunded).equal(true);
  });
});
