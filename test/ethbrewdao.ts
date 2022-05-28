import {expect} from "chai";
import {ethers} from "hardhat";

describe("EthBrewToken", function () {
    let owner;
    let daoOperationalAccount;
    let account1;
    let brewDAO;
    let numTokens;
    let maxTokensPerInvestor;
    let initialTokenPrice;
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
            expect(ownerBalance.toNumber() === numTokens);
        });
    });

    describe("transfer tokens", function () {
        it("should transfer specified  tokens  to the other account and affirm the balance", async function () {
            await brewDAO.connect(owner).transfer(investor1.address, 100);
            const tokenHolderCount = await brewDAO.numberOfTokenHolders();
            const investorTokenCount = await brewDAO.balanceOf(investor1.address);
            const ownerTokenCount = await brewDAO.balanceOf(owner.address);
            const tokenHolderArray = await brewDAO.tokenHolders();
            expect(tokenHolderCount.toNumber() === 100);
            expect(investorTokenCount === 1000);
        });
    });

    describe("initial token sale", function () {
        it("should allow buy tokens to an investor after the deployment and add the investor to the list of dao owners.", async function () {
            await brewDAO.connect(owner);
            const initialTokenHolderCount = await brewDAO.numberOfTokenHolders();
            const ownerBalanceOfTokens = await brewDAO.balanceOf(owner.address);
            const tokenInitialSaleWindow = await brewDAO.isPrimarySaleWindowOpen();
            expect(ownerBalanceOfTokens.toNumber() === numTokens);
            expect(initialTokenHolderCount.toNumber() === 1);
            // investor1 buys tokens on the initial sale offering
            const saleToInvestor = await brewDAO.connect(investor1).buyOnInitialOffering({
                from: investor1.address,
                value: 1
            })
            expect(saleToInvestor === true);
            let investorTokenCount = (await brewDAO.balanceOf(investor1.address)).toNumber();
            let tokenHolderCount=await brewDAO.numberOfTokenHolders();
            console.log("await brewDAO.balanceOf(investor1.address)",investorTokenCount);
            expect(investorTokenCount === 1000);
            expect(tokenHolderCount === 2);

        });
    });
});
