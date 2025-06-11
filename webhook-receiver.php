<?php
/**
 * Enhanced GitHub Webhook Receiver for IIS Kudu Deployment
 * 
 * This script receives GitHub webhooks and triggers Kudu deployment
 * for the IIS App Pool Recycler application with enhanced monitoring and error handling.
 */

// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Enhanced logging function
function logMessage($message, $level = 'INFO') {
    $timestamp = date('Y-m-d H:i:s');
    $ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
    $userAgent = $_SERVER['HTTP_USER_AGENT'] ?? 'unknown';
    
    $logEntry = "[$timestamp] [$level] $message [IP: $ip] [UA: " . substr($userAgent, 0, 50) . "...]\n";
    file_put_contents('webhook.log', $logEntry, FILE_APPEND | LOCK_EX);
    
    // Also log to deployment log for critical events
    if (in_array($level, ['ERROR', 'CRITICAL', 'DEPLOY'])) {
        file_put_contents('webhook-deployment.log', $logEntry, FILE_APPEND | LOCK_EX);
    }
}

// Health check endpoint
if ($_SERVER['REQUEST_METHOD'] === 'GET' && (isset($_GET['health']) || isset($_GET['status']))) {
    http_response_code(200);
    header('Content-Type: application/json');
    
    $status = [
        'status' => 'healthy',
        'service' => 'GitHub Webhook Receiver',
        'version' => '2.0.0',
        'timestamp' => date('c'),
        'server_info' => [
            'php_version' => PHP_VERSION,
            'deployment_script' => file_exists(__DIR__ . '/deploy-webhook.bat') ? 'available' : 'missing',
            'config_file' => file_exists(__DIR__ . '/config.ini') ? 'available' : 'missing',
            'last_deployment' => file_exists('webhook-deployment.log') ? date('c', filemtime('webhook-deployment.log')) : 'never'
        ]
    ];
    
    echo json_encode($status, JSON_PRETTY_PRINT);
    logMessage("Health check requested", 'INFO');
    exit;
}

// Start logging
logMessage("Webhook request received", 'INFO');

try {
    // Get the payload
    $payload = file_get_contents('php://input');
    $headers = getallheaders();
    
    // Get signature from header
    $signature = $headers['X-Hub-Signature-256'] ?? $headers['x-hub-signature-256'] ?? '';
    
    logMessage("Received signature: " . substr($signature, 0, 20) . "...");
    
    // Load configuration
    $configFile = __DIR__ . '/config.ini';
    if (!file_exists($configFile)) {
        throw new Exception("Configuration file not found: $configFile");
    }
    
    $config = parse_ini_file($configFile);
    if (!$config) {
        throw new Exception("Failed to parse configuration file");
    }
    
    $secret = $config['secret'] ?? '';
    $repository = $config['repository'] ?? '';
    $branch = $config['branch'] ?? 'main';
    
    if (empty($secret)) {
        throw new Exception("Webhook secret not configured");
    }
    
    // Verify signature
    $expected_signature = 'sha256=' . hash_hmac('sha256', $payload, $secret);
    
    if (!hash_equals($expected_signature, $signature)) {
        logMessage("Invalid signature. Expected: " . substr($expected_signature, 0, 20) . "...");
        http_response_code(401);
        exit('Unauthorized: Invalid signature');
    }
    
    logMessage("Signature verified successfully");
    
    // Parse payload
    $data = json_decode($payload, true);
    if (!$data) {
        throw new Exception("Failed to parse JSON payload");
    }
    
    // Log webhook details
    $repoName = $data['repository']['full_name'] ?? 'unknown';
    $ref = $data['ref'] ?? 'unknown';
    $commits = count($data['commits'] ?? []);
    
    logMessage("Repository: $repoName, Ref: $ref, Commits: $commits");
    
    // Check if it's the correct repository
    if ($repoName !== $repository) {
        logMessage("Repository mismatch. Expected: $repository, Got: $repoName");
        http_response_code(200);
        exit('Repository mismatch, skipping deployment');
    }
    
    // Check if it's a push to the target branch
    if ($ref !== "refs/heads/$branch") {
        logMessage("Branch mismatch. Expected: refs/heads/$branch, Got: $ref");
        http_response_code(200);
        exit('Not target branch, skipping deployment');
    }
    
    // Log the deployment trigger
    logMessage("Deployment conditions met. Triggering deployment...");
    
    // Get commit information for logging
    $lastCommit = end($data['commits']);
    $commitMessage = $lastCommit['message'] ?? 'No commit message';
    $commitAuthor = $lastCommit['author']['name'] ?? 'Unknown author';
    
    logMessage("Last commit: $commitMessage by $commitAuthor");
    
    // Trigger deployment script
    $deployScript = __DIR__ . '/deploy-webhook.bat';
    if (!file_exists($deployScript)) {
        throw new Exception("Deployment script not found: $deployScript");
    }
    
    // Execute deployment in background
    $command = "cd /d \"" . __DIR__ . "\" && deploy-webhook.bat > deployment-output.log 2>&1";
    
    if (PHP_OS_FAMILY === 'Windows') {
        // Windows command
        pclose(popen("start /B $command", "r"));
    } else {
        // Unix-like command (if needed)
        exec("$command &");
    }
    
    logMessage("Deployment script triggered successfully");
    
    // Return success response
    http_response_code(200);
    header('Content-Type: application/json');
    echo json_encode([
        'status' => 'success',
        'message' => 'Deployment triggered successfully',
        'repository' => $repoName,
        'branch' => $branch,
        'commit' => substr($lastCommit['id'] ?? '', 0, 7),
        'timestamp' => date('c')
    ]);
    
} catch (Exception $e) {
    $error = "Error: " . $e->getMessage();
    logMessage($error);
    
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode([
        'status' => 'error',
        'message' => $error,
        'timestamp' => date('c')
    ]);
}

logMessage("Webhook processing completed");
?>
