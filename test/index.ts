import hre from "hardhat"
import assert from "assert"
import { ContractFactory } from "@ethersproject/contracts";
import ethers from "ethers"

let Shine: ContractFactory;
let ShineV2: ContractFactory;
before ("get factories", async function () {
  Shine = await hre.ethers.getContractFactory("Shine");
  ShineV2 = await hre.ethers.getContractFactory("ShineV2");
})

describe("deployment", () => {
  // arrange
  // act

  it("Is named Shine", async function(){
    const shine = await hre.upgrades.deployProxy(Shine as ContractFactory, {kind: 'uups'})
    assert(await shine.name() === "Shine");
  })
  it("Has the symbol 'SHINE'", async function() {
    const shine = await hre.upgrades.deployProxy(Shine as ContractFactory, {kind: 'uups'})
    assert(await shine.symbol() === "SHINE");
  })
  it("Has a decimal count of 18", async function(){
    const shine = await hre.upgrades.deployProxy(Shine as ContractFactory, {kind: 'uups'})
    assert(await shine.decimals() === 18)
  })
  it("Has a total supply of ten billion", async function(){
    const shine = await hre.upgrades.deployProxy(Shine as ContractFactory, {kind: 'uups'})
    assert(await shine.totalSupply() / 10 ** 18  === 10000000000)
  });

  // it("The owner has a balance equal to the total supply", async function(){
  //   const shine = await hre.upgrades.deployProxy(this.Shine, {kind: 'uups'})
  //   assert(await shine.totalSupply() === shine)
  // })
})

describe("the upgrade process works correctly", () => {
  it("has a version number of v1.0.0!", async function(){
    // arrange
    const shine = await hre.upgrades.deployProxy(Shine as ContractFactory, {kind: 'uups'})
    // act
    const shine2 = await hre.upgrades.upgradeProxy(shine, ShineV2);
    assert
    // upgrades via proxy to shineV2
    assert(await shine2.version() === "v1.0.0");
  });
})