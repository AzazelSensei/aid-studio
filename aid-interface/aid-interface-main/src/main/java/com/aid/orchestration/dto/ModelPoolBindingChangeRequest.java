package com.aid.orchestration.dto;

import java.util.List;

import lombok.Data;

/**
 * 模型与模型池批量关系变更请求。
 */
@Data
public class ModelPoolBindingChangeRequest
{
    /** 待处理模型主键。 */
    private List<Long> modelIds;

    /** 待处理模型池主键。 */
    private List<Long> poolIds;

    /** 新增关系的能力选择；旧客户端省略时由服务端按唯一能力或唯一默认能力安全选择。 */
    private List<ModelPoolCapabilitySelection> capabilitySelections;

    /** 移出文本模型时由管理员明确选择的池内替代模型，键为模型池 ID。 */
    private java.util.Map<Long, String> poolReplacementCodes;
}
