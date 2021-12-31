import hre, {ethers} from "hardhat"
import {expect} from "chai";
import assert from "assert"
import { ContractFactory, Contract } from "@ethersproject/contracts";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

let Shine: ContractFactory;
let ShineV2: ContractFactory;

before ("get factories", async function () {
  Shine = await hre.ethers.getContractFactory("Shine");
  ShineV2 = await hre.ethers.getContractFactory("ShineV2");
})

describe("state at deployment", () => {
  // arrange
  let shine: Contract;
  before(async function(){
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

  describe("the fee structure", () => {
    it("has a charity fee of 3", async function(){
      expect(await shine.charityFee()).to.equal(3);
    })
    it("has a redistribution fee of 2", async function(){
      expect(await shine.redistributionFee()).to.equal(2);
    })
    it("has a team fee of 2", async function(){
      expect(await shine.marketingFee()).to.equal(2);
    })
  })

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
  before(async function(){
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

describe("An instance with set wallets", () => {
  let shine: Contract;

  before(async function(){
    shine = await hre.upgrades.deployProxy(Shine as ContractFactory, {kind: 'uups'})
  })

  it("initializes wallets", async function(){
    const [, charity, team] = await hre.ethers.getSigners();

    it("sets up the charity wallet", async function(){
      await shine.setCharityWallet(charity);
      expect(await shine.charityWallet() === charity)
    })

    it("sets up the team wallet", async function(){
      await shine.setMarketingWallet(team);
      expect(await shine.marketingWallet() === team)
    })
  })
})
// 
// test setting wallets
// test exempt transaction
// test non-exempt transaction

describe("transfer behavior", async function(){
  let shine: Contract;

  beforeEach(async function(){
    shine = await hre.upgrades.deployProxy(Shine as ContractFactory, {kind: 'uups'})
  })



    it("does not tax a transfer from a fee-exempt wallet to a normal wallet",async function(){
      const [owner, charity, team, thirdPartySender, thirdPartyRecipient] = await hre.ethers.getSigners();

      await shine.transfer(thirdPartyRecipient.address, 10000000);
      expect(await shine.balanceOf(thirdPartyRecipient.address)).to.equal(10000000)
    })
    it("does not tax a transfer from a fee-exempt wallet to a fee-exempt wallet",async function(){
      const [owner, charity, team, thirdPartySender, thirdPartyRecipient] = await hre.ethers.getSigners();

      await shine.transfer(charity.address, 10000000);
      expect(await shine.balanceOf(charity.address)).to.equal(10000000)
    })
    describe("a transfer from a normal wallet to a normal wallet", async function(){
      // TODO: refactor to a beforeEach?

      it("Transfers 93% to the recipient", async function(){
        const [owner, charity, team, thirdPartySender, thirdPartyRecipient] = await hre.ethers.getSigners();
        await shine.setCharityWallet(charity.address);
        await shine.setMarketingWallet(team.address);

        await shine.transfer(thirdPartySender.address, 10000000);

        let thirdPartySignedShine = await shine.connect(thirdPartySender);

        await thirdPartySignedShine.transfer(thirdPartyRecipient.address, 10000000)

        // await thirdPartySender.sendTransaction({Recipient: shine.address})
  
        // TODO: make transfer come from correct address
        expect(await shine.balanceOf(thirdPartyRecipient.address)).to.equal(10000000 * .93)
      })
      it("the charity wallet has 3% of the transfer", async function(){
        const [owner, charity, team, thirdPartySender, thirdPartyRecipient] = await hre.ethers.getSigners();
        await shine.setCharityWallet(charity.address);
        await shine.setMarketingWallet(team.address);

        await shine.transfer(thirdPartySender.address, 10000000);

        let thirdPartySignedShine = await shine.connect(thirdPartySender);

        await thirdPartySignedShine.transfer(thirdPartyRecipient.address, 10000000)

        expect(await shine.balanceOf(charity.address)).to.equal(10000000 * .03)
      })
      it("the team wallet has 2% of the transfer", async function() {
        const [owner, charity, team, thirdPartySender, thirdPartyRecipient] = await hre.ethers.getSigners();
        await shine.setCharityWallet(charity.address);
        await shine.setMarketingWallet(team.address);

        await shine.transfer(thirdPartySender.address, 10000000);

        let thirdPartySignedShine = await shine.connect(thirdPartySender);

        await thirdPartySignedShine.transfer(thirdPartyRecipient.address, 10000000)
        expect(await shine.balanceOf(team.address)).to.equal(10000000 * .02)
      })
    });

  describe("the contract when paused", () => {
    let shine: Contract;

    beforeEach(async function(){
      shine = await hre.upgrades.deployProxy(Shine as ContractFactory, {kind: 'uups'})
    });

    it("The pause event emits when pause() is called by the owner", async function(){
      expect(await shine.pause()).to.emit(shine, "Paused")
    })
    it("emits an unpause event the owner calls unpause()", async function(){
      await shine.pause();
      expect(await shine.unpause()).to.emit(shine, "Unpaused")

    })
    it("does not pause when a non-owner attempts to pause", async function(){
      const [owner, address1] = await hre.ethers.getSigners();
      let nonOwnerSignedShine = await shine.connect(address1);

      await expect(nonOwnerSignedShine.pause())
        .to.be.revertedWith('Ownable: caller is not the owner');
      // expect(nonOwnerSignedShine.pause()).to.not.emit(shine, "Paused")

    })
  })
  
  // const [owner, charity, team, thirdPartySender, thirdPartyRecipient] = await hre.ethers.getSigners();

})