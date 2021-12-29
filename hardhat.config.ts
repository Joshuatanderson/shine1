import { task } from "hardhat/config";
import "@nomiclabs/hardhat-waffle";
import '@typechain/hardhat';
import '@nomiclabs/hardhat-ethers';
import '@openzeppelin/hardhat-upgrades';
import "hardhat-contract-sizer"

import {CONSTANTS} from "./env";

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.8.2",
  networks: {
    ropsten: {
      url: `https://eth-ropsten.alchemyapi.io/v2/${CONSTANTS.ALCHEMY_API_KEY}`,
      accounts: [`${CONSTANTS.ROPSTEN_PRIVATE_KEY}`]
    }
  }
};