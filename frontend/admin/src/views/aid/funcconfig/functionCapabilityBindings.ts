import type { BusinessModelBinding } from '../aimanage/ModelBusinessBindingEditor';
import type { PoolModel } from './ModelPoolSelector';

export function usesStructuredCapabilities(model: PoolModel) {
  return model.structuredCapabilities === true;
}

export function normalizeFunctionCapabilityBindings(
  models: PoolModel[],
  bindings: BusinessModelBinding[]
) {
  const selectedIds = new Set(models.map((model) => model.id));
  const retained = bindings.filter((binding) => binding.modelId != null && selectedIds.has(binding.modelId));

  for (const model of models.filter(usesStructuredCapabilities)) {
    const capabilities = (model.capabilities || []).filter((capability: { enabled?: boolean }) => capability.enabled);
    const allowedCodes = new Set(capabilities.map((capability: { code: string }) => capability.code));
    const seen = new Set<string>();
    let rows = retained
      .filter((binding) => binding.modelId === model.id && allowedCodes.has(binding.capabilityCode))
      .filter((binding) => !seen.has(binding.capabilityCode) && seen.add(binding.capabilityCode));

    if (rows.filter((binding) => binding.defaultCapability).length !== 1) {
      const declaredDefaults = capabilities.filter((capability: { defaultCapability?: boolean }) => capability.defaultCapability);
      const declaredDefaultCode = declaredDefaults.length === 1 ? declaredDefaults[0].code : undefined;
      const fallbackCode = rows.length === 0
        ? declaredDefaultCode || (capabilities.length === 1 ? capabilities[0].code : undefined)
        : rows.length === 1
          ? rows[0].capabilityCode
          : declaredDefaultCode && rows.some((binding) => binding.capabilityCode === declaredDefaultCode)
            ? declaredDefaultCode
            : undefined;
      if (fallbackCode) {
        if (!rows.some((binding) => binding.capabilityCode === fallbackCode)) {
          rows = [...rows, {
            modelId: model.id,
            funcCode: '',
            capabilityCode: fallbackCode,
            defaultCapability: true
          }];
        } else {
          rows = rows.map((binding) => ({
            ...binding,
            defaultCapability: binding.capabilityCode === fallbackCode
          }));
        }
      }
    }

    const otherModelRows = retained.filter((binding) => binding.modelId !== model.id);
    retained.splice(0, retained.length, ...otherModelRows, ...rows);
  }
  return retained;
}
