import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber, Wallet } from "ethers";
import { ethers } from "hardhat";
import { join } from "path";
import { EthBrewDAO } from "../typechain";

describe("EthBrewToken", function () {
    let owner: SignerWithAddress;
    let account1: SignerWithAddress;
    let investor1: SignerWithAddress;
    let investor2: SignerWithAddress;
    let investor3: SignerWithAddress;
    let daoOperationalAccount: Wallet;

    let brewDAO: EthBrewDAO;
    let numTokens: number;
    let maxTokensPerInvestor: number;
    let initialTokenPrice: BigNumber;

    beforeEach("deploy contract", async () => {
        [owner, account1, investor1, investor2, investor3] = await ethers.getSigners();
        daoOperationalAccount = await ethers.Wallet.createRandom();

        initialTokenPrice = ethers.utils.parseEther(".0001");
        maxTokensPerInvestor = 1000;
        numTokens = 100000;
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
            expect(ownerBalance.toNumber()).to.equal(numTokens);
        });
    });

    describe("transfer tokens", function () {
        it("should transfer specified tokens to the other account and affirm the balance", async function () {
            await brewDAO.connect(owner).transfer(investor1.address, 100);
            const tokenHolderCount = await brewDAO.numberOfTokenHolders();
            const investorTokenCount = await brewDAO.balanceOf(investor1.address);
            const tokenHolderArray = await brewDAO.tokenHolders();

            expect(tokenHolderCount).to.equal(2);
            expect(investorTokenCount).to.equal(100);
            expect(tokenHolderArray.length).to.equal(2);
        });
    });

    describe("initial token sale", function () {
        it("should allow buy tokens to an investor after the deployment and add the investor to the list of dao owners.", async function () {
            await brewDAO.connect(investor1).buyOnInitialOffering({ value: ethers.utils.parseEther("0.1") });

            let investorTokenCount = await brewDAO.balanceOf(investor1.address);
            let tokenHolderCount = await brewDAO.numberOfTokenHolders();

            expect(investorTokenCount.toNumber()).to.equal(1000);
            expect(tokenHolderCount.toNumber()).to.equal(2);
        });

        it("should not allow to buy tokens over allowed limit.", async function () {
            let transaction = brewDAO.connect(investor1).buyOnInitialOffering({ value: ethers.utils.parseEther("3") });

            await expect(transaction).to.be.revertedWith("Purchase limit exceeds allowable token balance per holder");
        });
    });
});
