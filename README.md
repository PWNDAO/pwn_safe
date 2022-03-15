# PWN Wallet

Prototype of new contract wallet with ability to tokenize assets transfer rights (TR token). Without transfer rights, wallet owner cannot transfer wrapped asset.

TR token can be used as a collateral in DeFi protocols as it doesn't make a difference from using the asset itself:
1) borrower cannot move the asset while loan is in progress
2) in case of default, lender can claim TR token and transfer the asset to his wallet even though he is not the wallet owner

If using TR token as a collateral instead of an asset, owner of the asset is still the contract wallet which has several interesting consequences:
1) wallet is still the owner of the token so in case of games, it can still be productive asset
2) all airdrops related to the asset will be collected by the wallet

## Potential issues

This prototype currently supports just ERC721 tokens, but can be extended for any other ERC standard.

Assumption for the wallet to work is, that wallet owner cannot grant approval to any other address while asset is locker. In case the locked asset has some non-standard way how to transfer it / approve it to other address, the wallet cannot provide assurance to the "lender", that the asset is really locked even though TR token is minted.

This leads to the biggest trade-off. Wallet cannot have tokenized transfer rights to some collection and at the same time provide approval for all assets in that collection (`setApproveForAll`) to any address (usually protocol which uses `transferFrom` to transfer assets to its vault).

## Rinkeby
ATR contract: `0xDBdb041842407c109F65b23eA86D99c1E0D94522`
Wallet factory: `0xff9f68c2eD6aD97399f1e7304735D62C3da65d6B`
