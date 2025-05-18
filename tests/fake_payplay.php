<?php
header('Content-Type: application/json');
echo json_encode([
    'status' => 'FAIL',
    'error' => 'Simulated error'
]);
