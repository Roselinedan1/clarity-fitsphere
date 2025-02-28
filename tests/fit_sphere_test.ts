[Previous imports remain the same]

Clarinet.test({
  name: "Cannot join group twice",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('fit_sphere', 'create-group', [
        types.ascii("Test Group")
      ], deployer.address),
      
      Tx.contractCall('fit_sphere', 'join-group', [
        types.uint(1)
      ], user1.address),
      
      Tx.contractCall('fit_sphere', 'join-group', [
        types.uint(1)
      ], user1.address)
    ]);
    
    block.receipts[1].result.expectOk();
    block.receipts[2].result.expectErr(106); // err-already-member
  },
});

Clarinet.test({
  name: "Non-member cannot log activity",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('fit_sphere', 'create-group', [
        types.ascii("Test Group")
      ], deployer.address),
      
      Tx.contractCall('fit_sphere', 'create-competition', [
        types.uint(1),
        types.ascii("Test Competition"),
        types.uint(100),
        types.uint(1000),
        types.none()
      ], deployer.address),
      
      Tx.contractCall('fit_sphere', 'log-activity', [
        types.uint(1),
        types.ascii("running"),
        types.uint(5000)
      ], user1.address)
    ]);
    
    block.receipts[2].result.expectErr(107); // err-not-member
  },
});

[Previous tests remain the same]
