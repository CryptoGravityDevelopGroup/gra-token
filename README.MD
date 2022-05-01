- Solidity 0.8.13
- Truffle 
- OpenZeppelin 4.6.0
---  
## 使用发币合约
- 发币合约部署 & 验证   
   `truffle run verify GRA@{adders} --network ropsten --debug `

## 锁仓方式一：使用TokenTimeVesting合约步骤
1. 锁仓合约部署 & 验证   
   `truffle run verify TokenTimeVesting@{adders} --network ropsten --debug`
2. 如有认购，发币地址Approve锁仓合约额度 `1000000000000000000`
3. token owner地址写锁仓合约，新增一条锁仓记录
4. 到期后 锁仓合约受益人自行提取

## 锁仓方式二：使用GRAVestingWallet合约步骤  
1. 发币合约部署 & 验证   
   `truffle run verify GRA@{adders} --network ropsten --debug `
2. 锁仓合约部署 & 验证  
   `truffle run verify GRAVestingWallet@{adders} --network ropsten --debug`
3. 如有认购，token owner地址approve & 转账到锁仓合约固定数额
4. 到期后 锁仓合约受益人自行提取