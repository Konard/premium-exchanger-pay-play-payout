#!/usr/bin/env bash
# -----------------------------------------------------------------------
# create-pe-payplay-repo.sh
# -----------------------------------------------------------------------
# Generates a self-contained repository for developing & testing a
# PayPlay *payout* (autopayment) module compatible with Premium Exchanger.
# -----------------------------------------------------------------------
set -euo pipefail

REPO="pe-payplay-payout-test"
[ -d "$REPO" ] && { echo "Directory '$REPO' already exists. Aborting."; exit 1; }

echo "› Creating repository skeleton: $REPO"
mkdir -p "$REPO"/{src,tests}

############################################################################
# 1. README.md
############################################################################
cat <<'EOF' >"$REPO/README.md"
# PayPlay ↔ Premium Exchanger — Payout Module Test Harness

Quick-start repository that lets you **develop, stub and unit-test** a  
*PayPlay* autopayment (withdrawal) gateway module compatible with **Premium Exchanger** ≥ 2.6.

``\`\`
repo root
├── src/
│   └── Autopayment_payplay.php        ← gateway implementation
├── tests/
│   └── AutopaymentPayplayTest.php     ← PHPUnit tests
├── bootstrap.php                      ← autoload helper for tests
├── composer.json                      ← dev dependencies (phpunit)
└── .gitignore
``\`\`

## Usage

``\`\`bash
composer install
./vendor/bin/phpunit
``\`\`

## File-by-file overview

| File | Purpose |
|------|---------|
| **src/Autopayment_payplay.php** | Core gateway class. Production-ready `curl` code plus injectable stub for tests. |
| **tests/AutopaymentPayplayTest.php** | Covers: signature algorithm, `create_payout()` request shaping, and `sync_status()` flow. |
| **bootstrap.php** | Registers the `src/` tree for PSR-4 (`PE\\PayPlayTest\\`). |
| **composer.json** | Dev dependency on PHPUnit ≥ 10, PSR-4 autoload directive. |
| **.gitignore** | Ignores Composer artefacts (`/vendor`, `composer.lock`). |

Feel free to drop this folder into  
`application/modules/autopayment/payplay/` inside a real Premium Exchanger
install once you are done iterating.
EOF

############################################################################
# 2. composer.json
############################################################################
cat <<'EOF' >"$REPO/composer.json"
{
  "name": "premiumexchanger/payplay-test",
  "description": "Test harness for PayPlay payout module (Premium Exchanger)",
  "license": "MIT",
  "require": {
    "php": ">=8.1"
  },
  "require-dev": {
    "phpunit/phpunit": "^10"
  },
  "autoload": {
    "psr-4": {
      "PE\\PayPlayTest\\": "src/"
    }
  },
  "minimum-stability": "stable"
}
EOF

############################################################################
# 3. .gitignore
############################################################################
cat <<'EOF' >"$REPO/.gitignore"
/vendor
composer.lock
/.idea
.DS_Store
EOF

############################################################################
# 4. bootstrap.php
############################################################################
cat <<'PHP' >"$REPO/bootstrap.php"
<?php
// Lightweight bootstrap so tests can `require __DIR__.'/../bootstrap.php'`
require __DIR__ . '/vendor/autoload.php';
PHP

############################################################################
# 5. src/Autopayment_payplay.php
############################################################################
cat <<'PHP' >"$REPO/src/Autopayment_payplay.php"
<?php
/**
 * Autopayment_payplay — PayPlay payout gateway for Premium Exchanger.
 *
 *  • create_payout(array $row): array
 *  • sync_status(array $row):  string
 *
 * Injection-friendly: pass a callable $requestHandler to ctor to stub
 * network I/O in unit tests.  Production code falls back to cURL.
 */
namespace PE\PayPlayTest;

class Autopayment_payplay
{
    private string $apiKey;
    private string $apiSecret;
    private string $baseUrl;
    /** @var callable(string $method,string $url,string $body,array $hdrs):string */
    private $requestHandler;

    public function __construct(array $cfg, callable $requestHandler = null)
    {
        $this->apiKey         = $cfg['api_key']    ?? 'demo_key';
        $this->apiSecret      = $cfg['api_secret'] ?? 'demo_secret';
        $this->baseUrl        = rtrim($cfg['api_url'] ?? 'https://api.payplay.io', '/');
        $this->requestHandler = $requestHandler ?? [$this, 'curlRequest'];
    }

    /** Kick off a blockchain payout (withdrawal). */
    public function create_payout(array $row): array
    {
        $payload = [
            'amount'       => (string) $row['amount'],
            'asset'        => $row['currency'],
            'address'      => $row['wallet'],
            'external_id'  => (string) $row['id'],
            'callback_url' => $row['callback_url'] ?? 'https://example.com/webhook',
        ];

        $resp = $this->signedRequest('POST', '/v1/withdrawals', $payload);

        return [
            'external_id' => $resp['id']     ?? null,
            'status'      => $resp['status'] ?? 'PROCESSING',
            'raw'         => json_encode($resp, JSON_UNESCAPED_UNICODE),
        ];
    }

    /** Poll PayPlay and return remote status string. */
    public function sync_status(array $row): string
    {
        $resp = $this->signedRequest('GET', '/v1/withdrawals/' . $row['external_id']);
        return $resp['status'] ?? 'UNKNOWN';
    }

    /* ------------------------------------------------------------------ */

    private function signedRequest(string $method, string $path, array $body = [])
    {
        $timestamp    = (string) ((int) (microtime(true) * 1000));
        $jsonBody     = $body ? json_encode($body, JSON_UNESCAPED_SLASHES) : '';
        $stringToSign = "{$timestamp}\n{$method}\n{$path}\n{$jsonBody}";
        $sign         = hash_hmac('sha256', $stringToSign, $this->apiSecret);

        $headers = [
            "Content-Type: application/json",
            "X-PAYPLAY-KEY: {$this->apiKey}",
            "X-PAYPLAY-TIMESTAMP: {$timestamp}",
            "X-PAYPLAY-SIGN: {$sign}",
        ];
        $url  = $this->baseUrl . $path;
        $resp = call_user_func($this->requestHandler, $method, $url, $jsonBody, $headers);

        $data = json_decode($resp, true);
        if (!is_array($data)) {
            throw new \RuntimeException("Invalid JSON from PayPlay: $resp");
        }
        if (($data['status'] ?? 'SUCCESS') !== 'SUCCESS') {
            throw new \RuntimeException("PayPlay error payload: $resp");
        }
        return $data['data'] ?? $data;
    }

    /** Default HTTP implementation using cURL. */
    private function curlRequest(string $method, string $url, string $body, array $headers): string
    {
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CUSTOMREQUEST  => $method,
            CURLOPT_POSTFIELDS     => $body ?: null,
            CURLOPT_HTTPHEADER     => $headers,
        ]);
        $out = curl_exec($ch);
        if ($out === false) {
            throw new \RuntimeException('cURL error: ' . curl_error($ch));
        }
        return $out;
    }

    /* Helpers for unit tests ------------------------------------------ */

    public static function sign(string $secret, string $stringToSign): string
    {
        return hash_hmac('sha256', $stringToSign, $secret);
    }
}
PHP

############################################################################
# 6. tests/AutopaymentPayplayTest.php
############################################################################
cat <<'PHP' >"$REPO/tests/AutopaymentPayplayTest.php"
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
PHP

echo "› All files generated."
echo "› Next steps:"
echo "   cd $REPO && composer install && ./vendor/bin/phpunit"