<?php
declare(strict_types=1);

use PHPUnit\Framework\TestCase;
use PE\PayPlayTest\Autopayment_payplay;

require_once dirname(__DIR__, 1) . '/bootstrap.php';

final class AutopaymentPayplayTest extends TestCase
{
    /** Ensures we build the correct JSON & headers for create_payout() */
    public function testCreatePayoutShapesRequest(): void
    {
        $captured = [];

        $stubHandler = function (
            string $method,
            string $url,
            string $body,
            array  $hdrs
        ) use (&$captured): string {
            $captured = compact('method', 'url', 'body', 'hdrs');
            return json_encode([
                'status' => 'SUCCESS',
                'data'   => ['id' => 'wd_123', 'status' => 'PROCESSING']
            ]);
        };

        $gw = new Autopayment_payplay(
            ['api_key' => 'k', 'api_secret' => 's', 'api_url' => 'https://mock'],
            $stubHandler
        );

        $row   = ['id' => 42, 'amount' => 100, 'currency' => 'USDT',
                  'wallet' => 'TXYZ', 'callback_url' => 'https://me/cb'];
        $reply = $gw->create_payout($row);

        $req = json_decode($captured['body'], true);
        $this->assertSame('100',    $req['amount']);
        $this->assertSame('USDT',   $req['asset']);
        $this->assertSame('42',     $req['external_id']);
        $this->assertSame('TXYZ',   $req['address']);
        $this->assertSame('https://me/cb', $req['callback_url']);

        $this->assertSame('wd_123',     $reply['external_id']);
        $this->assertSame('PROCESSING', $reply['status']);
    }

    /** Verifies sync_status() consumes PayPlay payload and returns status */
    public function testSyncStatusReturnsRemoteStatus(): void
    {
        $stub = fn() => json_encode([
            'status' => 'SUCCESS',
            'data'   => ['status' => 'CONFIRMED']
        ]);
        $gw   = new Autopayment_payplay([], fn() => $stub());

        $state = $gw->sync_status(['external_id' => 'whatever']);
        $this->assertSame('CONFIRMED', $state);
    }

    /** Checks raw signature helper */
    public function testSignatureAlgorithm(): void
    {
        $toSign = "123\nPOST\n/v1/withdrawals\n{\"amount\":\"1\"}";
        $this->assertSame(
            hash_hmac('sha256', $toSign, 'secret'),
            Autopayment_payplay::sign('secret', $toSign)
        );
    }
}
