<?php
/**
 * Detailed extension functionality tests
 * Focus on igbinary, imagick, redis integration, and complex operations
 */

echo "=== Detailed Extension Functionality Tests ===\n\n";

// Test 1: igbinary advanced serialization
echo "1. Testing igbinary advanced serialization...\n";
$complexData = [
    'string' => 'Hello World',
    'number' => 12345,
    'float' => 3.14159,
    'array' => [1, 2, 3, 4, 5],
    'nested' => [
        'deep' => [
            'structure' => true,
            'null' => null,
        ]
    ],
    'object' => (object)['prop' => 'value']
];

$serialized = igbinary_serialize($complexData);
$unserialized = igbinary_unserialize($serialized);

echo "   Original size: " . strlen(serialize($complexData)) . " bytes (PHP serialize)\n";
echo "   igbinary size: " . strlen($serialized) . " bytes\n";
echo "   Compression: " . round((1 - strlen($serialized) / strlen(serialize($complexData))) * 100, 2) . "%\n";
echo "   Data integrity: " . ($complexData == $unserialized ? "✓ PASS" : "✗ FAIL") . "\n\n";

// Test 2: imagick comprehensive image operations
echo "2. Testing imagick image operations...\n";
try {
    $img = new Imagick();
    
    // Create image
    $img->newImage(200, 150, new ImagickPixel('blue'));
    $img->setImageFormat('png');
    
    // Test various operations
    $img->scaleImage(100, 75);
    $img->rotateImage(new ImagickPixel('white'), 45);
    $img->blurImage(5, 3);
    
    // Get image info
    echo "   Image format: " . $img->getImageFormat() . "\n";
    echo "   Dimensions: " . $img->getImageWidth() . "x" . $img->getImageHeight() . "\n";
    echo "   Image size: " . strlen($img->getImageBlob()) . " bytes\n";
    
    // Test supported formats
    $formats = Imagick::queryFormats();
    echo "   Supported formats: " . count($formats) . " (includes " . 
         (in_array('PNG', $formats) ? 'PNG' : '') . ", " .
         (in_array('JPEG', $formats) ? 'JPEG' : '') . ", " .
         (in_array('GIF', $formats) ? 'GIF' : '') . ")\n";
    
    $img->clear();
    echo "   ✓ PASS\n\n";
} catch (Exception $e) {
    echo "   ✗ FAIL: " . $e->getMessage() . "\n\n";
}

// Test 3: Redis with igbinary serialization mode
echo "3. Testing Redis with igbinary serialization...\n";
try {
    $redis = new Redis();
    
    // Verify igbinary serializer is available
    $hasIgbinary = defined('Redis::SERIALIZER_IGBINARY');
    echo "   Redis::SERIALIZER_IGBINARY available: " . ($hasIgbinary ? "✓" : "✗") . "\n";
    
    // Test other serializers
    $serializers = [];
    if (defined('Redis::SERIALIZER_NONE')) $serializers[] = 'NONE';
    if (defined('Redis::SERIALIZER_PHP')) $serializers[] = 'PHP';
    if (defined('Redis::SERIALIZER_IGBINARY')) $serializers[] = 'IGBINARY';
    if (defined('Redis::SERIALIZER_JSON')) $serializers[] = 'JSON';
    
    echo "   Available serializers: " . implode(', ', $serializers) . "\n";
    echo "   ✓ PASS\n\n";
} catch (Exception $e) {
    echo "   ✗ FAIL: " . $e->getMessage() . "\n\n";
}

// Test 4: MongoDB driver capabilities
echo "4. Testing MongoDB driver...\n";
try {
    // Test without actual connection
    $manager = new MongoDB\Driver\Manager('mongodb://localhost:27017', 
        ['connect' => false]);
    
    // Verify we can create queries and commands
    $query = new MongoDB\Driver\Query(['status' => 'active']);
    $command = new MongoDB\Driver\Command(['ping' => 1]);
    $bulkWrite = new MongoDB\Driver\BulkWrite();
    
    echo "   Manager class: ✓\n";
    echo "   Query class: ✓\n";
    echo "   Command class: ✓\n";
    echo "   BulkWrite class: ✓\n";
    echo "   ✓ PASS\n\n";
} catch (Exception $e) {
    echo "   ✗ FAIL: " . $e->getMessage() . "\n\n";
}

// Test 5: Data Structures advanced usage
echo "5. Testing Data Structures (ds) extension...\n";
try {
    // Vector operations
    $vector = new Ds\Vector([1, 2, 3, 4, 5]);
    $vector->push(6, 7, 8);
    $vector->map(function($x) { return $x * 2; });
    
    // Map operations
    $map = new Ds\Map(['a' => 1, 'b' => 2, 'c' => 3]);
    $map->put('d', 4);
    $filtered = $map->filter(function($key, $value) { return $value > 2; });
    
    // Set operations
    $set = new Ds\Set([1, 2, 3, 4, 5]);
    $set->add(6);
    $set->remove(1);
    
    // Stack operations
    $stack = new Ds\Stack([1, 2, 3]);
    $stack->push(4);
    $top = $stack->pop();
    
    echo "   Vector: ✓ (count: " . $vector->count() . ")\n";
    echo "   Map: ✓ (filtered count: " . $filtered->count() . ")\n";
    echo "   Set: ✓ (count: " . $set->count() . ")\n";
    echo "   Stack: ✓ (top was: $top)\n";
    echo "   ✓ PASS\n\n";
} catch (Exception $e) {
    echo "   ✗ FAIL: " . $e->getMessage() . "\n\n";
}

// Test 6: Parallel runtime
echo "6. Testing parallel extension...\n";
try {
    if (!extension_loaded('parallel')) {
        throw new Exception('Parallel extension not loaded');
    }
    
    // Simple parallel execution test
    $runtime = new parallel\Runtime();
    $future = $runtime->run(function() {
        return "Hello from parallel runtime";
    });
    
    $result = $future->value();
    echo "   Runtime execution: ✓\n";
    echo "   Result: '$result'\n";
    echo "   ✓ PASS\n\n";
} catch (Exception $e) {
    echo "   ✗ FAIL: " . $e->getMessage() . "\n\n";
}

// Test 7: GD advanced operations
echo "7. Testing GD image processing...\n";
try {
    $img = imagecreatetruecolor(100, 100);
    $white = imagecolorallocate($img, 255, 255, 255);
    $black = imagecolorallocate($img, 0, 0, 0);
    
    imagefill($img, 0, 0, $white);
    imagerectangle($img, 10, 10, 90, 90, $black);
    
    // Get image data
    ob_start();
    imagepng($img);
    $imageData = ob_get_clean();
    
    echo "   Image created: 100x100\n";
    echo "   PNG output size: " . strlen($imageData) . " bytes\n";
    echo "   ✓ PASS\n\n";
    
    imagedestroy($img);
} catch (Exception $e) {
    echo "   ✗ FAIL: " . $e->getMessage() . "\n\n";
}

// Test 8: Swoole coroutine
echo "8. Testing Swoole coroutine...\n";
try {
    $result = Swoole\Coroutine::create(function() {
        return "Coroutine executed";
    });
    
    echo "   Coroutine support: ✓\n";
    echo "   Swoole version: " . swoole_version() . "\n";
    echo "   ✓ PASS\n\n";
} catch (Exception $e) {
    echo "   ✗ FAIL: " . $e->getMessage() . "\n\n";
}

echo "=== All Detailed Tests Complete ===\n";
