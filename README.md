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
