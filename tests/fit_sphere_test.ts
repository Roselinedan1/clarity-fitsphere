Clarinet.test({
  name: "Winner determination handles empty activities correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('fit_sphere', 'determine-winner', [
        types.list([])
      ], deployer.address)
    ]);
    
    block.receipts[0].result.expectErr(105); // err-insufficient-balance
  },
});

[Previous tests remain the same]
