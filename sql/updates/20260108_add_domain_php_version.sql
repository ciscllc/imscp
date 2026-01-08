-- Add domain_php_version column to store per-domain PHP version selection
-- Run this migration on MySQL/MariaDB
ALTER TABLE `domain`
  ADD COLUMN `domain_php_version` VARCHAR(32) NOT NULL DEFAULT '' AFTER `domain_php`;
