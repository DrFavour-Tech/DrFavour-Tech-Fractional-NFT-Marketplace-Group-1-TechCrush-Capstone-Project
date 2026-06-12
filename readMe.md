Fractional NFT- Marketplace is a decentralized NFT contract that allows users to style NFT's, Buy/Sell NFT's, and claim NFTs securely on-chain.
Fractional NFT-Marketplace allows users to; buy/sell NFT's, Transfer NFT's.
Methods & Means include; solidity ^0.8.33;, Foundry, OpenZeppelin Sepolia
src/Fractiontoken.sol, scripts/deploycontracts.s.sol, test/MockER721
Deployment instructions using Foundry includes; forge install, forge build, forge test, forge script script/Deploy.s.sol --rpc-url <RPC_URL> --broadcast --private-key <KEY>

forge test to run tests
Security; Reentrancy protection, access control(only owner)

Network information includes; Anvil(local), Sepolia(Testnet), 
Charles, Favour, Max, Degen
License(MIT)