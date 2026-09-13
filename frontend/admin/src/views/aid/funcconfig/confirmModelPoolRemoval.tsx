import React from 'react';
import { Alert, Form, Modal, Select, Typography, message } from 'antd';
import { request } from '@/utils/request';
import { getToken } from '@/utils/auth';

interface RemovalPreview {
  poolId: number;
  poolName: string;
  agentCount: number;
  matrixCount: number;
  projectCount: number;
  replacements: { value: string; label: string }[];
}
const pending = new Map<string, Promise<any>>();

/** 移出入口共用只读影响预览与明确的业务内替换确认。 */
export async function confirmModelPoolRemoval(modelIds: number[], poolIds: number[], retainedCodes?: string[]): Promise<Record<number, string> | undefined> {
  if (!modelIds.length || !poolIds.length) return {};
  const data = { modelIds: [...new Set(modelIds)].sort((a, b) => a - b), poolIds: [...new Set(poolIds)].sort((a, b) => a - b) };
  const key = `${getToken()}:${JSON.stringify(data)}`;
  let running = pending.get(key);
  if (!running) {
    running = request({ url: '/aid/aidmodel/pool-bindings/removal-preview', method: 'post', data }).finally(() => pending.delete(key));
    pending.set(key, running);
  }
  const response: any = await running;
  const rows: RemovalPreview[] = response.data || [];
  if (rows.length !== data.poolIds.length) throw new Error('模型池已变化，请重新打开');
  const affected = rows.filter((row) => row.agentCount + row.matrixCount + row.projectCount > 0).map((row) => ({
    ...row, replacements: row.replacements.filter((option) => !retainedCodes || retainedCodes.includes(option.value))
  }));
  if (!affected.length) return {};
  const replacements: Record<number, string> = {};
  return new Promise((resolve) => {
    Modal.confirm({
      title: '确认替换当前业务引用后移出', width: 640,
      okText: '替换引用并移出', cancelText: '取消',
      okButtonProps: { disabled: affected.some((row) => !row.replacements.length) },
      content: <div style={{ maxHeight: '60vh', overflowY: 'auto' }}>
        <Alert type="warning" showIcon message="只迁移以下业务中的模型引用。不会下线模型、修改其他业务池或历史任务；替换会影响后续生成效果及费用。" style={{ marginBottom: 16 }} />
        {affected.map((row) => <section key={row.poolId}>
          <Typography.Text strong>{row.poolName}</Typography.Text>
          <Typography.Paragraph>智能体 {row.agentCount} 条 · 矩阵 {row.matrixCount} 条 · 项目 {row.projectCount} 条</Typography.Paragraph>
          {row.replacements.length ? <Form.Item label="池内替代文本模型" required>
            <Select aria-label={`${row.poolName}的替代模型`} style={{ width: '100%' }} showSearch optionFilterProp="label"
              placeholder="请选择，不会自动指定" options={row.replacements} onChange={(code) => { replacements[row.poolId] = code; }} />
          </Form.Item> : <Alert type="error" message="没有可用的池内替代文本模型，请先调整当前业务引用或配置可用文本模型。" />}
        </section>)}
      </div>,
      onOk: () => {
        if (affected.some((row) => !replacements[row.poolId])) {
          message.error('请为每个业务选择替代模型');
          return Promise.reject(new Error('请选择替代模型'));
        }
        resolve(replacements);
      },
      onCancel: () => resolve(undefined)
    });
  });
}
