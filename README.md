# Cross Chain Rebase Token with CCIP

1. Protocol that allows a user to deposit into a vault and in return, recieve rebase tokens that represent their underlying balance

2. Rebase Token -> alanceOf function is dynamic to show the changing balance with time.
   - Balance increases linearly with time
   - Mint tokens to users everytime they perform an action like minting, burning, transfering or bridging
3. Interest Rate
   - Individually set interest rate for user based on some global interest rate of protocol at the time the user deposits into the vault
   - This global interest rate can only incentivise/ reward early adopters.
   - Will increase token adoption
