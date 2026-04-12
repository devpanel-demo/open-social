<?php

// phpcs:ignoreFile

/**
 * Local overrides used by DevPanel-managed environments.
 *
 * This file is copied in after installation so runtime-specific values can be
 * changed without modifying the main settings.php template.
 */
$databases['default']['default'] = [
    'database'        => getenv('DB_NAME'),
    'username'        => getenv('DB_USER'),
    'password'        => getenv('DB_PASSWORD'),
    'host'            => getenv('DB_HOST'),
    'port'            => getenv('DB_PORT'),
    'driver'          => getenv('DB_DRIVER'),
    'prefix'          => '',
    'collation'       => 'utf8mb4_general_ci',
    'isolation_level' => 'REPEATABLE READ',
];

// Open Social requires a working private files path during install/runtime.
$settings['file_private_path'] = dirname($app_root) . '/private';

// Keep production-style error display disabled in the prepared image.
$config['system.logging']['error_level'] = 'hide';
ini_set('display_errors', '0');
ini_set('display_startup_errors', '0');
error_reporting(E_ALL & ~E_DEPRECATED & ~E_USER_DEPRECATED);

// DevPanel environments are dynamic, so keep host validation permissive here.
$settings['trusted_host_patterns'] = ['.*'];
