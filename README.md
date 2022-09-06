# PWNSafe

Collection of guard and module used on top of gnosis safe multisig contract wallet with ability to tokenize assets transfer rights (ATR token). Without transfer rights, wallet owner cannot transfer tokenized assets.

ATR token can be used as a collateral in DeFi protocols as it doesn't make a difference from using the asset itself:
1) borrower cannot move the asset while loan is in progress
2) in case of default, lender can claim ATR token and transfer the asset to his wallet even though he is not the wallet owner

If using ATR token as a collateral instead of an asset, owner of the asset is still the contract wallet which has several interesting consequences:
1) wallet is still an owner of the token so tokens utility is usable
2) all airdrops related to the asset will be collected by the wallet

Assumption for the wallet to work is, that wallet owner cannot grant approval to other address while asset is has its transfer rights minted. In case where "tokenized" asset has some non-standard way how to transfer it / approve it to other address, the wallet cannot provide assurance to the "lender", that the asset is really locked even though ATR token is minted.
