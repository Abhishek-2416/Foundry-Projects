# Cross Chain Rebase Token

1. A protocol that allows users to deposit their tokens into a vault and in return, receives the rebase tokens that represent their underlying value
2. We are creating a Rebase Token -> where the balanceOf function is dynamic to show the changing balance with time
    - Balance Increases lineraly with time
    - mint token to our users everytime they perform an action (minting, burning, transferring,or .. bridging)
3. Intrest rate 
    - We are going to set an intrest rate for each user based on some global interest rates of the protocol at the time user deposits into the vault
    - This global intrests rate can only decrease with time as to incentivise/reward the early adopters
    - Increase token adoption