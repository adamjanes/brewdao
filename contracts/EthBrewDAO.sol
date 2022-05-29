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

    mapping(address => uint) private _eligibleDividends;

    uint public tokenPrice;
    bool private primaryTokenSaleWindow;
    uint private maxTokenLimitPerHolder;

    event BrewDAOMemberAdded(address indexed memberAddress);
    event BrewTokenTransferred(address indexed to, uint amount);

    /**
        * @dev owner will start off with all tokens.
        * Max token supply 100,000 = shares of the brewery.
        * Tokens will be transferred manually to investors after launch.
    */
    constructor(uint numTokens, uint _initialTokenPrice, uint _maxTokenLimitPerHolder) ERC20("Brew DAO", "BREW") payable {
        ERC20._mint(msg.sender, numTokens);
        primaryTokenSaleWindow = true;
        maxTokenLimitPerHolder = _maxTokenLimitPerHolder;
        tokenPrice = _initialTokenPrice;
    }

    /**
        * @dev owner will deposit profits into the contract once per month.
    */
    function deposit() external payable onlyOwner {
        uint divPerToken = msg.value / totalSupply();
        uint holdersCount = _holders.length;

        for (uint i = 0; i < holdersCount; i++) {
            address holder = _holders[i];
            _eligibleDividends[holder] += balanceOf(holder) * divPerToken;
        }
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

    function claimDividends() external {
        address sender = msg.sender;
        
        uint amount = _eligibleDividends[sender];
        require(amount > 0, "No pending dividends");
        
        _eligibleDividends[sender] = 0;
        (bool success, ) = payable(sender).call{ value: amount }("");
        require(success, "Error when sending dividends");
     }

    function eligibleDividends(address account) external view returns (uint) {
        return _eligibleDividends[account];
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
}
