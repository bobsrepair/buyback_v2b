# Buyback contract v2b

This repository contains contract for BobsRepair Buyback program, version 2 variant b.

## Buyback program rules
* To participate in buyback program you need to deposit you BOB tokens to your balance on Buyback contract. 
* All token holders, deposited their tokens to Buyback contract, receive some portion of buyback.
* Portion of buyback ETH you receive is proportional to amount of BOB tokens on your account inside Buyback contract and the time passed from your deposits to current round.
* If you want to withdraw tokens from deposit, only the rest amount is counted, and time of deposit is not changed.
* If you want to add more tokens to a deposit, it is counted as a new deposit with it's own deposit time. Desired sell price is common for all deposits.
