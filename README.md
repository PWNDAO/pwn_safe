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
| AssetTransferRights | 0xA9d6ADC15054B1b668Ad886159132FCBCCACC280 | [Goerli](https://goerli.etherscan.io/address/0xA9d6ADC15054B1b668Ad886159132FCBCCACC280)
| AssetTransferRightsGuard | 0x4Ee0dD324e7ef1980010947EA172eAc3f6270F0F | [Goerli](https://goerli.etherscan.io/address/0x4Ee0dD324e7ef1980010947EA172eAc3f6270F0F)
| AssetTransferRightsGuardProxy | 0x49ec29913b506dE5aea2F944483FA8868d806fd0 | [Goerli](https://goerli.etherscan.io/address/0x49ec29913b506dE5aea2F944483FA8868d806fd0)
| PWNSafeFactory | 0x83daf9E6204D8A6b60bCc24e531c20457fe1Ccf4 | [Goerli](https://goerli.etherscan.io/address/0x83daf9E6204D8A6b60bCc24e531c20457fe1Ccf4)

### Mumbai
| Name | Address | Link |
| --- | --- | --- |
| Whitelist | 0xd8c27167232A4e744343dfD76027FbB4eD5B2542 | [Mumbai](https://mumbai.polygonscan.com/address/0xd8c27167232A4e744343dfD76027FbB4eD5B2542)
| FallbackHandler | 0x038A7810955fb548e5a38a256cfc6FA702173c13 | [Mumbai](https://mumbai.polygonscan.com/address/0x038A7810955fb548e5a38a256cfc6FA702173c13)
| AssetTransferRights | 0x92Ce756b54d15494141a87b59467c7682B230c0d | [Mumbai](https://mumbai.polygonscan.com/address/0x92Ce756b54d15494141a87b59467c7682B230c0d)
| AssetTransferRightsGuard | 0xF97779f08Fa2f952eFb12F5827Ad95cE26fEF432 | [Mumbai](https://mumbai.polygonscan.com/address/0xF97779f08Fa2f952eFb12F5827Ad95cE26fEF432)
| AssetTransferRightsGuardProxy | 0x2f705615E25D705813cC0E29f4225Db0EDB82eCa | [Mumbai](https://mumbai.polygonscan.com/address/0x2f705615E25D705813cC0E29f4225Db0EDB82eCa)
| PWNSafeFactory | 0x34fCA53BbCbc2a4E2fF5D7F704b7143133dfaCF7 | [Mumbai](https://mumbai.polygonscan.com/address/0x34fCA53BbCbc2a4E2fF5D7F704b7143133dfaCF7)
