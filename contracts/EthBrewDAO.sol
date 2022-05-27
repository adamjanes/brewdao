// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
pragma solidity ^0.8.0;

contract EthBrewDAO is ERC20, Ownable {

    address[] private holders;
    DivEligibleTokenHolder[] private dividendEligibleTokenHolders;

    struct DivEligibleTokenHolder {
        address tokenHolderAddress;
        uint tokenCount;
    }

    uint private tokenPrice;
    bool private primaryTokenSaleWindow;
    uint private maxTokenLimitPerHolder;
    bool private autoPayDividends;
    uint private dividendEligibleTokenBalance;
    uint private divEligibleTokenCount;

    //this is the address that keeps the balance of dividends and operational cashflows into the brew dao. The primary contract address is only used for the initial fund raise for the tokens
    //This will keep operational account seperate from the fund raising account.
    address payable private operationalWalletAddress;

    /**
        * @dev owner will start off with all tokens.
        * Max token supply 100,000 = shares of the brewery.
        * Tokens will be transferred manually to investors after launch.
    */
    constructor(uint numTokens, address payable _operationalWalletAddress) ERC20("Brew DAO", "BREW") payable {
        ERC20._mint(msg.sender, numTokens);
        primaryTokenSaleWindow = true;
        operationalWalletAddress = _operationalWalletAddress;
    }
    /**
        * @dev owner will deposit profits into the contract once per month.

    */
    function deposit() external payable onlyOwner returns (bool){
        bool success = operationalWalletAddress.call{value : msg.value}("");
        if (autoPayDividends == true) {
            payDividends();
        }
        return success;
    }

    function setTokenPrice(uint _tokenPrice) external onlyOwner {
        tokenPrice = _tokenPrice;
    }

    function closePrimaryTokenSaleWindow() external onlyOwner {
        primaryTokenSaleWindow = false;
    }

    function setMaxTokenLimitPerHolder(uint _maxAllowedTokens) external onlyOwner {
        maxTokenLimitPerHolder = _maxAllowedTokens;
    }

    function setAutoPayDividends(bool _autoPayDividends) external onlyOwner {
        autoPayDividends = _autoPayDividends;
    }

    function setDividendEligibilityTokenBalance(uint _eligibleTokenBalance) external onlyOwner {
        dividendEligibleTokenBalance = _eligibleTokenBalance;
    }


    /**
        * @dev owner can trigger a withdrawal to all contract addresses.
        * Function will split the amount between all accounts which have an
        * address with > 10 tokens.
        * Alternative - could use PaymentSplitter from OpenZeppelin?
        * https://docs.openzeppelin.com/contracts/2.x/api/payment#PaymentSplitter
    */
    function payDividends() onlyOwner public {
        require(operationalWalletAddress.balance > 0, "Not enough balance to pay dividends");
        uint divPerEligibleToken = operationalWalletAddress.balance / divEligibleTokenCount;
        uint eligibleTokenHoldersLength = dividendEligibleTokenHolders.length;
        for (uint i = 0; i < eligibleTokenHoldersLength; i++) {
            DivEligibleTokenHolder memory divPayTokenHolder = dividendEligibleTokenHolders[i];
            bool success = divPayTokenHolder.tokenHolderAddress.call{value : divPayTokenHolder.tokenCount * divPerEligibleToken}("");
            if (success == false) {
                revert("Error during dividend payouts");
            }
        }
    }

    /**
    @dev any one other than the owner can buy tokens when the initial sale window is open.
    */
    function initialTokenSale() payable tokenSaleWindowOpen external returns (bool){
        uint valueSent = msg.value;
        uint numTokensToTrasfer = valueSent / tokenPrice;
        transfer(msg.sender, numTokensToTrasfer);
        return true;

    }


    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        //check if a particular transfer is allowed. Either amount exceeds the number of tokens an address is allowed to hold
        uint currentBalance = balanceOf(to);
        if (currentBalance + amount > maxTokenLimitPerHolder) {
            revert("Purchase limit exceeds allowable token balance per holder");
        }

    }


    /**
    * @dev after token transfer => update list/mapping of addresses with
        * > 10 tokens which can receive dividends.
    */
    function _afterTokenTransfer(address from, address to, uint256 amount)
    internal virtual override {
        holders.push(to);
        uint balance = balanceOf(to);
        if (balance >= dividendEligibleTokenBalance) {
            dividendEligibleTokenHolders[DivEligibleTokenHolder.tokenHolderAddress] = to;
            dividendEligibleTokenHolders[DivEligibleTokenHolder.tokenCount] = balance;
            divEligibleTokenCount += balance;
        }
    }

    /*
    * @dev check the number of token holders in this dao any time. Used for unit testing for assertions that after token transfer is called.
    */
    function numberOfTokenHolders() view external returns (uint){
        return holders.length;
    }

    function tokenHolders() view external returns (address [] memory) {
        return holders;
    }

    modifier tokenSaleWindowOpen() {
        require(primaryTokenSaleWindow == true, "Token Sale Window is closed");
        _;
    }

}
