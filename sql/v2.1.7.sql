-- v2.1.7：修复模型真实标识变更后仍沿用平台模型编码的协议绑定。
-- 只更新原上游调用标识等于平台模型编码的绑定；独立 Endpoint ID 不受影响。
-- MySQL 5.7 兼容，可重复执行，不修改已创建任务的路由快照。
UPDATE `aid_ai_model_protocol_binding` AS `binding`
JOIN `aid_ai_model` AS `model` ON `model`.`id` = `binding`.`model_id`
SET `binding`.`definition_json` = JSON_SET(
  `binding`.`definition_json`, '$.upstreamModel', TRIM(`model`.`real_model_code`)),
  `binding`.`update_time` = NOW(),
  `binding`.`update_by` = 'system'
WHERE `model`.`real_model_code` IS NOT NULL
  AND TRIM(`model`.`real_model_code`) <> ''
  AND BINARY TRIM(`model`.`real_model_code`) <> BINARY `model`.`model_code`
  AND JSON_VALID(`binding`.`definition_json`)
  AND BINARY JSON_UNQUOTE(JSON_EXTRACT(
    IF(JSON_VALID(`binding`.`definition_json`), `binding`.`definition_json`, '{}'),
    '$.upstreamModel')) = BINARY `model`.`model_code`;
