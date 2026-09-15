-- AID v2.1.5 公共增量：GPT-5.6 Sol 模型身份、官方计费基线与文本明确拒绝退款
-- MySQL 5.7；可重复执行。仅条件迁移内置旧基线，不覆盖站长自定义价格、网关、密钥、启停和模型池。

SET @aid_gpt56_model_id := (
    SELECT m.id
    FROM aid_ai_model AS m
    JOIN aid_ai_provider AS p ON p.id = m.provider_id
    WHERE p.provider_code = 'openai'
      AND p.del_flag = '0'
      AND m.model_code = 'gpt-5.6'
      AND m.del_flag = '0'
    ORDER BY m.id
    LIMIT 1
);

SET @aid_gpt56_new_skus := JSON_ARRAY(
    JSON_OBJECT(
        'match',JSON_OBJECT('inputTokensMin',0,'inputTokensMax',272000),
        'remark','官方当前价：输入 $4、缓存读取 $0.40、缓存写入 $5、输出 $20 每百万 Token；按互斥分桶结算',
        'enabled',TRUE,'skuCode','OPENAI_GPT56_STD','skuName','GPT-5.6 Sol 标准(≤272K)','priority',1,
        'inputPricePerMillion',28,'cachedInputPricePerMillion',2.8,
        'cacheWritePricePerMillion',35,'outputPricePerMillion',140,
        'reasoningPricePerMillion',140
    ),
    JSON_OBJECT(
        'match',JSON_OBJECT('inputTokensMin',272001,'inputTokensMax',100000000),
        'remark','官方长上下文价：输入 $8、缓存读取 $0.80、缓存写入 $10、输出 $30 每百万 Token；按互斥分桶结算',
        'enabled',TRUE,'skuCode','OPENAI_GPT56_LONG','skuName','GPT-5.6 Sol 长上下文(>272K)','priority',2,
        'inputPricePerMillion',56,'cachedInputPricePerMillion',5.6,
        'cacheWritePricePerMillion',70,'outputPricePerMillion',210,
        'reasoningPricePerMillion',210
    )
);

-- 只识别两种已经发布过的内置旧价格。任一价格、区间、缓存/推理字段或结算元数据被修改，均视为站长自定义。
SET @aid_gpt56_model_old_billing := COALESCE((
    SELECT IF(
        JSON_VALID(m.billing_rule_json)
        AND JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.mode')) = 'SKU'
        AND JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.preHold')) = 'true'
        AND JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.meterType')) = 'TOKEN'
        AND JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.chargeType')) = 'TEXT'
        AND JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.matchStrategy')) = 'FIRST_HIT'
        AND JSON_LENGTH(JSON_EXTRACT(m.billing_rule_json, '$.params')) = 0
        AND JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.settleRule.settleMode')) = 'REFUND_ONLY'
        AND JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.settleRule.allowRefund')) = 'true'
        AND JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.settleRule.usageSource')) = 'PROVIDER_USAGE'
        AND JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.settleRule.allowExtraCharge')) = 'false'
        AND CAST(JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.settleRule.charToTokenRatio')) AS DECIMAL(20,6)) = 2
        AND (
            (
                JSON_LENGTH(JSON_EXTRACT(m.billing_rule_json, '$.skus')) = 1
                AND JSON_LENGTH(JSON_EXTRACT(m.billing_rule_json, '$.skus[0]')) = 11
                AND JSON_LENGTH(JSON_EXTRACT(m.billing_rule_json, '$.skus[0].match')) = 2
                AND JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.skus[0].skuCode')) = 'OPENAI_GPT56_STD'
                AND JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.skus[0].skuName')) = 'GPT-5.6 Standard'
                AND JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.skus[0].remark')) = '官方 Standard：输入 $5、缓存读取 $0.5、缓存写入 $6.25、输出 $30 每百万 Token；按互斥分桶结算'
                AND JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.skus[0].enabled')) = 'true'
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.skus[0].priority')) AS UNSIGNED) = 1
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.skus[0].match.inputTokensMin')) AS UNSIGNED) = 0
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.skus[0].match.inputTokensMax')) AS UNSIGNED) = 100000000
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.skus[0].inputPricePerMillion')) AS DECIMAL(20,6)) = 35
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.skus[0].cachedInputPricePerMillion')) AS DECIMAL(20,6)) = 3.5
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.skus[0].cacheWritePricePerMillion')) AS DECIMAL(20,6)) = 43.75
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.skus[0].outputPricePerMillion')) AS DECIMAL(20,6)) = 210
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.skus[0].reasoningPricePerMillion')) AS DECIMAL(20,6)) = 210
                AND JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.settleRule.usagePricingMode')) = 'BUCKETED'
            )
            OR
            (
                JSON_LENGTH(JSON_EXTRACT(m.billing_rule_json, '$.skus')) = 2
                AND JSON_LENGTH(JSON_EXTRACT(m.billing_rule_json, '$.skus[0]')) = 8
                AND JSON_LENGTH(JSON_EXTRACT(m.billing_rule_json, '$.skus[0].match')) = 2
                AND JSON_LENGTH(JSON_EXTRACT(m.billing_rule_json, '$.skus[1]')) = 8
                AND JSON_LENGTH(JSON_EXTRACT(m.billing_rule_json, '$.skus[1].match')) = 2
                AND JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.skus[0].skuCode')) = 'OPENAI_GPT56_STD'
                AND JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.skus[0].skuName')) = 'GPT-5.6 标准(≤272K)'
                AND JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.skus[0].remark')) = '官方Standard原价input $5/output $30每百万Token=3500/21000 Credits'
                AND JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.skus[0].enabled')) = 'true'
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.skus[0].priority')) AS UNSIGNED) = 1
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.skus[0].match.inputTokensMin')) AS UNSIGNED) = 0
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.skus[0].match.inputTokensMax')) AS UNSIGNED) = 272000
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.skus[0].inputPricePerMillion')) AS DECIMAL(20,6)) = 35
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.skus[0].outputPricePerMillion')) AS DECIMAL(20,6)) = 210
                AND JSON_EXTRACT(m.billing_rule_json, '$.skus[0].cachedInputPricePerMillion') IS NULL
                AND JSON_EXTRACT(m.billing_rule_json, '$.skus[0].cacheWritePricePerMillion') IS NULL
                AND JSON_EXTRACT(m.billing_rule_json, '$.skus[0].reasoningPricePerMillion') IS NULL
                AND JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.skus[1].skuCode')) = 'OPENAI_GPT56_LONG'
                AND JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.skus[1].skuName')) = 'GPT-5.6 长上下文(>272K)'
                AND JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.skus[1].remark')) = '官方长上下文input $6.25每百万Token=4375 Credits,输出定价表未分档按$30'
                AND JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.skus[1].enabled')) = 'true'
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.skus[1].priority')) AS UNSIGNED) = 2
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.skus[1].match.inputTokensMin')) AS UNSIGNED) = 272001
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.skus[1].match.inputTokensMax')) AS UNSIGNED) = 100000000
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.skus[1].inputPricePerMillion')) AS DECIMAL(20,6)) = 43.75
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(m.billing_rule_json, '$.skus[1].outputPricePerMillion')) AS DECIMAL(20,6)) = 210
                AND JSON_EXTRACT(m.billing_rule_json, '$.skus[1].cachedInputPricePerMillion') IS NULL
                AND JSON_EXTRACT(m.billing_rule_json, '$.skus[1].cacheWritePricePerMillion') IS NULL
                AND JSON_EXTRACT(m.billing_rule_json, '$.skus[1].reasoningPricePerMillion') IS NULL
                AND JSON_EXTRACT(m.billing_rule_json, '$.settleRule.usagePricingMode') IS NULL
            )
        ),
        1, 0
    )
    FROM aid_ai_model AS m
    WHERE m.id = @aid_gpt56_model_id
), 0);

SET @aid_gpt56_model_billing_hash := COALESCE((
    SELECT SHA2(COALESCE(m.billing_rule_json, ''), 256)
    FROM aid_ai_model AS m
    WHERE m.id = @aid_gpt56_model_id
), '');

SET @aid_gpt56_route_id := (
    SELECT b.id
    FROM aid_ai_model_protocol_binding AS b
    WHERE b.model_id = @aid_gpt56_model_id
      AND b.binding_code = 'route_94'
    ORDER BY b.id
    LIMIT 1
);

SET @aid_gpt56_route_old_billing := COALESCE((
    SELECT IF(
        JSON_VALID(b.definition_json)
        AND JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.mode')) = 'SKU'
        AND JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.preHold')) = 'true'
        AND JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.meterType')) = 'TOKEN'
        AND JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.chargeType')) = 'TEXT'
        AND JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.matchStrategy')) = 'FIRST_HIT'
        AND JSON_LENGTH(JSON_EXTRACT(b.definition_json, '$.billingRule.params')) = 0
        AND JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.settleRule.settleMode')) = 'REFUND_ONLY'
        AND JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.settleRule.allowRefund')) = 'true'
        AND JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.settleRule.usageSource')) = 'PROVIDER_USAGE'
        AND JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.settleRule.allowExtraCharge')) = 'false'
        AND CAST(JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.settleRule.charToTokenRatio')) AS DECIMAL(20,6)) = 2
        AND (
            (
                JSON_LENGTH(JSON_EXTRACT(b.definition_json, '$.billingRule.skus')) = 1
                AND JSON_LENGTH(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[0]')) = 11
                AND JSON_LENGTH(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[0].match')) = 2
                AND JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[0].skuCode')) = 'OPENAI_GPT56_STD'
                AND JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[0].skuName')) = 'GPT-5.6 Standard'
                AND JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[0].remark')) = '官方 Standard：输入 $5、缓存读取 $0.5、缓存写入 $6.25、输出 $30 每百万 Token；按互斥分桶结算'
                AND JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[0].enabled')) = 'true'
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[0].priority')) AS UNSIGNED) = 1
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[0].match.inputTokensMin')) AS UNSIGNED) = 0
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[0].match.inputTokensMax')) AS UNSIGNED) = 100000000
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[0].inputPricePerMillion')) AS DECIMAL(20,6)) = 35
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[0].cachedInputPricePerMillion')) AS DECIMAL(20,6)) = 3.5
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[0].cacheWritePricePerMillion')) AS DECIMAL(20,6)) = 43.75
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[0].outputPricePerMillion')) AS DECIMAL(20,6)) = 210
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[0].reasoningPricePerMillion')) AS DECIMAL(20,6)) = 210
                AND JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.settleRule.usagePricingMode')) = 'BUCKETED'
            )
            OR
            (
                JSON_LENGTH(JSON_EXTRACT(b.definition_json, '$.billingRule.skus')) = 2
                AND JSON_LENGTH(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[0]')) = 8
                AND JSON_LENGTH(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[0].match')) = 2
                AND JSON_LENGTH(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[1]')) = 8
                AND JSON_LENGTH(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[1].match')) = 2
                AND JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[0].skuCode')) = 'OPENAI_GPT56_STD'
                AND JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[0].skuName')) = 'GPT-5.6 标准(≤272K)'
                AND JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[0].remark')) = '官方Standard原价input $5/output $30每百万Token=3500/21000 Credits'
                AND JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[0].enabled')) = 'true'
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[0].priority')) AS UNSIGNED) = 1
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[0].match.inputTokensMin')) AS UNSIGNED) = 0
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[0].match.inputTokensMax')) AS UNSIGNED) = 272000
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[0].inputPricePerMillion')) AS DECIMAL(20,6)) = 35
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[0].outputPricePerMillion')) AS DECIMAL(20,6)) = 210
                AND JSON_EXTRACT(b.definition_json, '$.billingRule.skus[0].cachedInputPricePerMillion') IS NULL
                AND JSON_EXTRACT(b.definition_json, '$.billingRule.skus[0].cacheWritePricePerMillion') IS NULL
                AND JSON_EXTRACT(b.definition_json, '$.billingRule.skus[0].reasoningPricePerMillion') IS NULL
                AND JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[1].skuCode')) = 'OPENAI_GPT56_LONG'
                AND JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[1].skuName')) = 'GPT-5.6 长上下文(>272K)'
                AND JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[1].remark')) = '官方长上下文input $6.25每百万Token=4375 Credits,输出定价表未分档按$30'
                AND JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[1].enabled')) = 'true'
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[1].priority')) AS UNSIGNED) = 2
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[1].match.inputTokensMin')) AS UNSIGNED) = 272001
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[1].match.inputTokensMax')) AS UNSIGNED) = 100000000
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[1].inputPricePerMillion')) AS DECIMAL(20,6)) = 43.75
                AND CAST(JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.billingRule.skus[1].outputPricePerMillion')) AS DECIMAL(20,6)) = 210
                AND JSON_EXTRACT(b.definition_json, '$.billingRule.skus[1].cachedInputPricePerMillion') IS NULL
                AND JSON_EXTRACT(b.definition_json, '$.billingRule.skus[1].cacheWritePricePerMillion') IS NULL
                AND JSON_EXTRACT(b.definition_json, '$.billingRule.skus[1].reasoningPricePerMillion') IS NULL
                AND JSON_EXTRACT(b.definition_json, '$.billingRule.settleRule.usagePricingMode') IS NULL
            )
        ),
        1, 0
    )
    FROM aid_ai_model_protocol_binding AS b
    WHERE b.id = @aid_gpt56_route_id
), 0);

SET @aid_gpt56_route_hash := COALESCE((
    SELECT SHA2(COALESCE(b.definition_json, ''), 256)
    FROM aid_ai_model_protocol_binding AS b
    WHERE b.id = @aid_gpt56_route_id
), '');

START TRANSACTION;

UPDATE aid_ai_model AS m
SET m.real_model_code = CASE
        WHEN COALESCE(m.real_model_code, '') IN ('', 'gpt-5.6') THEN 'gpt-5.6-sol'
        ELSE m.real_model_code
    END,
    m.model_name = CASE
        WHEN COALESCE(m.model_name, '') IN ('', 'GPT-5.6') THEN 'GPT-5.6 Sol'
        ELSE m.model_name
    END,
    m.remark = CASE
        WHEN COALESCE(m.remark, '') = ''
            THEN 'GPT-5.6 Sol；平台稳定编码保留 gpt-5.6，真实上游使用 gpt-5.6-sol；官方当前价按 ≤272K 与 >272K 两档配置；支持可配置思考档位；保持停用'
        ELSE m.remark
    END,
    m.config_version = COALESCE(m.config_version, 0) + 1,
    m.update_time = NOW(),
    m.update_by = 'system'
WHERE m.id = @aid_gpt56_model_id
  AND (
      COALESCE(m.real_model_code, '') IN ('', 'gpt-5.6')
      OR COALESCE(m.model_name, '') IN ('', 'GPT-5.6')
  );
SET @aid_gpt56_model_config_changed := ROW_COUNT();

UPDATE aid_ai_model AS m
SET m.billing_rule_json = JSON_SET(
        m.billing_rule_json,
        '$.skus',JSON_EXTRACT(@aid_gpt56_new_skus, '$'),
        '$.settleRule.usagePricingMode','BUCKETED'
    ),
    m.billing_version = COALESCE(m.billing_version, 0) + 1,
    m.update_time = NOW(),
    m.update_by = 'system'
WHERE m.id = @aid_gpt56_model_id
  AND @aid_gpt56_model_old_billing = 1
  AND SHA2(COALESCE(m.billing_rule_json, ''), 256) = @aid_gpt56_model_billing_hash;
SET @aid_gpt56_model_billing_changed := ROW_COUNT();

UPDATE aid_ai_model_protocol_binding AS b
SET b.definition_json = JSON_SET(
        b.definition_json,
        '$.billingRule.skus',JSON_EXTRACT(@aid_gpt56_new_skus, '$'),
        '$.billingRule.settleRule.usagePricingMode','BUCKETED'
    ),
    b.update_time = NOW(),
    b.update_by = 'system'
WHERE b.id = @aid_gpt56_route_id
  AND @aid_gpt56_route_old_billing = 1
  AND SHA2(COALESCE(b.definition_json, ''), 256) = @aid_gpt56_route_hash;
SET @aid_gpt56_route_billing_changed := ROW_COUNT();

UPDATE aid_ai_model_protocol_binding AS b
SET b.definition_json = JSON_SET(
        b.definition_json,
        '$.upstreamModel','gpt-5.6-sol'
    ),
    b.update_time = NOW(),
    b.update_by = 'system'
WHERE b.id = @aid_gpt56_route_id
  AND JSON_VALID(b.definition_json)
  AND COALESCE(JSON_UNQUOTE(JSON_EXTRACT(b.definition_json, '$.upstreamModel')), '') IN ('', 'gpt-5.6');
SET @aid_gpt56_route_config_changed := ROW_COUNT();

UPDATE aid_ai_model AS m
SET m.config_version = COALESCE(m.config_version, 0) + 1,
    m.update_time = NOW(),
    m.update_by = 'system'
WHERE m.id = @aid_gpt56_model_id
  AND @aid_gpt56_model_config_changed = 0
  AND @aid_gpt56_route_config_changed > 0;

UPDATE aid_ai_model AS m
SET m.billing_version = COALESCE(m.billing_version, 0) + 1,
    m.update_time = NOW(),
    m.update_by = 'system'
WHERE m.id = @aid_gpt56_model_id
  AND @aid_gpt56_model_billing_changed = 0
  AND @aid_gpt56_route_billing_changed > 0;

-- 早期安装链只创建了结构化能力表，但没有为既有 GPT-5.6 回填能力、协议绑定和别名。
-- 仅在对应记录缺失时补齐；现有记录（包括站长自定义路由）保持不变。
SET @aid_gpt56_capability_definition := JSON_OBJECT(
    'sceneRules', JSON_OBJECT(
        'textOnly', JSON_OBJECT(
            'supportsDuration', FALSE,
            'supportsSizePreset', FALSE,
            'supportsAspectRatio', FALSE
        )
    ),
    'maxInputAudios', 0,
    'maxInputImages', 10,
    'maxInputVideos', 0,
    'inputModalities', JSON_ARRAY('TEXT', 'IMAGE'),
    'maxOutputTokens', 128000,
    'outputModalities', JSON_ARRAY('TEXT'),
    'inputImageFormats', JSON_ARRAY('jpeg', 'jpg', 'png', 'webp', 'gif'),
    'maxInputDocuments', 0,
    'reasoningApiStyle', 'OPENAI',
    'supportsReasoning', TRUE,
    'supportsAudioInput', FALSE,
    'supportsImageInput', TRUE,
    'supportsJsonObject', TRUE,
    'supportsVideoInput', FALSE,
    'contextWindowTokens', 1050000,
    'outputTokenApiField', 'max_completion_tokens',
    'capabilitySourceUrls', JSON_ARRAY('https://developers.openai.com/api/docs/models/gpt-5.6-sol'),
    'capabilityVerifiedAt', '2026-09-15',
    'defaultReasoningLevel', 'medium',
    'supportsDocumentInput', FALSE,
    'allowedReasoningLevels', JSON_ARRAY('low', 'medium', 'high', 'xhigh', 'max'),
    'defaultReasoningEnabled', FALSE,
    'maxInputImageFileSizeMb', 0,
    'returnsReasoningContent', FALSE,
    'supportsReasoningBudget', FALSE,
    'supportsReasoningContent', FALSE,
    'supportsReasoningDisable', TRUE,
    'supportsDuration', FALSE,
    'supportsSizePreset', FALSE,
    'supportsAspectRatio', FALSE
);

INSERT INTO aid_ai_model_capability
    (model_id, capability_code, generate_mode, definition_json, sort_order,
     create_time, create_by, update_time, update_by, remark)
SELECT m.id, 'text', 'text', @aid_gpt56_capability_definition, 0,
       NOW(), 'system', NULL, '', 'v2.1.5 兼容补齐'
FROM aid_ai_model AS m
JOIN aid_ai_provider AS p ON p.id = m.provider_id
WHERE p.provider_code = 'openai'
  AND p.del_flag = '0'
  AND m.model_code = 'gpt-5.6'
  AND m.del_flag = '0'
  AND NOT EXISTS (
      SELECT 1
      FROM aid_ai_model_capability AS c
      WHERE c.model_id = m.id
        AND c.capability_code = 'text'
  );

INSERT INTO aid_ai_model_protocol_binding
    (model_id, capability_code, binding_code, protocol, definition_json, sort_order,
     create_time, create_by, update_time, update_by, remark)
SELECT m.id, 'text', 'route_94', 'openai-compatible-text',
       JSON_OBJECT(
           'apiSuffix', '/v1/chat/completions',
           'billingMode', 'SKU',
           'billingRule', IF(
               JSON_VALID(m.billing_rule_json),
               CAST(m.billing_rule_json AS JSON),
               JSON_OBJECT()
           ),
           'capability', CAST(@aid_gpt56_capability_definition AS JSON),
           'code', 'route_94',
           'costCredits', m.cost_credits,
           'defaultBinding', TRUE,
           'enabled', TRUE,
           'fixedParameters', JSON_OBJECT(),
           'parameterMapping', JSON_OBJECT(),
           'presentation', JSON_OBJECT(
               'supportsLastFrame', FALSE,
               'supportsImageInput', TRUE,
               'supportsTextInput', TRUE,
               'supportsFirstFrame', FALSE,
               'supportsDuration', FALSE,
               'defaultOutputCount', 1,
               'maxOutputCount', 1,
               'supportsSystemPrompt', TRUE,
               'supportsSizePreset', FALSE,
               'supportsAspectRatio', FALSE,
               'supportsMultiImageInput', TRUE
           ),
           'protocol', 'openai-compatible-text',
           'upstreamModel', 'gpt-5.6-sol'
       ),
       0, NOW(), 'system', NULL, '', 'v2.1.5 兼容补齐'
FROM aid_ai_model AS m
JOIN aid_ai_provider AS p ON p.id = m.provider_id
WHERE p.provider_code = 'openai'
  AND p.del_flag = '0'
  AND m.model_code = 'gpt-5.6'
  AND m.del_flag = '0'
  AND NOT EXISTS (
      SELECT 1
      FROM aid_ai_model_protocol_binding AS b
      WHERE b.model_id = m.id
        AND b.capability_code = 'text'
        AND b.binding_code = 'route_94'
  );

INSERT INTO aid_ai_model_alias
    (legacy_model_id, legacy_model_code, model_id, capability_code, binding_code,
     create_time, create_by, update_time, update_by, remark)
SELECT m.id, 'gpt-5.6', m.id, 'text', 'route_94',
       NOW(), 'system', NULL, '', 'v2.1.5 兼容补齐'
FROM aid_ai_model AS m
JOIN aid_ai_provider AS p ON p.id = m.provider_id
WHERE p.provider_code = 'openai'
  AND p.del_flag = '0'
  AND m.model_code = 'gpt-5.6'
  AND m.del_flag = '0'
  AND NOT EXISTS (
      SELECT 1
      FROM aid_ai_model_alias AS a
      WHERE a.legacy_model_id = m.id
         OR a.legacy_model_code = 'gpt-5.6'
  );

COMMIT;
