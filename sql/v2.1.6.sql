-- v2.1.6：菜单名称统一使用 utf8mb4，保留已有菜单数据和自定义配置。
-- 在目标数据库中执行；可重复执行，MySQL 5.7 兼容。
SET NAMES utf8mb4;
SET @aid_menu_name_charset := (
  SELECT CHARACTER_SET_NAME FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sys_menu' AND COLUMN_NAME = 'menu_name'
  LIMIT 1
);
SET @aid_menu_name_sql := IF(@aid_menu_name_charset IS NOT NULL AND @aid_menu_name_charset <> 'utf8mb4',
  'ALTER TABLE `sys_menu` MODIFY COLUMN `menu_name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL COMMENT ''菜单名称''',
  'SELECT ''sys_menu.menu_name already utf8mb4 or table absent''');
PREPARE aid_menu_name_stmt FROM @aid_menu_name_sql;
EXECUTE aid_menu_name_stmt;
DEALLOCATE PREPARE aid_menu_name_stmt;

-- 兼容早期库的媒体任务摘要列；完整请求始终保存在 request_json。
SET @aid_media_prompt_charset := (
  SELECT CHARACTER_SET_NAME FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'aid_media_task' AND COLUMN_NAME = 'prompt'
  LIMIT 1
);
SET @aid_media_prompt_sql := IF(@aid_media_prompt_charset IS NOT NULL AND @aid_media_prompt_charset <> 'utf8mb4',
  'ALTER TABLE `aid_media_task` MODIFY COLUMN `prompt` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL COMMENT ''提示词''',
  'SELECT ''aid_media_task.prompt already utf8mb4 or table absent''');
PREPARE aid_media_prompt_stmt FROM @aid_media_prompt_sql;
EXECUTE aid_media_prompt_stmt;
DEALLOCATE PREPARE aid_media_prompt_stmt;
