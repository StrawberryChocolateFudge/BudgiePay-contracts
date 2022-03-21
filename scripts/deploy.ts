// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const initialSupply = "10000000";
  const maxMinted = "1000000000";
  const TheBudgieCoin = await ethers.getContractFactory("BudgieCoin");
  const budgiecoin = await TheBudgieCoin.deploy(
    ethers.utils.parseEther(initialSupply),
    ethers.utils.parseEther(maxMinted),
    "0x70997970c51812dc3a010c7d01b50e0d17dc79c8"
  );

  await budgiecoin.deployed();

  console.log("BudgieCoin is deployed to:", budgiecoin.address);

  const Payments = await ethers.getContractFactory("Payments");
  const payments = await Payments.deploy(
    "0x70997970c51812dc3a010c7d01b50e0d17dc79c8"
  );

  await payments.deployed();

  console.log("Payments have been deployed to: ", payments.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
