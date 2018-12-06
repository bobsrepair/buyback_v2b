# Buyback contract v2b

This repository contains contract for BobsRepair Buyback program, version 2 variant b.

## Buyback program rules
* To participate in the buyback program you will need to deposit your BOB Tokens to the smart contract.
* For every buyback round, a certain amount of BOB Tokens is purchased from the smart contract in exchange for ETH, at a price set by the company.
* The amount of ETH you receive is based on amount of tokens and time held. For the amount of tokens, the amount of ETH you receive is proportional to the amount of BOB tokens you have inside of the Buyback contract in relation with the total amount of BOB Tokens everyone has. For time held, the amount of ETH you receive is also weighted from the time you deposited your BOB Tokens to the time of the current round.
* If you would like to withdraw a portion of your BOB Tokens from the smart contract, your original deposit time for the remainder of the tokens does not change and you do not lose the extra weight of having them in the contract for longer.
* If you want to add more tokens to the smart contract, the addition is counted as a new deposit with it's own deposit time. 
