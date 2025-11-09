<?php
/**
 * Comprehensive extension functionality test for PHP 8.4 ZTS Alpine
 * Tests: igbinary, imagick, redis, mongodb, parallel, uv, ds, psr, swoole, gd, etc.
 */

$results = [];
$failures = [];

function test($name, callable $fn) {
    global $results, $failures;
    try {
        $result = $fn();
        $results[$name] = $result ? '✓' : '✗ FAILED';
        if (!$result) {
            $failures[] = $name;
        }
    } catch (Throwable $e) {
        $results[$name] = '✗ ERROR: ' . $e->getMessage();
        $failures[] = $name;
    }
}

echo "=== PHP Extension Functionality Tests ===\n\n";

// Test 1: igbinary serialization
test('igbinary', function() {
    $data = ['foo' => 'bar', 'nested' => ['a' => 1, 'b' => 2]];
    $serialized = igbinary_serialize($data);
    $unserialized = igbinary_unserialize($serialized);
    return $unserialized === $data;
});

// Test 2: imagick image manipulation
test('imagick', function() {
    $img = new Imagick();
    $img->newImage(100, 100, new ImagickPixel('red'));
    $img->setImageFormat('png');
    $blob = $img->getImageBlob();
    return strlen($blob) > 0 && $img->getImageWidth() === 100;
});

// Test 3: Redis with igbinary serialization
test('redis', function() {
    $redis = new Redis();
    // Don't actually connect, just verify methods exist
    return method_exists($redis, 'setOption') && 
           defined('Redis::SERIALIZER_IGBINARY');
});

// Test 4: MongoDB driver
test('mongodb', function() {
    // Just verify we can create MongoDB objects
    $manager = new MongoDB\Driver\Manager('mongodb://localhost:27017', 
        ['connect' => false]);
    return $manager instanceof MongoDB\Driver\Manager;
});

// Test 5: Data Structures (ds)
test('ds', function() {
    $vector = new Ds\Vector([1, 2, 3]);
    $vector->push(4);
    $map = new Ds\Map(['a' => 1, 'b' => 2]);
    return $vector->count() === 4 && $map->count() === 2;
});

// Test 6: PSR extension
test('psr', function() {
    return class_exists('Psr\Log\LogLevel') && 
           interface_exists('Psr\Log\LoggerInterface');
});

// Test 7: Swoole
test('swoole', function() {
    return class_exists('Swoole\Coroutine') && 
           function_exists('swoole_version');
});

// Test 8: UV (libuv)
test('uv', function() {
    $loop = uv_default_loop();
    return is_resource($loop) || is_object($loop);
});

// Test 9: Parallel extension
test('parallel', function() {
    return class_exists('parallel\Runtime') && 
           class_exists('parallel\Future');
});

// Test 10: GD image processing
test('gd', function() {
    $img = imagecreatetruecolor(50, 50);
    $result = is_resource($img) || is_object($img);
    if (is_resource($img)) {
        imagedestroy($img);
    }
    return $result;
});

// Test 11: BCMath arbitrary precision
test('bcmath', function() {
    $result = bcadd('1234567890123456789', '9876543210987654321');
    return $result === '11111111101111111110';
});

// Test 12: GMP
test('gmp', function() {
    $a = gmp_init('12345678901234567890');
    $b = gmp_init('98765432109876543210');
    $sum = gmp_add($a, $b);
    return gmp_strval($sum) === '111111111011111111100';
});

// Test 13: Intl
test('intl', function() {
    $fmt = new NumberFormatter('en_US', NumberFormatter::DECIMAL);
    return $fmt->format(1234.56) === '1,234.56';
});

// Test 14: PDO MySQL
test('pdo_mysql', function() {
    return in_array('mysql', PDO::getAvailableDrivers());
});

// Test 15: PDO PostgreSQL
test('pdo_pgsql', function() {
    return in_array('pgsql', PDO::getAvailableDrivers());
});

// Test 16: Mbstring
test('mbstring', function() {
    return mb_strlen('Hello 世界') === 8;
});

// Test 17: Zip
test('zip', function() {
    $zip = new ZipArchive();
    return method_exists($zip, 'open');
});

// Test 18: Soap
test('soap', function() {
    return class_exists('SoapClient');
});

// Test 19: Sockets
test('sockets', function() {
    return function_exists('socket_create');
});

// Test 20: OPcache
test('opcache', function() {
    // OPcache may be disabled in CLI mode, just verify functions exist
    return function_exists('opcache_get_status') && 
           function_exists('opcache_reset');
});

// Test 21: Exif
test('exif', function() {
    return function_exists('exif_imagetype');
});

// Test 22: Gettext
test('gettext', function() {
    return function_exists('gettext');
});

// Print results
echo "\n--- Test Results ---\n";
$maxLen = max(array_map('strlen', array_keys($results)));
foreach ($results as $name => $status) {
    printf("%-{$maxLen}s : %s\n", $name, $status);
}

echo "\n--- Summary ---\n";
$total = count($results);
$passed = $total - count($failures);
echo "Passed: $passed/$total\n";

if (count($failures) > 0) {
    echo "\nFailed tests:\n";
    foreach ($failures as $name) {
        echo "  - $name\n";
    }
    exit(1);
}

echo "\n✓ All extensions functional!\n";
exit(0);
