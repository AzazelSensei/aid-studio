import React from 'react';
import { Collapse, Form, Select, Space, Tabs, Tag, Typography } from 'antd';
import { BusinessDefaults } from '../aimanage/ModelBusinessBindingEditor';
import type { BusinessModelBinding } from '../aimanage/ModelBusinessBindingEditor';
import type { ModelCapabilityDefinition } from '../aimanage/modelDefinition';
import type { PoolModel } from './ModelPoolSelector';
import { usesStructuredCapabilities } from './functionCapabilityBindings';

export default function FunctionCapabilityEditor({ models, value, onChange, activeModel, onActiveModelChange }: { models: PoolModel[]; value: BusinessModelBinding[]; onChange: (next: BusinessModelBinding[]) => void; activeModel?: number; onActiveModelChange: (id?: number) => void }) {
  const configurable = models.filter(usesStructuredCapabilities);
  if (!configurable.length) return null;
  return <section aria-label="模型业务能力" style={{ marginTop: 16 }}>
    <Typography.Paragraph type="secondary">模型业务能力 · {configurable.length} 个模型。点击模型展开配置，每次只展开一个；收起不会丢失修改。</Typography.Paragraph>
    <Collapse accordion activeKey={activeModel == null ? [] : [String(activeModel)]} onChange={(keys) => {
      const key = Array.isArray(keys) ? keys[0] : keys;
      onActiveModelChange(key ? Number(key) : undefined);
    }} items={configurable.map((model) => {
    const capabilities: ModelCapabilityDefinition[] = model.capabilities || [];
    const selected = value.filter((row) => row.modelId === model.id);
    const replace = (rows: BusinessModelBinding[]) => onChange([...value.filter((row) => row.modelId !== model.id), ...rows]);
    const defaults = selected.filter((row) => row.defaultCapability);
    const valid = selected.length > 0 && defaults.length === 1;
    const defaultLabel = capabilities.find((item) => item.code === defaults[0]?.capabilityCode)?.label;
    return { key: String(model.id), label: <Space wrap><span id={`model-capability-${model.id}`}>{model.modelName}</span><Tag color={valid ? 'green' : 'error'}>{valid ? `已选 ${selected.length} 项 · 默认：${defaultLabel || defaults[0].capabilityCode}` : '待配置能力及默认值'}</Tag></Space>, children: <>
      <Form.Item label="业务允许的能力" required><Select mode="multiple" value={selected.map((row) => row.capabilityCode)} options={capabilities.map((capability) => ({ value: capability.code, label: capability.label, disabled: !capability.enabled }))} onChange={(codes: string[]) => replace(codes.map((code) => selected.find((row) => row.capabilityCode === code) || { modelId: model.id, funcCode: '', capabilityCode: code, defaultCapability: codes.length === 1 }))} /></Form.Item>
      <Form.Item label="默认能力" required><Select value={selected.find((row) => row.defaultCapability)?.capabilityCode} options={selected.map((row) => ({ value: row.capabilityCode, label: capabilities.find((capability) => capability.code === row.capabilityCode)?.label || row.capabilityCode }))} onChange={(code) => replace(selected.map((row) => ({ ...row, defaultCapability: row.capabilityCode === code })))} /></Form.Item>
      {selected.some((row) => capabilities.find((item) => item.code === row.capabilityCode)?.parameters.length) && <Collapse
        key={model.id} size="small" items={[{ key: 'parameters', label: '生成默认参数（可选，展开后按能力配置）', children: <Tabs items={selected.flatMap((row) => {
        const capability = capabilities.find((item) => item.code === row.capabilityCode);
        if (!capability?.parameters.length) return [];
        return [{ key: row.capabilityCode, label: capability.label, children: <BusinessDefaults definition={capability} value={row.defaultsJson} onChange={(defaultsJson) => replace(selected.map((item) => item === row ? { ...item, defaultsJson } : item))} /> }];
      })} /> }]} />}
    </> };
  })} />
  </section>;
}
