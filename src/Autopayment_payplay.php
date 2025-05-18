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
