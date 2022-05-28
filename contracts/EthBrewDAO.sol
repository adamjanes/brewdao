// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EthBrewDAO is ERC20, Ownable {

    struct MappingUint {
        bool exists;
        uint value;
    }
    address[] private _holders;
    // contains addresses indexes in _holders array for optimized lookup
    mapping(address => MappingUint) private _holderIndexes;

    uint public tokenPrice;
    bool private primaryTokenSaleWindow;
    uint private maxTokenLimitPerHolder;
    bool private autoPayDividends;
    uint private minAmountRequiredToPayDividend;

    //this is the address that keeps the balance of dividends and operational cashflows into the brew dao. The primary contract address is only used for the initial fund raise for the tokens
    //This will keep operational account seperate from the fund raising account.
    address payable private operationalWalletAddress;

    event BrewDAOMemberAdded(address indexed memberAddress);
    event BrewTokenTransferred(address indexed to, uint amount);

    /**
        * @dev owner will start off with all tokens.
        * Max token supply 100,000 = shares of the brewery.
        * Tokens will be transferred manually to investors after launch.
    */
    constructor(uint numTokens, address payable _operationalWalletAddress, uint _initialTokenPrice, uint _maxTokenLimitPerHolder) ERC20("Brew DAO", "BREW") payable {
        ERC20._mint(msg.sender, numTokens);
        primaryTokenSaleWindow = true;
        operationalWalletAddress = _operationalWalletAddress;
        maxTokenLimitPerHolder = _maxTokenLimitPerHolder;
        tokenPrice = _initialTokenPrice;
    }

    /**
        * @dev owner will deposit profits into the contract once per month.
    */
    function deposit(uint divEligibleTokenCount, address  [] calldata dividendEligibleTokenHolders) external payable onlyOwner returns (bool){
        (bool success,) = operationalWalletAddress.call{value : msg.value}("");
        if (autoPayDividends == true) {
            payDividends(divEligibleTokenCount, dividendEligibleTokenHolders);
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


    /**
        * @dev owner can trigger a withdrawal to all contract addresses.
        * Function will split the amount between all accounts which have an
        * address with > 10 tokens.
        * Alternative - could use PaymentSplitter from OpenZeppelin?
        * https://docs.openzeppelin.com/contracts/2.x/api/payment#PaymentSplitter
    */
    function payDividends(uint _divEligibleTokenCount, address  [] calldata dividendEligibleTokenHolders) onlyOwner canPayDividend public {
        uint divPerEligibleToken = operationalWalletAddress.balance / _divEligibleTokenCount;
        uint eligibleTokenHoldersLength = dividendEligibleTokenHolders.length;
        for (uint i = 0; i < eligibleTokenHoldersLength; i++) {
            (bool success,) = dividendEligibleTokenHolders[i].call{value : balanceOf(dividendEligibleTokenHolders[i]) * divPerEligibleToken}("");
            if (success == false) {
                revert("Error during dividend payouts");
            }
        }
    }

    /**
    @dev any one other than the owner can buy tokens when the initial sale window is open.
    */
    function buyOnInitialOffering() external payable tokenSaleWindowOpen returns (bool) {
        uint numTokensToTransfer = msg.value / tokenPrice;
        _transfer(owner(), msg.sender, numTokensToTransfer);
        return true;
    }

    function _beforeTokenTransfer(address, address to, uint256 amount) internal view override {
        //check if a particular transfer is allowed. Either amount exceeds the number of tokens an address is allowed to hold
        if (to != owner()) {
            uint currentBalance = balanceOf(to);
            if (currentBalance + amount > maxTokenLimitPerHolder) {
                revert("Purchase limit exceeds allowable token balance per holder");
            }
        }
    }

    /**
    * @dev after token transfer => update list/mapping of addresses with
        * > 10 tokens which can receive dividends.
    */
    function _afterTokenTransfer(address from, address to, uint256 amount)
    internal virtual override {
        if (balanceOf(to) == amount && !_holderIndexes[to].exists) {
            _holders.push(to);
            _holderIndexes[to] = MappingUint(true, _holders.length - 1);
        }

        if (balanceOf(from) == 0 && _holderIndexes[from].exists) {
            uint index = _holderIndexes[from].value;
            _holders[index] = _holders[_holders.length - 1];
            _holders.pop();
            delete _holderIndexes[from];
        }

        if (from != owner()) {
            emit BrewDAOMemberAdded(to);
            emit BrewTokenTransferred(to, amount);
        }
    }

    function isPrimarySaleWindowOpen() external view returns (bool){
        return primaryTokenSaleWindow;
    }

    /*
    * @dev check the number of token holders in this dao any time. Used for unit testing for assertions that after token transfer is called.
    */
    function numberOfTokenHolders() external view returns (uint){
        return _holders.length;
    }

    function tokenHolders() external view returns (address [] memory) {
        return _holders;
    }

    modifier tokenSaleWindowOpen() {
        require(primaryTokenSaleWindow == true, "Token Sale Window is closed");
        _;
    }

    modifier canPayDividend(){
        require(operationalWalletAddress.balance >= minAmountRequiredToPayDividend, "Not enough balance to pay dividends");
        _;
    }

}
