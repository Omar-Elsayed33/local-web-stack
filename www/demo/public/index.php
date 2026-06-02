<?php
/**
 * local-web-stack — demo project (committed as an example).
 *
 * Any other folder you add under www/ is ignored by Git and served
 * automatically at http://<folder>.local. For local development only.
 */

$host       = $_SERVER['HTTP_HOST'] ?? 'unknown';
// All database values come from the environment (set in docker-compose.yml
// from .env), so any project can read them the same way.
$dbHost     = getenv('MYSQL_HOST') ?: 'mysql';
$dbPort     = getenv('MYSQL_PORT') ?: '3306';
$dbName     = getenv('MYSQL_DATABASE') ?: 'app';
$dbUser     = getenv('MYSQL_USER') ?: 'app';
$dbPass     = getenv('MYSQL_PASSWORD') ?: 'app';
$mailUiHost = getenv('MAILPIT_DOMAIN') ?: 'mail.local';

// Quick MySQL connectivity check.
$dbStatus = 'not tested';
try {
    $pdo = new PDO(
        "mysql:host={$dbHost};port={$dbPort};dbname={$dbName};charset=utf8mb4",
        $dbUser,
        $dbPass,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_TIMEOUT => 3]
    );
    $dbStatus = 'connected — MySQL ' . $pdo->query('SELECT VERSION()')->fetchColumn();
} catch (Throwable $e) {
    $dbStatus = 'failed — ' . $e->getMessage();
}

echo "<h1>Local Web Stack Demo</h1>";
echo "<p>If you can see this page, PHP is working.</p>";
echo "<ul>";
echo "<li><strong>Host:</strong> " . htmlspecialchars($host, ENT_QUOTES) . "</li>";
echo "<li><strong>PHP version:</strong> " . PHP_VERSION . "</li>";
echo "<li><strong>MySQL:</strong> " . htmlspecialchars($dbStatus, ENT_QUOTES) . "</li>";
echo "<li><strong>Mailpit UI:</strong> <a href=\"http://{$mailUiHost}\">http://{$mailUiHost}</a> "
   . "(SMTP: mailpit:1025)</li>";
echo "</ul>";
echo "<hr>";

phpinfo();
