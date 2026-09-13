-- v2.1.3：补齐数据库迁移历史并修正 DeepSeek Flash 普通聊天路由与当前官方上游模型名。
-- 保留模型编码以兼容已发布 Skill 版本。
-- 不覆盖模型启停、密钥、网关、倍率、业务池或自定义计费。

CREATE TABLE IF NOT EXISTS `aid_schema_history` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键',
  `script_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL COMMENT '脚本文件名',
  `checksum` char(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL COMMENT '脚本内容SHA256',
  `status` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL COMMENT '执行状态 SUCCESS/FAILED',
  `error_message` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL COMMENT '失败原因',
  `executed_at` datetime NOT NULL COMMENT '执行时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_script_name` (`script_name`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=Dynamic COMMENT='数据库升级脚本执行记录（升级器维护）';

START TRANSACTION;

UPDATE aid_ai_model AS m
JOIN aid_ai_provider AS p ON p.id = m.provider_id
SET m.real_model_code = 'deepseek-flash',
    m.model_name = CASE
        WHEN m.model_name IN ('DeepSeek V4 Flash', 'DeepSeek V4.1 Flash') THEN 'DeepSeek V4.1 Flash'
        ELSE m.model_name
    END,
    m.api_suffix = '/chat/completions',
    m.remark = CASE
        WHEN m.remark IS NULL THEN NULL
        ELSE REPLACE(m.remark, 'DeepSeek V4 Flash', 'DeepSeek V4.1 Flash')
    END,
    m.config_version = COALESCE(m.config_version, 0) + 1,
    m.update_time = NOW(),
    m.update_by = 'system'
WHERE p.provider_code = 'deepseek'
  AND p.del_flag = '0'
  AND m.model_code = 'deepseek-flash'
  AND m.del_flag = '0'
  AND (
      COALESCE(m.real_model_code, '') <> 'deepseek-flash'
      OR COALESCE(m.api_suffix, '') <> '/chat/completions'
      OR m.model_name = 'DeepSeek V4 Flash'
      OR COALESCE(m.remark, '') LIKE '%DeepSeek V4 Flash%'
  );

UPDATE aid_ai_model_protocol_binding AS b
JOIN aid_ai_model AS m ON m.id = b.model_id
JOIN aid_ai_provider AS p ON p.id = m.provider_id
SET b.definition_json = JSON_SET(
        b.definition_json,
        '$.upstreamModel', 'deepseek-flash',
        '$.apiSuffix', CASE
            WHEN b.capability_code = 'fim' OR b.protocol = 'deepseek:fim'
                THEN '/beta/completions'
            ELSE '/chat/completions'
        END
    ),
    b.update_time = NOW(),
    b.update_by = 'system'
WHERE p.provider_code = 'deepseek'
  AND p.del_flag = '0'
  AND m.model_code = 'deepseek-flash'
  AND m.del_flag = '0'
  AND JSON_VALID(b.definition_json)
  AND (
      COALESCE(JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.upstreamModel')), '') <> 'deepseek-flash'
      OR COALESCE(JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.apiSuffix')), '') <>
          CASE
              WHEN b.capability_code = 'fim' OR b.protocol = 'deepseek:fim'
                  THEN '/beta/completions'
              ELSE '/chat/completions'
          END
  );

COMMIT;
