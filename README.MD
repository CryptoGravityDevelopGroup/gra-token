- Solidity 0.8.13
- Truffle 
- OpenZeppelin
--- 

1. 发币合约  
`truffle run verify GRA@0xE3CeA92f11801cd617e851cB41607dD4d299E707 --network ropsten --debug `
2. 锁仓合约  
   `truffle run verify TokenTimeVesting@0x724285E6B4e57a9F59ED4136930bA7FD053b1746 --network ropsten --debug`
3. 发币地址Approve锁仓合约额度 `1000000000000000000`
4. 如有认购，往锁仓合约新增一条锁仓记录