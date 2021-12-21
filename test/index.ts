import hre, {ethers} from "hardhat"
import {expect} from "chai";
import assert from "assert"
import { ContractFactory, Contract } from "@ethersproject/contracts";

let Shine: ContractFactory;
let ShineV2: ContractFactory;

before ("get factories", async function () {
  Shine = await hre.ethers.getContractFactory("Shine");
  ShineV2 = await hre.ethers.getContractFactory("ShineV2");
})

describe("state at deployment", () => {
  // arrange
  let shine: Contract;
  beforeEach(async function(){
    shine = await hre.upgrades.deployProxy(Shine as ContractFactory, {kind: 'uups'})
  })
  // act

  it("Is named Shine", async function(){
    assert(await shine.name() === "Shine");
  })
  it("Has the symbol 'SHINE'", async function() {
    assert(await shine.symbol() === "SHINE");
  })
  it("Has a decimal count of 18", async function(){
    assert(await shine.decimals() === 18)
  })
  it("Has a total supply of ten billion", async function(){
    assert(await shine.totalSupply() / 10 ** 18  === 10000000000)
  });

  it("The owner has a balance equal to the total supply", async function(){
    const [owner] = await hre.ethers.getSigners();

    expect(await shine.balanceOf(owner.address)).to.equal(await shine.totalSupply());
  })
})

describe("the upgrade process works correctly", () => {
  it("has a version number of v1.0.1!", async function(){
    // arrange
    const shine = await hre.upgrades.deployProxy(Shine as ContractFactory, {kind: 'uups'})
    // act
    const shine2 = await hre.upgrades.upgradeProxy(shine, ShineV2);
    // upgrades via proxy to shineV2
    assert(await shine2.version() === "v1.0.1");
  });
})

describe("An airdrop", () => {
  let shine: Contract;
  beforeEach(async function(){
    shine = await hre.upgrades.deployProxy(Shine as ContractFactory, {kind: 'uups'})
  })
  it("airdrops to multiple wallets successfully", async function(){
    const [owner, address1, address2] = await hre.ethers.getSigners();

    const decimals = ethers.BigNumber.from("10").pow(18);
    const airdropAmount = hre.ethers.BigNumber.from(10000000).mul(decimals);
    const airdropAddresses = [address1.address, address2.address]


    await shine.airdrop(airdropAddresses, airdropAmount);

    expect(await shine.balanceOf(address1.address)).to.equal(airdropAmount);
    expect(await shine.balanceOf(address2.address)).to.equal(airdropAmount);
  })
})
