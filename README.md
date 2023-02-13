# PWNSafe

Collection of guard and module used on top of gnosis safe multisig contract wallet with ability to tokenize assets transfer rights (ATR token). Without transfer rights, wallet owner cannot transfer tokenized assets.

ATR token can be used as a collateral in DeFi protocols as it doesn't make a difference from using the asset itself:
1) borrower cannot move the asset while loan is in progress
2) in case of default, lender can claim ATR token and transfer the asset to his wallet even though he is not the wallet owner

If using ATR token as a collateral instead of an asset, owner of the asset is still the contract wallet which has several interesting consequences:
1) wallet is still an owner of the token so tokens utility is usable
2) all airdrops related to the asset will be collected by the wallet

Assumption for the wallet to work is, that wallet owner cannot grant approval to other address while asset is has its transfer rights minted. In case where "tokenized" asset has some non-standard way how to transfer it / approve it to other address, the wallet cannot provide assurance to the "lender", that the asset is really locked even though ATR token is minted.

## Deployed addresses
### Mainnet
TBD

### Polygon
TBD

### Goerli
| Name | Address | Link |
| --- | --- | --- |
| Whitelist | 0x8Ce467a4985B6170F1461A42032ff827c57Aa3C6 | [Goerli](https://goerli.etherscan.io/address/0x8Ce467a4985B6170F1461A42032ff827c57Aa3C6)
| FallbackHandler | 0xd23f1e8d26C35295aBcd17362063bac7999F7Bc5 | [Goerli](https://goerli.etherscan.io/address/0xd23f1e8d26C35295aBcd17362063bac7999F7Bc5)
| AssetTransferRights | 0x9a5869a2E15fDFB92ad5fBB1e1853042bc70768f | [Goerli](https://goerli.etherscan.io/address/0x9a5869a2E15fDFB92ad5fBB1e1853042bc70768f)
| AssetTransferRightsGuard (proxy) | 0x7aab799C02df6181d765015D09c8a93F0052FEdD | [Goerli](https://goerli.etherscan.io/address/0x7aab799C02df6181d765015D09c8a93F0052FEdD)
| PWNSafeFactory | 0xD80FC95381dFca116db921775a1ee0DA99d1fB09 | [Goerli](https://goerli.etherscan.io/address/0xD80FC95381dFca116db921775a1ee0DA99d1fB09)

### Mumbai
| Name | Address | Link |
| --- | --- | --- |
| Whitelist | 0xd8c27167232A4e744343dfD76027FbB4eD5B2542 | [Mumbai](https://mumbai.polygonscan.com/address/0xd8c27167232A4e744343dfD76027FbB4eD5B2542)
| FallbackHandler | 0x038A7810955fb548e5a38a256cfc6FA702173c13 | [Mumbai](https://mumbai.polygonscan.com/address/0x038A7810955fb548e5a38a256cfc6FA702173c13)
| AssetTransferRights | 0xE989a297c033C963B57b513D845a034615C34b2D | [Mumbai](https://mumbai.polygonscan.com/address/0xE989a297c033C963B57b513D845a034615C34b2D)
| AssetTransferRightsGuard (proxy) | 0xe2cb6Bfb0cff0c4B9b24ab605899B1B4F7e13cc9 | [Mumbai](https://mumbai.polygonscan.com/address/0xe2cb6Bfb0cff0c4B9b24ab605899B1B4F7e13cc9)
| PWNSafeFactory | 0x6B5e585C76ABca1AD431613817aA71BE1d025f65 | [Mumbai](https://mumbai.polygonscan.com/address/0x6B5e585C76ABca1AD431613817aA71BE1d025f65)
