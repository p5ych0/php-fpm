<?php
/**
 * Image and video format support test for PHP ZTS Alpine
 * Tests: imagick (HEIC/AVIF/WebP/JPEG XL/SVG), gd (WebP/AVIF), ffmpeg/ffprobe (H.264/HEVC/VP9/AV1)
 * Needs fixtures/sample.heic (64x48, EXIF Make=FixtureCam): the image can read HEIC but not write it.
 */

$results = [];
$failures = [];
$tmp = sys_get_temp_dir() . '/formats-' . getmypid();
@mkdir($tmp);

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

function sh(string $cmd): array {
    exec($cmd . ' 2>&1', $out, $code);
    return [$code, implode("\n", $out)];
}

function imagickRoundTrip(string $format): bool {
    $img = new Imagick();
    $img->newPseudoImage(64, 48, 'gradient:red-blue');
    $img->setImageFormat($format);
    $back = new Imagick();
    $back->readImageBlob($img->getImageBlob());
    return $back->getImageWidth() === 64 && $back->getImageHeight() === 48;
}

echo "=== Image & Video Format Tests ===\n\n";

// Test 1: imagick coders registered
test('imagick coders (HEIC HEIF AVIF WEBP JXL SVG PDF)', function() {
    $missing = array_diff(['HEIC', 'HEIF', 'AVIF', 'WEBP', 'JXL', 'SVG', 'PDF'], Imagick::queryFormats());
    if ($missing) {
        throw new RuntimeException('missing ' . implode(', ', $missing));
    }
    return true;
});

// Test 2: imagick decodes HEIC (iPhone photos) incl. EXIF
test('imagick read HEIC + EXIF', function() {
    $img = new Imagick(__DIR__ . '/fixtures/sample.heic');
    return $img->getImageWidth() === 64 && $img->getImageHeight() === 48
        && $img->getImageProperty('exif:Make') === 'FixtureCam';
});

// Test 3-5: imagick encode + decode
foreach (['AVIF', 'WEBP', 'JXL'] as $format) {
    test("imagick $format round-trip", fn() => imagickRoundTrip($format));
}

// Test 6: imagick renders SVG (librsvg)
test('imagick read SVG', function() {
    $img = new Imagick();
    $img->readImageBlob('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="48"><rect width="64" height="48" fill="red"/></svg>');
    $img->setImageFormat('png');
    return $img->getImageWidth() === 64 && strlen($img->getImageBlob()) > 0;
});

// Test 7: gd WebP/AVIF compiled in
test('gd_info WebP + AVIF', function() {
    $info = gd_info();
    return $info['WebP Support'] && $info['AVIF Support'];
});

// Test 8-9: gd encode + decode
test('gd WebP round-trip', function() use ($tmp) {
    $im = imagecreatetruecolor(64, 48);
    imagewebp($im, "$tmp/gd.webp");
    return imagesx(imagecreatefromwebp("$tmp/gd.webp")) === 64;
});

test('gd AVIF round-trip', function() use ($tmp) {
    $im = imagecreatetruecolor(64, 48);
    imageavif($im, "$tmp/gd.avif", 50, 10);
    return imagesx(imagecreatefromavif("$tmp/gd.avif")) === 64;
});

// Test 10: gd reads AVIF written by imagick (libheif) and vice versa
test('gd <-> imagick AVIF interop', function() use ($tmp) {
    $img = new Imagick();
    $img->newPseudoImage(64, 48, 'gradient:red-blue');
    $img->writeImage("avif:$tmp/im.avif");
    return imagesx(imagecreatefromavif("$tmp/im.avif")) === 64
        && (new Imagick("$tmp/gd.avif"))->getImageHeight() === 48;
});

// Test 11: ffmpeg + ffprobe binaries
test('ffmpeg/ffprobe available', function() {
    return sh('ffmpeg -version')[0] === 0 && sh('ffprobe -version')[0] === 0;
});

// Test 12-15: encode short clips, probe them, grab a frame into imagick
$clips = [
    'H.264 mp4' => ['libx264', 'mp4', 'h264'],
    'HEVC mp4' => ['libx265', 'mp4', 'hevc'],
    'VP9 webm' => ['libvpx-vp9', 'webm', 'vp9'],
    'AV1 webm' => ['libaom-av1 -cpu-used 8', 'webm', 'av1'],
];
foreach ($clips as $name => [$encoder, $ext, $codec]) {
    test("video $name encode/probe/thumbnail", function() use ($tmp, $encoder, $ext, $codec) {
        $clip = "$tmp/clip.$ext";
        [$code, $out] = sh("ffmpeg -v error -y -f lavfi -i testsrc=size=128x96:rate=10:duration=1 -c:v $encoder -pix_fmt yuv420p $clip");
        if ($code !== 0) {
            throw new RuntimeException($out);
        }
        [, $json] = sh("ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height -of json $clip");
        $stream = json_decode($json, true)['streams'][0] ?? [];
        [$code, $out] = sh("ffmpeg -v error -y -ss 0.5 -i $clip -frames:v 1 $tmp/frame.jpg");
        if ($code !== 0) {
            throw new RuntimeException($out);
        }
        return ($stream['codec_name'] ?? null) === $codec && ($stream['width'] ?? 0) === 128
            && (new Imagick("$tmp/frame.jpg"))->getImageWidth() === 128;
    });
}

array_map('unlink', glob("$tmp/*"));
rmdir($tmp);

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

echo "\n✓ All formats supported!\n";
exit(0);
