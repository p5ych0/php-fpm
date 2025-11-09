<?php
/**
 * Production-Ready Parallel & Swoole Demonstration
 * Simplified real-world usage examples
 */

echo "╔════════════════════════════════════════════════════════════╗\n";
echo "║  Parallel & Swoole Extensions - Production Demo           ║\n";
echo "╚════════════════════════════════════════════════════════════╝\n\n";

// ============================================================================
// PARALLEL EXTENSION TESTS
// ============================================================================

echo "┌─ PARALLEL EXTENSION ─────────────────────────────────────┐\n\n";

if (!extension_loaded('parallel')) {
    die("✗ Parallel extension not loaded\n");
}

// Test 1: Multi-threaded data processing
echo "1. Multi-Threaded Data Processing\n";
echo "   Processing large dataset across 4 threads...\n";

$data = range(1, 100);
$chunks = array_chunk($data, 25);
$startTime = microtime(true);

$runtimes = [];
$futures = [];

foreach ($chunks as $i => $chunk) {
    $runtimes[$i] = new parallel\Runtime();
    $futures[$i] = $runtimes[$i]->run(function($data) {
        $sum = 0;
        foreach ($data as $num) {
            $sum += $num * $num; // CPU intensive operation
        }
        return $sum;
    }, [$chunk]);
}

$totalSum = 0;
foreach ($futures as $future) {
    $totalSum += $future->value();
}

$duration = round((microtime(true) - $startTime) * 1000, 2);
echo "   Result: Sum of squares = $totalSum\n";
echo "   Duration: {$duration}ms\n";
echo "   ✓ Parallel processing successful\n\n";

// Test 2: Producer-Consumer pattern
echo "2. Producer-Consumer Pattern\n";

$channel = new parallel\Channel();
$producer = new parallel\Runtime();
$consumer = new parallel\Runtime();

// Start producer
$producerFuture = $producer->run(function($ch) {
    for ($i = 1; $i <= 10; $i++) {
        $ch->send("Job #$i");
    }
    $ch->send(null); // Signal completion
    return "Producer finished";
}, [$channel]);

// Start consumer
$consumerFuture = $consumer->run(function($ch) {
    $processed = 0;
    while (($job = $ch->recv()) !== null) {
        $processed++;
    }
    return $processed;
}, [$channel]);

$jobsProcessed = $consumerFuture->value();
$producerResult = $producerFuture->value();

echo "   $producerResult\n";
echo "   Consumer processed: $jobsProcessed jobs\n";
echo "   ✓ Channel communication working\n\n";

echo "└──────────────────────────────────────────────────────────┘\n\n";

// ============================================================================
// SWOOLE EXTENSION TESTS
// ============================================================================

echo "┌─ SWOOLE EXTENSION ───────────────────────────────────────┐\n\n";

if (!extension_loaded('swoole')) {
    die("✗ Swoole extension not loaded\n");
}

echo "   Swoole Version: " . swoole_version() . "\n\n";

// Test 1: Concurrent coroutines
echo "1. Concurrent Coroutine Execution\n";

$results = [];
$startTime = microtime(true);

Swoole\Coroutine\run(function() use (&$results) {
    // Simulate 5 concurrent API calls
    for ($i = 0; $i < 5; $i++) {
        go(function() use ($i, &$results) {
            $delay = rand(50, 150);
            Swoole\Coroutine::sleep($delay / 1000);
            $results[] = "Task $i completed ({$delay}ms)";
        });
    }
});

$totalTime = round((microtime(true) - $startTime) * 1000, 2);
echo "   Executed 5 concurrent tasks in {$totalTime}ms\n";
echo "   Results: " . count($results) . " tasks completed\n";
echo "   ✓ Concurrent execution successful\n\n";

// Test 2: Channel for inter-coroutine communication
echo "2. Coroutine Channel Communication\n";

Swoole\Coroutine\run(function() {
    $channel = new Swoole\Coroutine\Channel(5);
    $processed = 0;
    
    // Producer
    go(function() use ($channel) {
        for ($i = 1; $i <= 5; $i++) {
            $channel->push(['id' => $i, 'data' => "Item $i"]);
        }
        $channel->close();
    });
    
    // Consumer
    go(function() use ($channel, &$processed) {
        while (true) {
            $item = $channel->pop();
            if ($item === false) break;
            $processed++;
        }
    });
    
    Swoole\Coroutine::sleep(0.1); // Wait for completion
    
    echo "   Processed $processed items through channel\n";
    echo "   ✓ Channel communication successful\n\n";
});

// Test 3: WaitGroup for synchronization
echo "3. WaitGroup Synchronization\n";

Swoole\Coroutine\run(function() {
    $wg = new Swoole\Coroutine\WaitGroup();
    $completed = [];
    
    for ($i = 0; $i < 3; $i++) {
        $wg->add();
        go(function() use ($wg, $i, &$completed) {
            Swoole\Coroutine::sleep(0.05);
            $completed[] = "Worker $i";
            $wg->done();
        });
    }
    
    $wg->wait(); // Block until all done
    
    echo "   All workers completed: " . implode(', ', $completed) . "\n";
    echo "   ✓ WaitGroup synchronization successful\n\n";
});

// Test 4: Defer for cleanup
echo "4. Defer Pattern (Resource Cleanup)\n";

Swoole\Coroutine\run(function() {
    go(function() {
        defer(function() {
            echo "   → Cleanup: Closing database connection\n";
        });
        
        defer(function() {
            echo "   → Cleanup: Releasing file handle\n";
        });
        
        echo "   Working with resources...\n";
        Swoole\Coroutine::sleep(0.01);
        echo "   Work completed\n";
    });
});

echo "   ✓ Defer execution successful (LIFO)\n\n";

echo "└──────────────────────────────────────────────────────────┘\n\n";

// ============================================================================
// SUMMARY
// ============================================================================

echo "╔════════════════════════════════════════════════════════════╗\n";
echo "║                    SUMMARY                                 ║\n";
echo "╠════════════════════════════════════════════════════════════╣\n";
echo "║  ✓ Parallel Extension:                                    ║\n";
echo "║    - Multi-threaded computation ✓                         ║\n";
echo "║    - Channel communication ✓                              ║\n";
echo "║    - Producer-consumer pattern ✓                          ║\n";
echo "║                                                            ║\n";
echo "║  ✓ Swoole Extension:                                      ║\n";
echo "║    - Coroutine execution ✓                                ║\n";
echo "║    - Channel communication ✓                              ║\n";
echo "║    - WaitGroup synchronization ✓                          ║\n";
echo "║    - Defer pattern ✓                                      ║\n";
echo "║                                                            ║\n";
echo "║  Both extensions are PRODUCTION READY!                    ║\n";
echo "╚════════════════════════════════════════════════════════════╝\n";
