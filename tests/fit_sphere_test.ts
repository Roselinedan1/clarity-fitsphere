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
    
    // Verify group exists
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
  name: "Can create and manage competition",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user1 = accounts.get('wallet_1')!;
    
    // Create group first
    let block = chain.mineBlock([
      Tx.contractCall('fit_sphere', 'create-group', [
        types.ascii("Active Group")
      ], deployer.address),
      
      // Create competition
      Tx.contractCall('fit_sphere', 'create-competition', [
        types.uint(1),
        types.ascii("Summer Challenge"),
        types.uint(100), // duration
        types.uint(1000) // prize
      ], deployer.address),
      
      // Log activity
      Tx.contractCall('fit_sphere', 'log-activity', [
        types.uint(1),
        types.ascii("running"),
        types.uint(5000)
      ], user1.address)
    ]);
    
    block.receipts[0].result.expectOk();
    block.receipts[1].result.expectOk();
    block.receipts[2].result.expectOk();
    
    // Verify competition
    let getCompetition = chain.callReadOnlyFn(
      'fit_sphere',
      'get-competition',
      [types.uint(1)],
      deployer.address
    );
    
    let competition = getCompetition.result.expectSome().expectTuple();
    assertEquals(competition['name'], "Summer Challenge");
  },
});

Clarinet.test({
  name: "Only group admin can end competition",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      // Create group and competition
      Tx.contractCall('fit_sphere', 'create-group', [
        types.ascii("Test Group")
      ], deployer.address),
      
      Tx.contractCall('fit_sphere', 'create-competition', [
        types.uint(1),
        types.ascii("Test Competition"),
        types.uint(1),
        types.uint(100)
      ], deployer.address),
      
      // Try to end competition with non-admin
      Tx.contractCall('fit_sphere', 'end-competition', [
        types.uint(1)
      ], user1.address)
    ]);
    
    block.receipts[2].result.expectErr(types.uint(102)); // err-unauthorized
  },
});