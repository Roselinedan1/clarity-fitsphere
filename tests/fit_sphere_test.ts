import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Can create a new fitness group",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('fit_sphere', 'create-group', [
        types.ascii("Fitness Warriors")
      ], deployer.address)
    ]);
    
    block.receipts[0].result.expectOk().expectUint(1);
    
    let getGroup = chain.callReadOnlyFn(
      'fit_sphere',
      'get-group',
      [types.uint(1)],
      deployer.address
    );
    
    let group = getGroup.result.expectSome().expectTuple();
    assertEquals(group['name'], "Fitness Warriors");
  },
});

Clarinet.test({
  name: "Can create competition with token rewards",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const tokenContract = accounts.get('token')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('fit_sphere', 'create-group', [
        types.ascii("Active Group")
      ], deployer.address),
      
      Tx.contractCall('fit_sphere', 'create-competition', [
        types.uint(1),
        types.ascii("Token Challenge"),
        types.uint(100),
        types.uint(1000),
        types.some(tokenContract.address)
      ], deployer.address)
    ]);
    
    block.receipts[0].result.expectOk();
    block.receipts[1].result.expectOk();
    
    let getCompetition = chain.callReadOnlyFn(
      'fit_sphere',
      'get-competition',
      [types.uint(1)],
      deployer.address
    );
    
    let competition = getCompetition.result.expectSome().expectTuple();
    assertEquals(competition['token-address'].some, tokenContract.address);
  },
});

Clarinet.test({
  name: "Can track points and update leaderboard",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('fit_sphere', 'create-group', [
        types.ascii("Point Test Group")
      ], deployer.address),
      
      Tx.contractCall('fit_sphere', 'create-competition', [
        types.uint(1),
        types.ascii("Points Challenge"),
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
    
    block.receipts[2].result.expectOk();
    
    let getPoints = chain.callReadOnlyFn(
      'fit_sphere',
      'get-user-points',
      [types.principal(user1.address)],
      deployer.address
    );
    
    let points = getPoints.result.expectSome().expectTuple();
    assertEquals(points['points'], types.uint(10000));
  },
});
