require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

const { API_URL, PRIVATE_KEY } = process.env;

const networks = { hardhat: {} };
if (API_URL) {
  networks.sepolia = {
    url: API_URL,
    accounts: PRIVATE_KEY ? [`0x${PRIVATE_KEY}`] : [],
  };
}

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.27",
    settings: {
      optimizer: {
        enabled: true,
        runs: 500,
      },
      viaIR: true,
    },
  },
  networks,
};
