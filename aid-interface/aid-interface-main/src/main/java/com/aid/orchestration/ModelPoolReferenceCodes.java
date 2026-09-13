package com.aid.orchestration;

import com.aid.aid.domain.AidAiModel;
import com.aid.aid.domain.AidAiModelAlias;
import com.aid.aid.mapper.AidAiModelAliasMapper;
import com.aid.aid.service.IAidAiModelService;
import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/** 汇总模型当前标识和兼容旧标识，供业务引用检查与迁移共用。 */
@Service
@RequiredArgsConstructor
public class ModelPoolReferenceCodes {
    private final IAidAiModelService models;
    private final AidAiModelAliasMapper aliases;

    public List<String> resolve(Collection<Long> ids) {
        if (ids.isEmpty()) return List.of();
        var codes = new LinkedHashSet<String>();
        models.list(Wrappers.<AidAiModel>lambdaQuery().select(AidAiModel::getModelCode)
                .in(AidAiModel::getId, ids)).forEach(model -> codes.add(model.getModelCode()));
        aliases.selectList(Wrappers.<AidAiModelAlias>lambdaQuery().select(AidAiModelAlias::getLegacyModelCode)
                .in(AidAiModelAlias::getModelId, ids)).forEach(alias -> codes.add(alias.getLegacyModelCode()));
        return codes.stream().filter(code -> code != null && !code.isBlank()).toList();
    }
}
