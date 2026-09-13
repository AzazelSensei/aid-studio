package com.aid.orchestration;

import com.aid.aid.domain.AidAgent;
import com.aid.aid.domain.AidAiModel;
import com.aid.aid.domain.AidAiModelFuncConfig;
import com.aid.aid.domain.AidGenAgentPool;
import com.aid.aid.domain.AidProjectGenConfig;
import com.aid.aid.mapper.AidProjectGenConfigMapper;
import com.aid.aid.service.IAidAiModelFuncConfigService;
import com.aid.aid.service.IAidAiModelService;
import com.aid.aid.service.IAidGenAgentPoolService;
import com.aid.agent.IAidAgentService;
import com.aid.common.exception.ServiceException;
import com.aid.model.service.IAiModelBusinessService;
import com.aid.orchestration.dto.ModelPoolBindingChangeRequest;
import com.alibaba.fastjson2.JSON;
import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import java.util.ArrayList;
import java.util.List;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/** 只读预览模型移出业务池的引用及可用替代项。 */
@Service
@Slf4j
@RequiredArgsConstructor
public class ModelPoolRemovalPreviewService {
    private final IAidAiModelFuncConfigService functions;
    private final ModelPoolReferenceCodes referenceCodes;
    private final IAidAgentService agents;
    private final IAidGenAgentPoolService matrix;
    private final AidProjectGenConfigMapper projects;
    private final IAiModelBusinessService availableModels;

    @Data
    public static class Preview {
        private Long poolId;
        private String poolName;
        private long agentCount;
        private long matrixCount;
        private long projectCount;
        private List<Replacement> replacements = List.of();
    }

    public record Replacement(String value, String label) { }

    public List<Preview> preview(ModelPoolBindingChangeRequest request) {
        if (request == null || request.getModelIds() == null || request.getPoolIds() == null
                || request.getModelIds().isEmpty() || request.getPoolIds().isEmpty()
                || request.getModelIds().size() > 1000 || request.getPoolIds().size() > 100) {
            log.info("模型池移出预览参数无效");
            throw new ServiceException("请选择模型及业务池");
        }
        List<Preview> result = new ArrayList<>();
        for (AidAiModelFuncConfig pool : functions.list(Wrappers.<AidAiModelFuncConfig>lambdaQuery()
                .select(AidAiModelFuncConfig::getId, AidAiModelFuncConfig::getFuncCode, AidAiModelFuncConfig::getFuncName,
                        AidAiModelFuncConfig::getModelType, AidAiModelFuncConfig::getModelIds)
                .in(AidAiModelFuncConfig::getId, request.getPoolIds()).eq(AidAiModelFuncConfig::getDelFlag, "0"))) {
            List<Long> ids = pool.getModelIds() == null ? List.of() : JSON.parseArray(pool.getModelIds(), Long.class);
            List<Long> removed = ids.stream().filter(request.getModelIds()::contains).toList();
            Preview row = new Preview();
            row.setPoolId(pool.getId()); row.setPoolName(pool.getFuncName());
            if (!removed.isEmpty()) {
                List<String> codes = referenceCodes.resolve(removed);
                if (!codes.isEmpty()) {
                    row.setAgentCount(agents.count(Wrappers.<AidAgent>lambdaQuery().eq(AidAgent::getBizCategoryCode, pool.getFuncCode())
                            .in(AidAgent::getModelCode, codes).eq(AidAgent::getDelFlag, "0")));
                    row.setMatrixCount(matrix.count(Wrappers.<AidGenAgentPool>lambdaQuery().eq(AidGenAgentPool::getBizCategoryCode, pool.getFuncCode())
                            .in(AidGenAgentPool::getModelCode, codes).eq(AidGenAgentPool::getDelFlag, "0")));
                    row.setProjectCount(projects.selectCount(Wrappers.<AidProjectGenConfig>lambdaQuery().eq(AidProjectGenConfig::getSceneCode, pool.getFuncCode())
                            .in(AidProjectGenConfig::getModelCode, codes).eq(AidProjectGenConfig::getDelFlag, "0")));
                }
            }
            if ("text".equals(pool.getModelType()) && row.getAgentCount() + row.getMatrixCount() + row.getProjectCount() > 0)
                row.setReplacements(availableModels.listAvailableModelsByFuncCode(pool.getFuncCode()).stream()
                        .filter(m -> !removed.contains(m.getId()))
                        .map(m -> new Replacement(m.getModelCode(), m.getModelName())).toList());
            result.add(row);
        }
        return result;
    }
}
