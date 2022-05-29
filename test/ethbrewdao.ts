import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber, Wallet } from "ethers";
import { ethers } from "hardhat";
import { EthBrewDAO } from "../typechain";

describe("EthBrewToken", function () {
    let owner: SignerWithAddress;
    let account1: SignerWithAddress;
    let investor1: SignerWithAddress;
    let investor2: SignerWithAddress;
    let investor3: SignerWithAddress;

    let brewDAO: EthBrewDAO;
    let numTokens: number;
    let maxTokensPerInvestor: number;
    let initialTokenPrice: BigNumber;

    beforeEach("deploy contract", async () => {
        [owner, account1, investor1, investor2, investor3] = await ethers.getSigners();

        initialTokenPrice = ethers.utils.parseEther(".0001");
        maxTokensPerInvestor = 1000;
        numTokens = 100000;
        const EthBrewDAO = await ethers.getContractFactory("EthBrewDAO");
        brewDAO = await EthBrewDAO.deploy(
            numTokens,
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

    describe("after token transfer", function () {
        it("should add address to the list of holders if it received tokens while having no tokens prior", async function () {
            await brewDAO.connect(owner).transfer(investor1.address, 100);
            
            let holders = await brewDAO.tokenHolders();

            expect(holders).to.contain(investor1.address);
        });

        it("should not add address to the list of holders if it received tokens while already having tokens", async function () {
            await brewDAO.connect(owner).transfer(investor1.address, 100);
            await brewDAO.connect(owner).transfer(investor1.address, 100);
            
            let holders = await brewDAO.tokenHolders();

            expect(holders.length).to.equal(2);
        });

        it("should remove address from the list of holders if all tokens were transfered from it", async function () {
            await brewDAO.connect(owner).transfer(investor1.address, 100);
            await brewDAO.connect(investor1).transfer(investor2.address, 100);
            
            let holders = await brewDAO.tokenHolders();

            expect(holders.length).to.equal(2);
            expect(holders).to.not.contain(investor1.address);
        });

        it("should not remove address from the list of holders if only part of the tokens were transfered from it", async function () {
            await brewDAO.connect(owner).transfer(investor1.address, 100);
            await brewDAO.connect(investor1).transfer(investor2.address, 50);
            
            let holders = await brewDAO.tokenHolders();

            expect(holders.length).to.equal(3);
            expect(holders).to.contain(investor1.address);
        });
    });

    describe("deposit", function () {
        it("should track eligible dividends for token holders", async function () {
            await brewDAO.connect(owner).setMaxTokenLimitPerHolder(100000);
            
            await brewDAO.connect(owner).transfer(investor1.address, 20000);
            await brewDAO.connect(owner).transfer(investor2.address, 30000);
            
            await brewDAO.connect(owner).deposit({ value: ethers.utils.parseEther("1") });
            
            const ownerDividends = await brewDAO.eligibleDividends(owner.address);
            const investor1Dividends = await brewDAO.eligibleDividends(investor1.address);
            const investor2Dividends = await brewDAO.eligibleDividends(investor2.address);

            expect(ownerDividends).to.be.equal(ethers.utils.parseEther("0.5"));
            expect(investor1Dividends).to.be.equal(ethers.utils.parseEther("0.2"));
            expect(investor2Dividends).to.be.equal(ethers.utils.parseEther("0.3"));
        });
    });

    describe("claim dividends", function () {
        it("should send dividends to the claimant address", async function () {
            await brewDAO.connect(owner).setMaxTokenLimitPerHolder(100000);
            await brewDAO.connect(owner).transfer(investor1.address, 20000);
            await brewDAO.connect(owner).deposit({ value: ethers.utils.parseEther("1") });
            
            
            const balanceBefore = await investor1.getBalance();
            await brewDAO.connect(investor1).claimDividends();
            const balanceAfter = await investor1.getBalance();
            
            expect(balanceAfter.sub(balanceBefore).gt(ethers.utils.parseEther("0.18"))).to.be.true;
            expect(await brewDAO.eligibleDividends(investor1.address)).to.equal(0);
        });

        it("should revert if claimant is not eligible", async function () {
            await brewDAO.connect(owner).setMaxTokenLimitPerHolder(100000);
            await brewDAO.connect(owner).transfer(investor1.address, 20000);
            await brewDAO.connect(owner).deposit({ value: ethers.utils.parseEther("1") });

            const tx = brewDAO.connect(investor2).claimDividends();

            await expect(tx).to.be.reverted;
        });
    });
});
