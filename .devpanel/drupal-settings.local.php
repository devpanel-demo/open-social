<?php

// phpcs:ignoreFile

/**
 * There are some basic configuration created by DevPanel
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

$settings['file_private_path'] = dirname($app_root) . '/private';
$config['system.logging']['error_level'] = 'hide';
