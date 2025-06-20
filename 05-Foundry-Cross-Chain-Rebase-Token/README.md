# Cross Chain Rebase Token

1. A protocol that allows users to deposit their tokens into a vault and in return, receives the rebase tokens that represent their underlying value
2. We are creating a Rebase Token -> where the balanceOf function is dynamic to show the changing balance with time
    - Balance Increases lineraly with time
    - mint token to our users everytime they perform an action (minting, burning, transferring,or .. bridging)
3. Intrest rate 
    - We are going to set an intrest rate for each user based on some global interest rates of the protocol at the time user deposits into the vault
    - This global intrests rate can only decrease with time as to incentivise/reward the early adopters
    - Increase token adoption

# Vulnerabilities 🚨

1. In the transfer and transferFrom functions if you are sending the recepient are not old user of the protocol then they inherit the interest rate of the sending wallet
- The bug comes in when someone does a very small deposit really early on in the protocol and their Intrests rate is high too 
- Then if a second account comes in much later say when the interest rate is 2% and deposits huge amount
- Transfers it to the first user then the first user will retain their old interest rate with a high balance too ‼️

2. Interest Calculation
- If someone keeps spamming the burn/transfer the interest calculation get too much over and over so, it would go from simpleInterest calculations to compounding interest calculations


