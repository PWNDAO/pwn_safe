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

### Goerli
| Name | Address | Link |
| --- | --- | --- |
| AssetTransferRights | 0xE7e2556C63eC17A2B750c0a2Eb1d6DB2dE06DA89 | [Goerli](https://goerli.etherscan.io/address/0xE7e2556C63eC17A2B750c0a2Eb1d6DB2dE06DA89)
| AssetTransferRightsGuard | 0x257058924Ba6B39Dd14E7560d3107993bbF4518D | [Goerli](https://goerli.etherscan.io/address/0x257058924Ba6B39Dd14E7560d3107993bbF4518D)
| AssetTransferRightsGuardProxy | 0xaa80041E74Ae36078C29A68751097CEbf9E322F8 | [Goerli](https://goerli.etherscan.io/address/0xaa80041E74Ae36078C29A68751097CEbf9E322F8)
| OperatorsContext | 0x90A9E0D74558d57D06Ce5ccA1Af07D9B9c53e0E8 | [Goerli](https://goerli.etherscan.io/address/0x90A9E0D74558d57D06Ce5ccA1Af07D9B9c53e0E8)
| PWNSafeFactory | 0xAC69CDDE099348c979E3C14A2E754df08Ba7cecd | [Goerli](https://goerli.etherscan.io/address/0xAC69CDDE099348c979E3C14A2E754df08Ba7cecd)

### Mumbai
| Name | Address | Link |
| --- | --- | --- |
| AssetTransferRights | 0xe52405604bF644349f57b36Ca6E85cf095faB8dA | [Mumbai](https://mumbai.polygonscan.io/address/0xe52405604bF644349f57b36Ca6E85cf095faB8dA)
| AssetTransferRightsGuard | 0x0172F9cB25F04D780EBD49bD53A9f8589F75Fbee | [Mumbai](https://mumbai.polygonscan.com/address/0x0172F9cB25F04D780EBD49bD53A9f8589F75Fbee)
| AssetTransferRightsGuardProxy | 0x8Bc6496A07A602ae3daaBBB0B3Ba2F2597dE5164 | [Mumbai](https://mumbai.polygonscan.io/address/0x8Bc6496A07A602ae3daaBBB0B3Ba2F2597dE5164)
| OperatorsContext | 0x8D5c942981F1B6A44629970E04CB9C54093E9550 | [Mumbai](https://mumbai.polygonscan.io/address/0x8D5c942981F1B6A44629970E04CB9C54093E9550)
| PWNSafeFactory | 0xc67fa1A6394373490aF953Fa955171E87F6dCA7D | [Mumbai](https://mumbai.polygonscan.io/address/0xc67fa1A6394373490aF953Fa955171E87F6dCA7D)
