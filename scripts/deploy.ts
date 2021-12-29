import { ContractFactory } from "ethers";
import hre from "hardhat";

async function main() {
  const [deployer] = await hre.ethers.getSigners();


  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const Shine = await hre.ethers.getContractFactory("Shine");

  let shine = await hre.upgrades.deployProxy(Shine as ContractFactory, {kind: 'uups'})


  console.log("Shine address:", shine.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });