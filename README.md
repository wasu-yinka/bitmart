# BitMart – Decentralized Bitcoin Commerce Protocol

**Author:** Senior Stacks/Clarity Developer
**Protocol Version:** 1.0
**Language:** [Clarity](https://docs.stacks.co/docs/write-smart-contracts/clarity-overview)
**Blockchain:** [Stacks](https://stacks.co/) (Layer 2 for Bitcoin)
**License:** MIT

---

## 🧾 Overview

**BitMart** is a decentralized, peer-to-peer Bitcoin-native commerce protocol built on the Stacks Layer 2 blockchain. It enables merchants to list products and auctions with **native BTC settlement**, leveraging the **security of Bitcoin’s proof-of-work** and the **smart contract capabilities of Clarity**. BitMart is designed to minimize trust dependencies through **automated escrow**, **brand verification**, **reputation systems**, and **transparent settlement mechanics**, all without intermediaries.

---

## 📌 Key Features

* **Bitcoin-Native Settlement** via Stacks Layer 2
* **Direct Sales and Auctions** with built-in payment and bidding logic
* **Reputation-Based Brand Verification** and merchant registration
* **Customer Review System** with ratings and on-chain reviews
* **Platform Fee Mechanics** with customizable fee rates
* **Immutable, Transparent Commerce** powered by Bitcoin and Stacks

---

## 🧱 System Architecture

```
                    ┌─────────────────────────────┐
                    │        Users (Wallets)       │
                    └────────────┬────────────────┘
                                 │
        ┌────────────────────────▼────────────────────────┐
        │                BitMart Smart Contract           │
        │  (Written in Clarity, deployed on Stacks L2)    │
        └────────────┬──────────────┬─────────────┬───────┘
                     │              │             │
              ┌──────▼──────┐ ┌─────▼─────┐ ┌──────▼─────┐
              │ Brand Mgmt  │ │ Product    │ │ Auction    │
              │ & Verification│ │ Listings   │ │ Mechanics  │
              └─────────────┘ └────────────┘ └────────────┘
                     │              │             │
              ┌──────▼──────┐ ┌─────▼─────┐ ┌──────▼─────┐
              │ Reviews     │ │ Payments   │ │ Platform   │
              │ & Ratings   │ │ & Escrow   │ │ Fee System │
              └─────────────┘ └────────────┘ └────────────┘
```

---

## 🔍 Contract Overview

### ✅ Brand Management

Merchants must register a brand to list products. Brand records include:

* Name
* Verification status (owner-controlled)
* Registration block height

**Public Functions:**

* `register-brand`
* `verify-brand` *(only contract owner)*

---

### 🛍️ Product Listings

Merchants can list products for:

* **Direct Sale** – fixed price in sats
* **Auction** – with reserve price and dynamic bidding

**Public Functions:**

* `list-product` – fixed-price listings
* `create-auction` – auction-based listings
* `buy-product` – direct purchase with BTC settlement

---

### 🔨 Auction System

Products listed as auctions allow:

* Time-limited bidding
* Refunds to outbid participants
* BTC-native escrow & settlement

**Auction Parameters:**

* Reserve price
* Expiry block height
* Current top bid
* Leading bidder (optional)

**Public Functions:**

* `submit-bid`
* `finalize-auction`

---

### 🌟 Reviews & Ratings

Buyers can leave reviews with star ratings (1–5) and a comment. Each review is uniquely tied to:

* Product ID
* Customer address

**Public Function:**

* `submit-review`

---

### ⚖️ Platform Fee System

The platform deducts a **fee in basis points (bps)** on all transactions (default: 250 = 2.5%).

**Public Functions:**

* `update-platform-fee` *(owner only)*

**Read-Only:**

* `get-platform-fee`

---

## 🧬 Contract Architecture

| Component          | Data Structure                                           | Description                  |
| ------------------ | -------------------------------------------------------- | ---------------------------- |
| `brands`           | `principal → {name, is-verified, registration-block}`    | Merchant registry            |
| `products`         | `uint → {merchant, title, description, price-sats, ...}` | Product catalog              |
| `auctions`         | `uint → {expiry-block, reserve-price, ...}`              | Auction tracking             |
| `reviews`          | `{product-id, customer} → {rating, comment, block}`      | Product reviews              |
| `platform-fee-bps` | Global variable                                          | Platform fee in basis points |
| `product-counter`  | Global counter                                           | Tracks total products listed |

---

## 🔄 Data Flow Overview (Example: Auction Process)

1. **Merchant creates auction** using `create-auction`.
2. **Buyers bid** using `submit-bid`. Funds are escrowed via `stx-transfer?`.
3. On new bids, **previous bidder is refunded**.
4. Once the auction expires:

   * **Merchant calls `finalize-auction`**
   * Funds are split between platform and merchant.
   * Product is marked sold.

---

## 🛡️ Security & Safety

* **Role Enforcement:** Only contract owner can verify brands or update fees.
* **Escrow Logic:** All funds are securely managed via `stx-transfer?`.
* **Input Validation:** String checks, numeric ranges, and structural guards.
* **Safe Bid Refunds:** Previous bids are returned before accepting new ones.

---

## 📚 Read-Only Queries

| Function             | Description                |
| -------------------- | -------------------------- |
| `get-product-info`   | Get product metadata       |
| `get-brand-info`     | Get brand data             |
| `get-auction-info`   | Get auction status         |
| `get-product-review` | Get a specific review      |
| `get-product-count`  | Total products listed      |
| `get-platform-fee`   | Current platform fee (bps) |

---

## ⚙️ Deployment Considerations

* **Stacks Network:** Optimized for mainnet but compatible with testnet
* **Contract Owner:** Use a multisig for increased security
* **Wallet Compatibility:** Compatible with Hiro Wallet and any Clarity-compliant wallet

---

## 🔐 Permissions & Governance

| Action                  | Permission Required          |
| ----------------------- | ---------------------------- |
| `verify-brand`          | Contract Owner only          |
| `update-platform-fee`   | Contract Owner only          |
| Product/Auction Listing | Registered Merchants         |
| Review Submission       | Any user                     |
| Bidding & Purchasing    | Any user with sufficient STX |

---

## 📄 License

This smart contract is released under the **MIT License**.
Feel free to use, audit, and extend it.

---

## 🧠 Final Notes

**BitMart** provides a foundational commerce layer for Bitcoin-native applications by enabling programmable commerce over Bitcoin via Stacks. It is **modular**, **trust-minimized**, and **designed for extensibility**, allowing future upgrades such as NFT integration, dispute resolution, or advanced escrow mechanisms.

> *Bitcoin is hard money. BitMart makes it programmable.*
