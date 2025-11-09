<?php
// Simple browscap test: prints whether browscap is configured and basic keys
$ini = ini_get('browscap');
$browser = @get_browser(null, true);

$info = [
    'browscap_ini' => $ini,
    'configured' => is_array($browser) && !empty($ini),
    'keys' => is_array($browser) ? array_slice(array_keys($browser), 0, 10) : [],
];

echo json_encode($info, JSON_PRETTY_PRINT), "\n";
