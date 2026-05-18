# WaqfChain
### Tokenized Islamic Endowment Assets on Arc · Powered by Circle

> *"Waqf is one of Islam's most profound financial innovations — charitable endowments that have funded hospitals, universities, and mosques for over a thousand years. Yet today, billions in Waqf assets sit illiquid, mismanaged, and inaccessible to the people they were meant to serve. WaqfChain changes that."*

---

## The Problem

The global Waqf sector manages an estimated **$1 trillion** in assets — properties, agricultural land, commercial buildings — across the Muslim world. Yet:

- **Fragmented records** make it impossible to verify ownership or track distributions
- **Illiquidity** means beneficiaries wait months or years for yield
- **Opacity** creates opportunities for mismanagement and corruption
- **High remittance costs** eat into cross-border beneficiary payouts
- **No programmable compliance** means Sharia rules are enforced manually and inconsistently

In the UAE alone, the AWQAF (General Authority of Islamic Affairs & Endowments) manages over **600,000 Waqf assets** — most of them on paper.

---

## The Solution: WaqfChain

WaqfChain tokenizes Waqf assets on **Arc** — Circle's purpose-built L1 blockchain — issuing ERC-20 tokens that represent fractional ownership of registered endowment assets. Every token holder receives proportional yield distributions in **USDC**, automatically settled on Arc with sub-second finality and predictable fees.

### Why Arc?

Arc was purpose-built for exactly this use case:

| Arc Feature | WaqfChain Application |
|---|---|
| USDC as native gas | Dollar-denominated fees — no crypto volatility in operations |
| Deterministic finality | Instant beneficiary settlements — no 6-block wait |
| Programmable payment flows | Automated yield distribution with Zakat deduction |
| Circle infrastructure | Circle Wallets for beneficiary key management |
| CCTP | Cross-border USDC for GCC-wide beneficiary base |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    USER INTERFACE LAYER                      │
│  WaqfChain Web App · MetaMask · Circle Wallets SDK           │
└──────────────────────┬──────────────────────────────────────┘
                       │ eth_sendRawTransaction
┌──────────────────────▼──────────────────────────────────────┐
│                  CIRCLE INFRASTRUCTURE                       │
│  USDC · Circle Wallets · Circle Gateway · CCTP + Bridge Kit  │
└──────────────────────┬──────────────────────────────────────┘
                       │ Arc RPC
┌──────────────────────▼──────────────────────────────────────┐
│                    ARC BLOCKCHAIN (L1)                       │
│  WaqfToken.sol · ComplianceRegistry.sol                      │
│  DistributionEngine.sol · WaqfGovernance.sol                 │
└──────────────────────┬──────────────────────────────────────┘
                       │ Events / Indexing
┌──────────────────────▼──────────────────────────────────────┐
│                  DATA & ORACLE LAYER                         │
│  AWQAF Authority Oracle · Event Indexer · IPFS Metadata      │
└─────────────────────────────────────────────────────────────┘
```

See `architecture.html` for the full interactive diagram.

---

## Smart Contracts

| Contract | Purpose |
|---|---|
| `ComplianceRegistry.sol` | Stores KYC, Sharia, and AWQAF status for investors and assets |
| `WaqfToken.sol` | ERC-20 token with transfer restrictions — only KYC-verified holders |
| `DistributionEngine.sol` | Pro-rata USDC yield distribution with automatic Zakat (2.5%) deduction |
| `WaqfGovernance.sol` | 2-of-3 Mutawalli (trustee) multisig for critical governance actions |

---

## Circle Products Used

### USDC
The native settlement currency for all WaqfChain operations. Yield distributions to beneficiaries, token purchases, and Arc network fees are all denominated in USDC — eliminating crypto volatility risk for endowment funds.

### Circle Wallets
Beneficiary wallets are managed via Circle Wallets SDK, enabling:
- Programmatic wallet creation for beneficiaries without crypto experience
- KYC status linked directly to wallet
- Secure key management for the Waqf treasury (multi-sig)

### Circle Gateway
Routes outgoing USDC distributions from the treasury to thousands of beneficiary wallets. Handles liquidity and settlement orchestration for multi-party distribution flows.

### CCTP + Bridge Kit
Enables cross-chain USDC movement for the GCC beneficiary base — allowing beneficiaries in Saudi Arabia, Qatar, Kuwait, and Bahrain to receive distributions on their preferred chain while assets remain on Arc.

---

## Compliance & Sharia Framework

WaqfChain implements a layered compliance architecture:

**Sharia Compliance:**
- No interest-bearing components (Riba prohibition)
- All business activities screened against halal criteria
- Profit-sharing structure (Musharakah-compliant)
- Automatic 2.5% Zakat deduction on every distribution
- Sharia fatwa certificate stored on IPFS, hash pinned onchain

**Regulatory Compliance (UAE):**
- AWQAF authority registration number required for tokenization
- KYC/AML via Circle identity layer
- OFAC / UN sanctions screening
- FATF travel rule enforced for transactions > $1,000
- Full onchain audit trail for DIFC/ADGM reporting

**Transfer Restrictions:**
- Only KYC-verified addresses may hold WaqfTokens
- Enforced at the smart contract level — `ComplianceRegistry.sol` consulted on every transfer
- Trustees can pause the token contract via `WaqfGovernance.sol`

---

## Transaction Flow

```
1. Mutawalli registers asset + AWQAF number
        ↓
2. Oracle verifies with AWQAF authority off-chain → writes hash to ComplianceRegistry
        ↓
3. Sharia fatwa uploaded to IPFS → hash pinned to token metadata
        ↓
4. WaqfToken.sol mints ERC-20 tokens on Arc
        ↓
5. Investors purchase tokens (KYC-verified only) with USDC
        ↓
6. Monthly: DistributionEngine calculates pro-rata yield
        ↓
7. 2.5% Zakat deducted → reserved for charity
        ↓
8. Circle Gateway routes USDC to beneficiary wallets
        ↓
9. Cross-border beneficiaries receive via CCTP
```

---

## Setup Instructions

### Prerequisites
- Node.js v18+
- MetaMask with Arc testnet configured
- Circle Developer account (console.circle.com)

### Arc Testnet Network Config
```
Network Name: Arc Testnet
RPC URL:      https://rpc.arc-testnet.circle.com
Chain ID:     [Arc testnet chain ID]
Currency:     USDC
Explorer:     https://explorer.arc-testnet.circle.com
```

### Install & Run
```bash
# Clone repository
git clone https://github.com/[your-username]/waqfchain
cd waqfchain

# Install dependencies
npm install

# Deploy contracts to Arc testnet
npx hardhat run scripts/deploy.js --network arc-testnet

# Start frontend
open index.html
# Or serve locally:
npx serve .
```

### Environment Variables
```env
ARC_RPC_URL=https://rpc.arc-testnet.circle.com
CIRCLE_API_KEY=your_circle_api_key
COMPLIANCE_REGISTRY=0x...   # Deployed contract address
WAQF_TOKEN=0x...            # Deployed contract address  
DISTRIBUTION_ENGINE=0x...   # Deployed contract address
USDC_ARC=0x...              # USDC address on Arc testnet
```

---

## Integration with Circle Tools

### Circle Wallets Integration
```javascript
import { initiateUserControlledWalletsClient } from '@circle-fin/user-controlled-wallets';

const client = initiateUserControlledWalletsClient({
  apiKey: process.env.CIRCLE_API_KEY
});

// Create wallet for new beneficiary
const { data } = await client.createUser({ userId: beneficiaryId });
```

### USDC Distribution via Arc
```javascript
const provider = new ethers.JsonRpcProvider(process.env.ARC_RPC_URL);
const engine = new ethers.Contract(DISTRIBUTION_ENGINE, abi, signer);

// Execute queued distribution
const tx = await engine.executeDistribution(distributionId);
await tx.wait();
console.log(`Distributed to beneficiaries. Tx: ${tx.hash}`);
```

---

## Circle Product Feedback

### What We Chose & Why

**USDC on Arc** was the natural choice for a Waqf platform. Endowment managers need predictability — they cannot have distribution amounts fluctuate with ETH gas prices or token volatility. USDC on Arc gives dollar-denominated operations end to end.

**Circle Wallets** solved our hardest UX problem: most Waqf beneficiaries are not crypto-native. Circle Wallets allows us to create and manage wallets on their behalf programmatically, without requiring them to understand seed phrases.

**Circle Gateway** enabled multi-party treasury management that would have taken significant custom engineering to build otherwise.

### What Worked Well

- The Arc RPC is fast and reliable — our distribution transactions confirmed in under 2 seconds on testnet
- Circle Wallets SDK documentation is comprehensive and the developer experience is smooth
- USDC as gas on Arc is genuinely transformative for financial applications — no mental overhead of converting between tokens

### What Could Be Improved

- The CCTP Bridge Kit documentation for Arc-specific flows could be more detailed — we had to piece together the cross-chain flow from multiple sources
- A testnet faucet dashboard within the Circle developer console would speed up testing significantly
- Circle Wallets could benefit from a built-in compliance/KYC webhook system to reduce the custom oracle infrastructure we had to build

---

## Team

Built for **The Stablecoins Commerce Stack Challenge** hosted by Ignyte, sponsored by Arc (Circle).

*For educational and testnet demonstration purposes only. Not for production use.*

---

*وقف — Endowment for the benefit of humanity*
