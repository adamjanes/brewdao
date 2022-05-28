import { expect } from "chai";
import { ethers } from "hardhat";

describe("EthBrewToken", function () {
  let owner;
  let daoOperationalAccount;
  let account1;
  let brewDAO;
  let numTokens;
  let maxTokensPerInvestor;
  let initialTokenPrice ;
  let investor1;
  let investor2;
  let investor3;

  beforeEach("deploy contract", async () => {
    const accounts = await ethers.getSigners();

    owner = accounts[0];
    daoOperationalAccount = accounts[1];
    account1 = accounts[2];
    investor1 = accounts[3];
    investor2 = accounts[4];
    investor3 = accounts[5];
    initialTokenPrice = ethers.utils.parseEther(".00001");
    maxTokensPerInvestor = 1000;
    numTokens = 100000;
    console.log("owner", owner.address);
    console.log("investor", investor1.address);
    console.log("account1", account1.address);
    const EthBrewDAO = await ethers.getContractFactory("EthBrewDAO");
    brewDAO = await EthBrewDAO.deploy(
      numTokens,
      daoOperationalAccount.address,
      initialTokenPrice,
      maxTokensPerInvestor
    );
    await brewDAO.deployed();
  });

  describe("DAO instantiated with tokens in owner acccount", function () {
    it("owner address should have all the tokens initially", async function () {
      const ownerBalance = await brewDAO.balanceOf(owner.address);
      console.log("owner balance at start ", ownerBalance.toNumber());
      expect(ownerBalance.toNumber() === numTokens);
    });
  });

  describe("deposit", function () {
    it("should increment contract ETH balance in the eth brew dao token", async function () {
      await brewDAO
        .connect(account1)
        .deposit({ from: account1.address, value: 20 });
      expect(brewDAO.balance === 20);
    });
  });

  describe("transfer tokens", function () {
    it("should transfer specified  tokens  to the other account and affirm the balance", async function () {
      await brewDAO.connect(owner).transfer(investor1.address, 100);
      const tokenHolderCount = await brewDAO.numberOfTokenHolders();
      const investorTokenCount = await brewDAO.balanceOf(investor1.address);
      const ownerTokenCount = await brewDAO.balanceOf(owner.address);
      console.log(
        "brewDAO.numberOfTokenHolders() ",
        tokenHolderCount.toNumber()
      );
      console.log("owner token count ", ownerTokenCount.toNumber());
      console.log("investorTokenCount ", investorTokenCount.toNumber());
      const tokenHolderArray = await brewDAO.tokenHolders();
      tokenHolderArray.forEach((element) => {
        console.log("token holders", element);
      });

      expect(tokenHolderCount.toNumber() === 100);
      expect(investorTokenCount === 1000);
    });
  });
});
