import hre, {ethers, network} from "hardhat"
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

const ONE_MINUTE = 60 * 60;

const timeTravelOneMinute = async function (){
  const blockNumAfter = await ethers.provider.getBlockNumber();
  const blockAfter = await ethers.provider.getBlock(blockNumAfter);
  const oneMinuteTimestamp = blockAfter.timestamp + ONE_MINUTE;
  await network.provider.send("evm_setNextBlockTimestamp", [oneMinuteTimestamp]);
}

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
    it("has a single fee variable of 2", async function(){
      expect(await shine.feePercentage()).to.equal(2);
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

  it("Has balances persist after upgrade", async function(){
     // arrange
     const shine = await hre.upgrades.deployProxy(Shine as ContractFactory, {kind: 'uups'});
     const [owner, address1, address2] = await hre.ethers.getSigners();
     const airdropAmount = 10000000;
     const airdropAccounts = [address1.address, address2.address]
     const daysLocked = 90;

     // act
     await shine.airdrop(airdropAccounts, airdropAmount, daysLocked);
     const shine2 = await hre.upgrades.upgradeProxy(shine, ShineV2);
     // upgrades via proxy to shineV2
     expect(await shine2.version() === "v1.0.1");
     expect(await shine2.balanceOf(address1.address)).to.equal(airdropAmount);
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
    const daysLocked = 90;


    await shine.airdrop(airdropAddresses, airdropAmount, daysLocked);

    expect(await shine.balanceOf(address1.address)).to.equal(airdropAmount);
    expect(await shine.balanceOf(address2.address)).to.equal(airdropAmount);
  })
  it("timelocks airdropped wallets", async function(){
    const [owner, address1, address2] = await hre.ethers.getSigners();

    const airdropAmount = 10000000;
    const airdropAddresses = [address1.address, address2.address]
    const daysLocked = 90;

    await shine.airdrop(airdropAddresses, airdropAmount, daysLocked);
    const thirdPartySignedShine = shine.connect(address1);

    await timeTravelOneMinute()

    await expect(thirdPartySignedShine.transfer(address2.address, 10000000)).to.be.revertedWith("Is timelocked address")
  })
  it("unlocks airdropped wallets after 3 months when set to 90 days", async function(){
    const [owner, address1, address2, address3] = await hre.ethers.getSigners();

    const airdropAmount = 10000000;
    const airdropAddresses = [address1.address, address2.address]

    await shine.airdrop(airdropAddresses, airdropAmount, 90);

    // set up time travel logic
    const ninetyDays = 90 * 24 * 60 * 60;
    const blockNumAfter = await ethers.provider.getBlockNumber();
    const blockAfter = await ethers.provider.getBlock(blockNumAfter);
    const ninetyDaysFromNow = blockAfter.timestamp + ninetyDays;

    // time travel
    await network.provider.send("evm_setNextBlockTimestamp", [ninetyDaysFromNow + 1]);

    const thirdPartySignedShine = await shine.connect(address1);

    // make transfer right after 3 months
    await expect(() => thirdPartySignedShine.transfer(address3.address, 10000000))
      .to.changeTokenBalance(shine, address3, 9200000); // reduced amount accounts for transfer tax

  })
  it("unlocks airdropped wallets after 4 months when set to 120 days", async function(){
    const [owner, address1, address2, address3] = await hre.ethers.getSigners();

    const airdropAmount = 10000000;
    const airdropAddresses = [address1.address, address2.address]

    await shine.airdrop(airdropAddresses, airdropAmount, 120);

    // set up time travel logic
    const OneTwentyDays = 120 * 24 * 60 * 60; //120 days
    const blockNumAfter = await ethers.provider.getBlockNumber();
    const blockAfter = await ethers.provider.getBlock(blockNumAfter);
    const OneTwentyDaysFromNow = blockAfter.timestamp + OneTwentyDays;

    // time travel
    await network.provider.send("evm_setNextBlockTimestamp", [OneTwentyDaysFromNow + 1]);

    const thirdPartySignedShine = await shine.connect(address1);

    // make transfer right after 3 months
    await expect(() => thirdPartySignedShine.transfer(address3.address, 10000000))
      .to.changeTokenBalance(shine, address3, 9200000); // reduced amount accounts for transfer tax

  })
  it("unlocks airdropped wallets after 5 months when set to 150 days", async function(){
    const [owner, address1, address2, address3] = await hre.ethers.getSigners();

    const airdropAmount = 10000000;
    const airdropAddresses = [address1.address, address2.address]

    await shine.airdrop(airdropAddresses, airdropAmount, 150);

    // set up time travel logic
    const OneFiftyDays = 150 * 24 * 60 * 60; //150 days
    const blockNumAfter = await ethers.provider.getBlockNumber();
    const blockAfter = await ethers.provider.getBlock(blockNumAfter);
    const OneFiftyDaysFromNow = blockAfter.timestamp + OneFiftyDays;

    // time travel
    await network.provider.send("evm_setNextBlockTimestamp", [OneFiftyDaysFromNow + 1]);

    const thirdPartySignedShine = await shine.connect(address1);

    // make transfer right after 3 months
    await expect(() => thirdPartySignedShine.transfer(address3.address, 10000000))
      .to.changeTokenBalance(shine, address3, 9200000); // reduced amount accounts for transfer tax

  })
})

describe("An instance with set wallets", () => {
  let shine: Contract;

  before(async function(){
    shine = await hre.upgrades.deployProxy(Shine as ContractFactory, {kind: 'uups'})
  })

  it("initializes wallets", async function(){
    const [, charity, team, liquidity] = await hre.ethers.getSigners();

    it("sets up the charity wallet", async function(){
      await shine.setCharityWallet(charity);
      expect(await shine.charityWallet() === charity)
    })

    it("sets up the team wallet", async function(){
      await shine.setMarketingWallet(team);
      expect(await shine.marketingWallet() === team)
    })
    it("sets up the liquidity wallet", async function(){
      await shine.setLiquidityWallet(liquidity);
      expect(await shine.marketingWallet() === liquidity)
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

      await timeTravelOneMinute()

      await expect(() => shine.transfer(thirdPartyRecipient.address, 10000000))
        .to.changeTokenBalance(shine, thirdPartyRecipient, 10000000);
    })
    it("does not tax a transfer from a fee-exempt wallet to a fee-exempt wallet",async function(){
      const [owner, charity, team, thirdPartySender, thirdPartyRecipient] = await hre.ethers.getSigners();

      await timeTravelOneMinute()

      await shine.transfer(charity.address, 10000000);
      expect(await shine.balanceOf(charity.address)).to.equal(10000000)
    })
    describe("a transfer from a normal wallet to a normal wallet", async function(){
      // TODO: refactor to a beforeEach?

      it("Transfers 92% to the recipient", async function(){
        const [owner, charity, team, thirdPartySender, thirdPartyRecipient] = await hre.ethers.getSigners();
        await shine.setCharityWallet(charity.address);
        await shine.setMarketingWallet(team.address);

        await timeTravelOneMinute()

        await shine.transfer(thirdPartySender.address, 10000000);

        let thirdPartySignedShine = await shine.connect(thirdPartySender);

        await thirdPartySignedShine.transfer(thirdPartyRecipient.address, 10000000)

        // await thirdPartySender.sendTransaction({Recipient: shine.address})
  
        // TODO: make transfer come from correct address
        expect(await shine.balanceOf(thirdPartyRecipient.address)).to.equal(10000000 * .92)
      })
      it("the charity wallet has 2% of the transfer", async function(){
        const [owner, charity, team, liquidity, thirdPartySender, thirdPartyRecipient] = await hre.ethers.getSigners();
        await shine.setCharityWallet(charity.address);
        await shine.setMarketingWallet(team.address);
        await shine.setLiquidityWallet(liquidity.address);

        await timeTravelOneMinute()

        await shine.transfer(thirdPartySender.address, 10000000);

        let thirdPartySignedShine = await shine.connect(thirdPartySender);

        await thirdPartySignedShine.transfer(thirdPartyRecipient.address, 10000000)

        expect(await shine.balanceOf(charity.address)).to.equal(10000000 * .02)
      })
      it("the marketing wallet has 2% of the transfer", async function() {
        const [owner, charity, team, liquidity, thirdPartySender, thirdPartyRecipient] = await hre.ethers.getSigners();
        await shine.setCharityWallet(charity.address);
        await shine.setMarketingWallet(team.address);
        await shine.setLiquidityWallet(liquidity.address);

        await timeTravelOneMinute()

        await shine.transfer(thirdPartySender.address, 10000000);

        let thirdPartySignedShine = await shine.connect(thirdPartySender);

        await thirdPartySignedShine.transfer(thirdPartyRecipient.address, 10000000)
        expect(await shine.balanceOf(team.address)).to.equal(10000000 * .02)
      })
      it("the liquidity wallet has 2% of the transfer", async function() {
        const [owner, charity, team, liquidity, thirdPartySender, thirdPartyRecipient] = await hre.ethers.getSigners();
        await shine.setCharityWallet(charity.address);
        await shine.setMarketingWallet(team.address);
        await shine.setLiquidityWallet(liquidity.address);

        await timeTravelOneMinute()

        await shine.transfer(thirdPartySender.address, 10000000);

        let thirdPartySignedShine = await shine.connect(thirdPartySender);

        await thirdPartySignedShine.transfer(thirdPartyRecipient.address, 10000000)
        expect(await shine.balanceOf(liquidity.address)).to.equal(10000000 * .02)
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
    })
  })
})

describe("bot behavior", () => {
  let shine: Contract;

  beforeEach(async function(){
    shine = await hre.upgrades.deployProxy(Shine as ContractFactory, {kind: 'uups'})
  });

  it("blocks an immediate transfer by a non-owner", async function(){
    const [owner, bot, account1, account2, address3] = await hre.ethers.getSigners();

    await shine.transfer(bot.address, 1000000);

    const botSignedShine = await shine.connect(bot);
    
    await expect(botSignedShine.transfer(account1.address, 1000000))
      .to.be.revertedWith("You are blacklisted");

  })
})