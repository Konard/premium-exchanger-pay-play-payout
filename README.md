# PayPlay ↔ Premium Exchanger — Payout Module Test Harness

Quick-start repository for developing, stubbing, and unit-testing a *PayPlay* autopayment (withdrawal) gateway module compatible with **Premium Exchanger** ≥ 2.6.

## Repository Structure

```
repo root
├── src/
│   └── Autopayment_payplay.php        ← Gateway implementation
├── tests/
│   ├── AutopaymentPayplayTest.php     ← PHPUnit tests (97%+ coverage enforced)
│   └── fake_payplay.php               ← Local test server for coverage
├── bootstrap.php                      ← Autoload helper for tests
├── composer.json                      ← Dev dependencies (phpunit)
├── phpunit.xml                        ← PHPUnit config (coverage threshold)
├── xdebug.ini                         ← Xdebug config for coverage
├── Dockerfile                         ← Docker setup for consistent dev/test
└── .gitignore
```

## Getting Started

### 1. Install Dependencies

```bash
composer install
```

### 2. Run Tests (with Coverage)

**Locally:**
```bash
XDEBUG_MODE=coverage ./vendor/bin/phpunit --coverage-text
```

**In Docker:**
```bash
docker build -t premium-exchanger-payplay .
docker run --rm -e XDEBUG_MODE=coverage -v $(pwd):/app -w /app premium-exchanger-payplay vendor/bin/phpunit --coverage-text
```

- Code coverage threshold is enforced (97%+). Tests will fail if coverage drops.
- Xdebug is required for coverage. See `xdebug.ini` for config.

### 3. Developing & Testing the Gateway

- Edit `src/Autopayment_payplay.php` to implement or extend the gateway logic.
- Add or modify tests in `tests/AutopaymentPayplayTest.php`.
- Use dependency injection for the request handler to stub network I/O in tests.
- Run tests frequently to ensure coverage and correctness.

### 4. Using the Gateway in Your Project

```php
use PE\PayPlayTest\Autopayment_payplay;

$gateway = new Autopayment_payplay([
    'api_key'    => 'your_key',
    'api_secret' => 'your_secret',
    'api_url'    => 'https://api.payplay.io',
]);

// Create a payout
$result = $gateway->create_payout([
    'id'           => 123,
    'amount'       => 100,
    'currency'     => 'USDT',
    'wallet'       => 'TXYZ...',
    'callback_url' => 'https://yourdomain/callback',
]);

// Check payout status
$status = $gateway->sync_status(['external_id' => $result['external_id']]);
```

### 5. Advanced: Local Coverage for All Branches

To achieve maximum coverage, the test suite includes a local PHP server (`tests/fake_payplay.php`) to simulate error payloads. This is handled automatically in the tests.

## File-by-file Overview

| File | Purpose |
|------|---------|
| **src/Autopayment_payplay.php** | Core gateway class. Production-ready `curl` code plus injectable stub for tests. |
| **tests/AutopaymentPayplayTest.php** | Covers: signature algorithm, `create_payout()` request shaping, error handling, and `sync_status()` flow. |
| **tests/fake_payplay.php** | Local test server for simulating error payloads in coverage tests. |
| **bootstrap.php** | Registers the `src/` tree for PSR-4 (`PE\\PayPlayTest\\`). |
| **composer.json** | Dev dependency on PHPUnit ≥ 10, PSR-4 autoload directive. |
| **phpunit.xml** | Enforces code coverage threshold. |
| **xdebug.ini** | Xdebug config for coverage. |
| **Dockerfile** | Docker setup for consistent dev/test. |
| **.gitignore** | Ignores Composer artefacts (`/vendor`, `composer.lock`). |

## Contributing & Development
- Keep code coverage above the enforced threshold (97%).
- Add tests for all new logic and error branches.
- Use Docker for consistent local and CI testing.
- PRs should pass all tests and coverage checks.

---

Feel free to drop this folder into `application/modules/autopayment/payplay/` inside a real Premium Exchanger install once you are done iterating.
