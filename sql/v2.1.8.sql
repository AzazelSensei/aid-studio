-- v2.1.8：允许复用已删除模型编码及后台删除用户的联系方式；兼容 MySQL 5.7，重复执行安全。
SET @aid_has_active_model_code := (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'aid_ai_model' AND COLUMN_NAME = 'active_model_code'
);
SET @aid_sql := IF(@aid_has_active_model_code = 0,
    'ALTER TABLE `aid_ai_model` ADD COLUMN `active_model_code` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci GENERATED ALWAYS AS (CASE WHEN `del_flag` = ''0'' THEN `model_code` ELSE NULL END) VIRTUAL',
    'SELECT 1');
PREPARE aid_stmt FROM @aid_sql;
EXECUTE aid_stmt;
DEALLOCATE PREPARE aid_stmt;

SET @aid_has_active_model_index := (
    SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'aid_ai_model' AND INDEX_NAME = 'uk_aid_ai_model_active_code'
);
SET @aid_sql := IF(@aid_has_active_model_index = 0,
    'ALTER TABLE `aid_ai_model` ADD UNIQUE INDEX `uk_aid_ai_model_active_code` (`active_model_code`)',
    'SELECT 1');
PREPARE aid_stmt FROM @aid_sql;
EXECUTE aid_stmt;
DEALLOCATE PREPARE aid_stmt;

SET @aid_has_legacy_model_index := (
    SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'aid_ai_model' AND INDEX_NAME = 'uk_aid_ai_model_model_code'
);
SET @aid_sql := IF(@aid_has_legacy_model_index > 0,
    'ALTER TABLE `aid_ai_model` DROP INDEX `uk_aid_ai_model_model_code`',
    'SELECT 1');
PREPARE aid_stmt FROM @aid_sql;
EXECUTE aid_stmt;
DEALLOCATE PREPARE aid_stmt;

-- 保留按 model_code 查询的索引能力，不让软删除历史导致常用查找全表扫描。
SET @aid_has_model_lookup_index := (
    SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'aid_ai_model' AND INDEX_NAME = 'idx_aid_ai_model_model_code'
);
SET @aid_sql := IF(@aid_has_model_lookup_index = 0,
    'ALTER TABLE `aid_ai_model` ADD INDEX `idx_aid_ai_model_model_code` (`model_code`)',
    'SELECT 1');
PREPARE aid_stmt FROM @aid_sql;
EXECUTE aid_stmt;
DEALLOCATE PREPARE aid_stmt;

-- 已逻辑删除的账号释放联系方式；历史业务记录仍按 user_id 保留。
UPDATE `sys_user`
SET `phonenumber` = NULL, `email` = NULL,
    `update_by` = 'system', `update_time` = NOW()
WHERE `del_flag` = '2' AND (`phonenumber` IS NOT NULL OR `email` IS NOT NULL);
