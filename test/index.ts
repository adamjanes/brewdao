import { expect } from "chai";
import { ethers } from "hardhat";

describe("BrewToken", function () {
  let owner;
  let account1;
  let brewDAO;
  let numTokens;

  beforeEach("deploy contract", async () => {
    const accounts = await ethers.getSigners();

    owner = accounts[0];
    account1 = accounts[1];
    numTokens = 10000;

    const BrewDAO = await ethers.getContractFactory("BrewDAO");
    brewDAO = await BrewDAO.deploy(numTokens);
    await brewDAO.deployed();
  });

 // TODO: doesn't work - can an ERC-20 contract be payable?
  describe("deposit", function () {
    it("should increment contract ETH balance", async function () {
      brewDAO.connect(account1).deposit({ from: account1.address, value: 20 });
      expect(brewDAO.balance === 20);
    });
  });



  
});
