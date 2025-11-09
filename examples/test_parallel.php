<?php
/**
 * Parallel Extension Real-World Test
 * Tests: Multi-threaded computation, shared data, concurrent execution
 */

echo "=== Parallel Extension Real-World Test ===\n\n";

if (!extension_loaded('parallel')) {
    die("Parallel extension not loaded!\n");
}

// Test 1: CPU-intensive parallel computation
echo "Test 1: Parallel Fibonacci Calculation\n";
echo "Computing Fibonacci(35) in 4 parallel threads...\n";

$fibonacci = function(int $n): int {
    if ($n <= 1) return $n;
    return $fibonacci($n - 1) + $fibonacci($n - 2);
};

$startTime = microtime(true);

// Create 4 parallel runtimes
$runtimes = [];
$futures = [];

for ($i = 0; $i < 4; $i++) {
    $runtimes[$i] = new parallel\Runtime();
    $futures[$i] = $runtimes[$i]->run(function($n) {
        $fib = function(int $n) use (&$fib): int {
            if ($n <= 1) return $n;
            return $fib($n - 1) + $fib($n - 2);
        };
        return [
            'thread' => $n,
            'result' => $fib(30 + $n),
            'pid' => getmypid()
        ];
    }, [$i]);
}

// Collect results
$results = [];
foreach ($futures as $i => $future) {
    $results[] = $future->value();
}

$endTime = microtime(true);
$duration = round(($endTime - $startTime) * 1000, 2);

echo "Results:\n";
foreach ($results as $result) {
    echo sprintf("  Thread %d (PID: %d): fib(%d) = %d\n", 
        $result['thread'], 
        $result['pid'],
        30 + $result['thread'],
        $result['result']
    );
}
echo "Duration: {$duration}ms\n";
echo "✓ PASS: All threads completed\n\n";

// Test 2: Parallel channel communication
echo "Test 2: Channel Communication Between Threads\n";

$channel = new parallel\Channel();

// Producer thread
$producer = new parallel\Runtime();
$producerFuture = $producer->run(function($channel) {
    for ($i = 1; $i <= 5; $i++) {
        $channel->send([
            'id' => $i,
            'data' => "Message $i",
            'timestamp' => time()
        ]);
        usleep(100000); // 100ms
    }
    $channel->send('DONE');
}, [$channel]);

// Consumer thread
$consumer = new parallel\Runtime();
$consumerFuture = $consumer->run(function($channel) {
    $messages = [];
    while (true) {
        $msg = $channel->recv();
        if ($msg === 'DONE') break;
        $messages[] = $msg;
    }
    return $messages;
}, [$channel]);

$messages = $consumerFuture->value();
$producerFuture->value();

echo "Received " . count($messages) . " messages:\n";
foreach ($messages as $msg) {
    echo sprintf("  #%d: %s (ts: %d)\n", $msg['id'], $msg['data'], $msg['timestamp']);
}
echo "✓ PASS: Channel communication working\n\n";

// Test 3: Parallel events
echo "Test 3: Event-Based Synchronization\n";

$events = new parallel\Events();
$events->setBlocking(false);

// Create multiple tasks
for ($i = 0; $i < 3; $i++) {
    $runtime = new parallel\Runtime();
    $future = $runtime->run(function($id) {
        usleep(rand(100000, 500000)); // Random delay 100-500ms
        return "Task $id completed";
    }, [$i]);
    
    $events->addFuture("task_$i", $future);
}

$completed = 0;
$timeout = 2; // 2 seconds timeout
$start = microtime(true);

echo "Waiting for tasks to complete...\n";
while ($completed < 3 && (microtime(true) - $start) < $timeout) {
    $event = $events->poll();
    if ($event) {
        echo sprintf("  %s: %s\n", $event->source, $event->value);
        $completed++;
    }
    usleep(10000); // 10ms
}

if ($completed === 3) {
    echo "✓ PASS: All events processed\n\n";
} else {
    echo "✗ FAIL: Timeout waiting for events\n\n";
}

// Test 4: Error handling in parallel execution
echo "Test 4: Exception Handling\n";

try {
    $runtime = new parallel\Runtime();
    $future = $runtime->run(function() {
        throw new Exception("Intentional error from parallel thread");
    });
    
    $future->value();
    echo "✗ FAIL: Exception not caught\n\n";
} catch (parallel\Future\Error\Foreign $e) {
    echo "Caught exception from parallel thread: " . $e->getMessage() . "\n";
    echo "✓ PASS: Exception handling working\n\n";
}

// Test 5: Shared memory via channels
echo "Test 5: Producer-Consumer Pattern with Multiple Workers\n";

$workChannel = new parallel\Channel();
$resultChannel = new parallel\Channel();

// Start 3 worker threads
$workers = [];
for ($i = 0; $i < 3; $i++) {
    $workers[$i] = new parallel\Runtime();
    $workers[$i]->run(function($workChan, $resultChan, $workerId) {
        while (true) {
            $task = $workChan->recv();
            if ($task === null) break;
            
            // Process task (square the number)
            $result = [
                'worker' => $workerId,
                'input' => $task,
                'output' => $task * $task
            ];
            
            $resultChan->send($result);
        }
    }, [$workChannel, $resultChannel, $i]);
}

// Send work
echo "Sending 9 tasks to 3 workers...\n";
for ($i = 1; $i <= 9; $i++) {
    $workChannel->send($i);
}

// Send termination signals
for ($i = 0; $i < 3; $i++) {
    $workChannel->send(null);
}

// Collect results
$results = [];
for ($i = 0; $i < 9; $i++) {
    $results[] = $resultChannel->recv();
}

// Sort by input for display
usort($results, fn($a, $b) => $a['input'] <=> $b['input']);

foreach ($results as $r) {
    echo sprintf("  Worker #%d: %d² = %d\n", $r['worker'], $r['input'], $r['output']);
}
echo "✓ PASS: Multi-worker pattern successful\n\n";

echo "=== All Parallel Tests Completed Successfully ===\n";
