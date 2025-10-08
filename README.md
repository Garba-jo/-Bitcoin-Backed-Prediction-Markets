# 🎯 Bitcoin-Backed Prediction Markets

A decentralized prediction markets platform built on Stacks, allowing users to stake Bitcoin on market outcomes.

## 🚀 Features

- Create prediction markets with customizable questions
- Stake BTC on YES/NO outcomes
- Oracle-based result settlement
- Automated reward distribution
- Minimum stake requirements

## 📝 Contract Functions

### create-market
Create a new prediction market with a question and duration in blocks.

### stake-yes
Stake BTC on a "YES" outcome for a specific market.

### stake-no  
Stake BTC on a "NO" outcome for a specific market.

### settle-market
Oracle settles market outcome (restricted to oracle address).

### claim-reward
Claim rewards for winning predictions.

## 🔧 Usage

1. Deploy contract using Clarinet
2. Create markets using `create-market`
3. Users stake on outcomes using `stake-yes` or `stake-no`
4. Oracle settles market after end time
5. Winners claim rewards using `claim-reward`

## ⚠️ Requirements

- Clarinet
- Stacks wallet
- Minimum stake amount (100 STX)

## 🔒 Security

- Oracle-controlled settlement
- Market state validation
- Stake amount verification
```

Git commit message:
```
feat: implement Bitcoin-backed prediction markets MVP with staking and oracle settlement
```

PR Title:
```
Add Bitcoin-backed Prediction Markets Smart Contract
```

PR Description:
```
This PR implements a minimal viable product for Bitcoin-backed prediction markets on Stacks:

- Core market creation and staking functionality
- Oracle-based settlement system
- Reward distribution mechanism
- Basic access controls and validation
- Clear documentation and usage instructions

The implementation focuses on essential features while maintaining security and correctness. Ready for initial testing and feedback.