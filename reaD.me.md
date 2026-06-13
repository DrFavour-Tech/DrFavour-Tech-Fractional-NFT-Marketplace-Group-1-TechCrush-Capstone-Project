Fractional NFT- Marketplace is a decentralized NFT contract that allows users to style NFT's, Buy/Sell NFT's, and claim NFTs securely on-chain.

OVERVIEW; Fractional NFT Marketplace is a smart contract system that allows users to:
Mint NFTs
Fractionalize NFTs into tradable shares
Buy and sell NFT fractions
Reconstruct full ownership by acquiring all fractions
Trade ownership transparently on-chain
The project is designed for learning, experimentation, and decentralized asset ownership

CORE FEATURES;
NFT Minting
Users can mint NFTs representing digital assets.
Fractional Ownership
NFT owners can split a single NFT into multiple ERC20-like fractions.
Fraction Trading
Users can buy and sell fractions through the marketplace.
Ownership Tracking
The contract tracks fractional holders and ownership percentages.
Full Redemption
A user who owns all fractions can reclaim the original NFT.
Marketplace Listings
Fractional shares can be listed and purchased on-chain.

TECH STACK;
Solidity
Foundry
OpenZeppelin Contracts
Ethereum / Sepolia Testnet

SMART CONTRACTS;
NFTCollection.sol; Mints, & Transfer NFT's, and store metadata url's
Fractiontoken.sol; Mint fractions, Transfer fractions, Burn fractions, Track balances
FractionalNFTMarketplace.sol; Lock NFTs into the marketplace, Fractionalize NFTs, Create listings, Purchase fractions, Redeem complete ownership.

HOW FRACTIONALIZATION WORKS;
Step 1 — Mint NFT; mintNFT("ipfs://metadata-uri");
Step 2 — Deposit NFT
Step 3 — Users Buy Fractions
Step 4 — Redeem NFT

INSTALLATION PREREQUISITES;
Foundry; curl -L https://foundry.paradigm.xyz | bash
foundryup
Clone Repository; git clone <your-repository-url>
cd fractional-nft-marketplace
Install dependencies; forge install
Compile contracts; forge build
Run tests; forge test
Deploy locally(start anvil); anvil
Deploy Contract; forge script script/Deploy.s.sol \
--rpc-url http://127.0.0.1:8545 \
--broadcast

DEPLOYING TO SEPOLIA;
Add environmental variables(create .env); forge script script/Deploy.s.sol \
--rpc-url http://127.0.0.1:8545 \
--broadcast
Deploy; forge script script/Deploy.s.sol \
--rpc-url $SEPOLIA_RPC_URL \
--private-key $PRIVATE_KEY \
--broadcast \
--verify

SECURITY CONSIDERATIONS;
Reentrancy Protection; for marketplace purchases and withdrawals.
Access Control; Restrict administrative functions using: Ownable

VALIDATION CHECKS; Always validate: 
Ownership, 
Fraction supply
Listing prices
Purchase amounts

FUTURE IMPROVEMENTS;
Royalty support
Multi-chain support
Yield generation for NFT holders

TESTING STRATEGY; The project should test:
NFT minting
Fraction creation
Buying fractions
Redeeming NFTs
Reentrancy attacks
Ownership validations

Recommended OpenZeppelin Imports;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

License; MIT

Contributors; Dr.Favour, Charles, Max., Degen.