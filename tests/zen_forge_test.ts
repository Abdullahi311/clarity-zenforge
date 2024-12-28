import {
    Clarinet,
    Tx,
    Chain,
    Account,
    types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Ensure that only owner can mint meditations",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const user1 = accounts.get('wallet_1')!;

        let block = chain.mineBlock([
            // Owner minting should succeed
            Tx.contractCall('zen-forge', 'mint-meditation', [
                types.ascii("Morning Calm"),
                types.uint(600),
                types.uint(100)
            ], deployer.address),
            // Non-owner minting should fail
            Tx.contractCall('zen-forge', 'mint-meditation', [
                types.ascii("Evening Peace"),
                types.uint(900),
                types.uint(150)
            ], user1.address)
        ]);

        block.receipts[0].result.expectOk().expectUint(0);
        block.receipts[1].result.expectErr().expectUint(100);
    }
});

Clarinet.test({
    name: "Test meditation session completion and rewards",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const user1 = accounts.get('wallet_1')!;

        // First mint a meditation
        let mint = chain.mineBlock([
            Tx.contractCall('zen-forge', 'mint-meditation', [
                types.ascii("Morning Calm"),
                types.uint(600),
                types.uint(100)
            ], deployer.address)
        ]);

        // Complete a session
        let complete = chain.mineBlock([
            Tx.contractCall('zen-forge', 'complete-session', [
                types.uint(0)
            ], user1.address)
        ]);

        complete.receipts[0].result.expectOk().expectBool(true);

        // Check user stats
        let stats = chain.mineBlock([
            Tx.contractCall('zen-forge', 'get-user-stats', [
                types.principal(user1.address)
            ], user1.address)
        ]);

        let statsResult = stats.receipts[0].result.expectOk().expectSome();
        assertEquals(statsResult['total-minutes'], types.uint(600));
        assertEquals(statsResult['sessions-completed'], types.uint(1));
        assertEquals(statsResult['rewards-earned'], types.uint(10));
    }
});