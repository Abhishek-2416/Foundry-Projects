
# Chainlink FundMe Deployment & Cast Cheatsheet

This cheatsheet summarizes how to deploy a smart contract using Foundry with Chainlink Price Feeds on Sepolia Testnet, and how to interact with it using `cast`.

---

## 🔧 Setup

### 1. `.env` File
Create a `.env` file in your root directory:

```env
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_KEY
PRIVATE_KEY=0xYOUR_PRIVATE_KEY
```

---

## 🛠️ `foundry.toml` Configuration

```toml
rpc_endpoints = { sepolia = "${SEPOLIA_RPC_URL}" }

[profile.default.env]
SEPOLIA_RPC_URL = "${SEPOLIA_RPC_URL}"
PRIVATE_KEY = "${PRIVATE_KEY}"
```

---

## 📜 Deployment Script (`script/DeployFundMe.s.sol`)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {FundMe} from "../src/FundMe.sol";

contract DeployFundMe is Script {
    function run() external {
        // Load RPC and private key from .env
        string memory rpcURL = vm.envString("SEPOLIA_RPC_URL");
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        // Optional: Create fork for simulation
        vm.createSelectFork(rpcURL);

        // Broadcast transaction
        vm.startBroadcast(privateKey);
        address priceFeed = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43; // BTC/USD Price Feed on Sepolia
        new FundMe(priceFeed);
        vm.stopBroadcast();
    }
}
```

---

## 🚀 Deployment Command

```bash
forge script script/DeployFundMe.s.sol --broadcast
```

This uses the `.env` and `foundry.toml` to automatically get your RPC and key.

---

## 🔍 Interact with Deployed Contract

### Contract Address Example:
`0xe1F488984160bb3e90E0543f5Eb623c050fae94A`

### ABI Function:
```solidity
getPrice() returns (uint256)
```

### Cast Call:

```bash
cast call 0xe1F488984160bb3e90E0543f5Eb623c050fae94A "getPrice() returns (uint256)" --rpc-url $SEPOLIA_RPC_URL
```

> 🧠 **Note:** Always ensure your `$SEPOLIA_RPC_URL` is available in your shell.

---

## 💡 Decimals Info (BTC/USD Price Feed on Sepolia)

- Output from `getPrice()` might look like: `7955939196000`
- This is `79559.39196000` USD if the feed has 8 decimals.

To convert:

```js
Human-readable = result / 1e8
```

---

## ✅ Summary

| Concept            | Value                          |
|--------------------|---------------------------------|
| Deployment Style   | Clean via `.env` + Foundry      |
| Benefits           | Reusability, Security, DevOps   |
| Tooling            | `forge script`, `cast call`     |

---

Happy Hacking! 🚀
