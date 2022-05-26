// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
pragma solidity ^0.8.0;

contract EthBrewDAO is ERC20, Ownable {

    address[] private holders;

    /**
        * @dev owner will start off with all tokens.
        * Max token supply 100,000 = shares of the brewery.
        * Tokens will be transferred manually to investors after launch.
    */
    constructor(uint numTokens) ERC20("Brew DAO", "BREW") payable {
        ERC20._mint(msg.sender, numTokens);
    }
    /**
        * @dev owner will deposit profits into the contract once per month.
    */
    function deposit() external payable {}


    /**
        * @dev owner can trigger a withdrawal to all contract addresses.
        * Function will split the amount between all accounts which have an
        * address with > 10 tokens.
        * Alternative - could use PaymentSplitter from OpenZeppelin?
        * https://docs.openzeppelin.com/contracts/2.x/api/payment#PaymentSplitter
    */
    function payDividends() external onlyOwner {


    }


    /**
    * @dev after token transfer => update list/mapping of addresses with
        * > 10 tokens which can receive dividends.
    */
    function _afterTokenTransfer(address from, address to, uint256 amount)
    internal virtual override {
        holders.push(to);
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

}
