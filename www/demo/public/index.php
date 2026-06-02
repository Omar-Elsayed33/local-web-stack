<?php
/**
 * local-web-stack — demo project
 *
 * Shows project info and verifies the MySQL + Mailpit wiring.
 * For local development only.
 */

$projectName  = getenv('MYSQL_DATABASE') ? 'local-web-stack (demo)' : 'demo';
$host         = $_SERVER['HTTP_HOST'] ?? 'unknown';
$phpVersion   = PHP_VERSION;

// Values injected by docker-compose (see the php service environment).
$dbHost = 'mysql';
$dbPort = 3306;
$dbName = getenv('MYSQL_DATABASE') ?: 'app';
$dbUser = getenv('MYSQL_USER') ?: 'app';
$dbPass = getenv('MYSQL_PASSWORD') ?: 'app';

$mailHost   = 'mailpit';
$mailPort   = 1025;
$mailUiHost = getenv('MAILPIT_DOMAIN') ?: 'mail.test';

// --- MySQL connection test --------------------------------------------------
$dbStatus = '';
$dbOk = false;
try {
    $dsn = "mysql:host={$dbHost};port={$dbPort};dbname={$dbName};charset=utf8mb4";
    $pdo = new PDO($dsn, $dbUser, $dbPass, [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_TIMEOUT            => 3,
    ]);
    $version  = $pdo->query('SELECT VERSION()')->fetchColumn();
    $dbStatus = "Connected. MySQL server version: {$version}";
    $dbOk = true;
} catch (Throwable $e) {
    $dbStatus = 'Connection failed: ' . $e->getMessage();
}

// --- Optional test email ----------------------------------------------------
$mailStatus = '';
$mailSent = false;
if (($_GET['sendmail'] ?? '') === '1') {
    $to      = 'test@local.test';
    $subject = 'Test email from local-web-stack demo';
    $body    = "Hello from the demo project at {$host}.\nSent: " . date('c');
    $headers = 'From: noreply@local.test';

    // mail() is routed to Mailpit via msmtp (see php/Dockerfile).
    $mailSent   = @mail($to, $subject, $body, $headers);
    $mailStatus = $mailSent
        ? "Email handed off to SMTP. Open http://{$mailUiHost} to view it."
        : 'mail() returned false. Check msmtp config and Mailpit container.';
}

function e(string $v): string { return htmlspecialchars($v, ENT_QUOTES, 'UTF-8'); }
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?= e($projectName) ?></title>
    <style>
        :root { color-scheme: light dark; }
        body { font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif;
               max-width: 760px; margin: 3rem auto; padding: 0 1rem; line-height: 1.5; }
        h1 { margin-bottom: 0; }
        .muted { color: #888; margin-top: .25rem; }
        table { border-collapse: collapse; width: 100%; margin: 1rem 0; }
        th, td { text-align: left; padding: .5rem .75rem; border-bottom: 1px solid #8884; vertical-align: top; }
        th { width: 38%; white-space: nowrap; }
        .ok { color: #2e7d32; font-weight: 600; }
        .err { color: #c62828; font-weight: 600; }
        code { background: #8882; padding: .1rem .35rem; border-radius: 4px; }
        .card { border: 1px solid #8884; border-radius: 10px; padding: 1rem 1.25rem; margin: 1.25rem 0; }
        a.btn { display: inline-block; padding: .5rem .9rem; border: 1px solid #8886;
                border-radius: 8px; text-decoration: none; }
    </style>
</head>
<body>
    <h1>✅ <?= e($projectName) ?></h1>
    <p class="muted">Docker-based local PHP development stack.</p>

    <div class="card">
        <h2>Environment</h2>
        <table>
            <tr><th>Project</th><td><?= e($projectName) ?></td></tr>
            <tr><th>Host / domain</th><td><code><?= e($host) ?></code></td></tr>
            <tr><th>PHP version</th><td><?= e($phpVersion) ?></td></tr>
        </table>
    </div>

    <div class="card">
        <h2>MySQL connection</h2>
        <table>
            <tr><th>Host</th><td><code><?= e($dbHost) ?></code></td></tr>
            <tr><th>Port</th><td><code><?= e((string)$dbPort) ?></code></td></tr>
            <tr><th>Database</th><td><code><?= e($dbName) ?></code></td></tr>
            <tr><th>User</th><td><code><?= e($dbUser) ?></code></td></tr>
            <tr><th>Status</th>
                <td class="<?= $dbOk ? 'ok' : 'err' ?>"><?= e($dbStatus) ?></td></tr>
        </table>
    </div>

    <div class="card">
        <h2>Mailpit (local email testing)</h2>
        <table>
            <tr><th>SMTP host</th><td><code><?= e($mailHost) ?></code></td></tr>
            <tr><th>SMTP port</th><td><code><?= e((string)$mailPort) ?></code></td></tr>
            <tr><th>Web UI</th><td><a href="http://<?= e($mailUiHost) ?>" target="_blank">http://<?= e($mailUiHost) ?></a></td></tr>
        </table>
        <p>
            Configure your app's SMTP to <code><?= e($mailHost) ?>:<?= e((string)$mailPort) ?></code>
            (no auth, no TLS). PHP's built-in <code>mail()</code> is already routed to Mailpit.
        </p>
        <?php if ($mailStatus !== ''): ?>
            <p class="<?= $mailSent ? 'ok' : 'err' ?>"><?= e($mailStatus) ?></p>
        <?php endif; ?>
        <p><a class="btn" href="?sendmail=1">Send a test email</a></p>
    </div>

    <p class="muted">For local development only — Mailpit does not deliver real email.</p>
</body>
</html>
