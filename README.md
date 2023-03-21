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
| Whitelist | 0xE48CC858F320e97548D25F41114D1A58242A5712 | [Goerli](https://goerli.etherscan.io/address/0xE48CC858F320e97548D25F41114D1A58242A5712)
| FallbackHandler | 0x381476bb7C4E479F6c11Ba58439E7B100FA2797d | [Goerli](https://goerli.etherscan.io/address/0x381476bb7C4E479F6c11Ba58439E7B100FA2797d)
| AssetTransferRights | 0x7b38e76958b715852e7731fB40C7b92241817242 | [Goerli](https://goerli.etherscan.io/address/0x7b38e76958b715852e7731fB40C7b92241817242)
| AssetTransferRightsGuard (proxy) | 0x21B208C59464Be99589E7c5C693f64c053092f02 | [Goerli](https://goerli.etherscan.io/address/0x21B208C59464Be99589E7c5C693f64c053092f02)
| PWNSafeFactory | 0x5639eF6ee606B5F6785453f286c65C0367C2186b | [Goerli](https://goerli.etherscan.io/address/0x5639eF6ee606B5F6785453f286c65C0367C2186b)

### Mumbai
| Name | Address | Link |
| --- | --- | --- |
| Whitelist | 0x1b3aB253454f4776F127DB1Ef27b3f90AafFC073 | [Mumbai](https://mumbai.polygonscan.com/address/0x1b3aB253454f4776F127DB1Ef27b3f90AafFC073)
| FallbackHandler | 0x71052758a5Ed56b4142812f6b3C08d2C9e3Fb7AE | [Mumbai](https://mumbai.polygonscan.com/address/0x71052758a5Ed56b4142812f6b3C08d2C9e3Fb7AE)
| AssetTransferRights | 0x399d1523Cd1345e4b78de8D2325fe6603FB86115 | [Mumbai](https://mumbai.polygonscan.com/address/0x399d1523Cd1345e4b78de8D2325fe6603FB86115)
| AssetTransferRightsGuard (proxy) | 0x79A215C5a0b920664855dA2a5ba3fCab55460585 | [Mumbai](https://mumbai.polygonscan.com/address/0x79A215C5a0b920664855dA2a5ba3fCab55460585)
| PWNSafeFactory | 0xA6445748844deB2e24b9051050d08E4d1141AFA9 | [Mumbai](https://mumbai.polygonscan.com/address/0xA6445748844deB2e24b9051050d08E4d1141AFA9)
