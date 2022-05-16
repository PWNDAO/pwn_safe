require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");
require("hardhat-docgen");
require("dotenv").config();

module.exports = {
  solidity: {
    version: "0.8.9",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      outputSelection: {
        "*": {
          "*": ["storageLayout"]
        }
      }
    },
  },
  networks: {
    rinkeby: {
      url: process.env.RINKEBY_URL || "",
      accounts:
        process.env.DEPLOY_PRIVATE_KEY_TESTNET !== undefined
          ? [process.env.DEPLOY_PRIVATE_KEY_TESTNET]
          : [],
    }
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  docgen: {
    path: './docs',
    clear: true,
    runOnCompile: true,
    except: ["^contracts/test/", "^contracts/openzeppelin/"],
  }
};
