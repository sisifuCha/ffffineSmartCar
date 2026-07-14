/**
 * 传感器数据存储（HTTP 端口 5001 的 JSON 键值对数据）
 * 通过 AppStorage 驱动 UI 订阅更新
 */

/** 传感器条目 */
export interface SensorEntry {
  key: string;
  value: string;
}

export class SensorDataStore {
  static readonly KEY_RAW_JSON = 'sensor_raw_json';
  static readonly KEY_ENTRIES = 'sensor_entries';
  static readonly KEY_LAST_UPDATE = 'sensor_last_update';
  static readonly KEY_CONNECTED = 'sensor_connected';

  static init(): void {
    AppStorage.setOrCreate(SensorDataStore.KEY_RAW_JSON, '');
    AppStorage.setOrCreate(SensorDataStore.KEY_ENTRIES, []);
    AppStorage.setOrCreate(SensorDataStore.KEY_LAST_UPDATE, 0);
    AppStorage.setOrCreate(SensorDataStore.KEY_CONNECTED, false);
  }

  /**
   * 解析 JSON 键值对并更新 AppStorage。
   * @returns true 表示解析成功，false 表示不是有效 JSON
   */
  static updateFromJson(jsonStr: string): boolean {
    let obj: Record<string, Object> | undefined;

    // 尝试直接解析
    obj = SensorDataStore.tryParse(jsonStr);
    // 如果直接解析失败，尝试从响应中提取 JSON 子串（可能嵌在 HTML 里）
    if (!obj) {
      obj = SensorDataStore.extractJsonFromText(jsonStr);
    }
    if (!obj) {
      console.warn('SensorDataStore', 'not valid JSON');
      AppStorage.set(SensorDataStore.KEY_CONNECTED, false);
      return false;
    }

    AppStorage.set(SensorDataStore.KEY_RAW_JSON, jsonStr);
    AppStorage.set(SensorDataStore.KEY_LAST_UPDATE, Date.now());
    AppStorage.set(SensorDataStore.KEY_CONNECTED, true);

    const entries = SensorDataStore.flattenEntries(obj);
    AppStorage.set(SensorDataStore.KEY_ENTRIES, entries);
    console.info('SensorDataStore', 'entries', entries.length);
    return true;
  }

  private static tryParse(raw: string): Record<string, Object> | undefined {
    try {
      const trimmed = raw.trim();
      if (!trimmed.startsWith('{')) {
        return undefined;
      }
      const parsed = JSON.parse(trimmed) as Object;
      if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
        return undefined;
      }
      return parsed as Record<string, Object>;
    } catch (_e) {
      return undefined;
    }
  }

  /** 从可能混有 HTML 的文本中提取第一个 JSON 对象 */
  private static extractJsonFromText(text: string): Record<string, Object> | undefined {
    const start = text.indexOf('{');
    if (start < 0) {
      return undefined;
    }
    // 从第一个 { 开始，逐字符匹配括号深度
    let depth = 0;
    let inString = false;
    let escape = false;
    for (let i = start; i < text.length; i++) {
      const ch = text.charAt(i);
      if (escape) {
        escape = false;
        continue;
      }
      if (ch === '\\') {
        escape = true;
        continue;
      }
      if (ch === '"') {
        inString = !inString;
        continue;
      }
      if (inString) {
        continue;
      }
      if (ch === '{') {
        depth++;
      } else if (ch === '}') {
        depth--;
        if (depth === 0) {
          const candidate = text.substring(start, i + 1);
          try {
            const parsed = JSON.parse(candidate) as Object;
            if (typeof parsed === 'object' && parsed !== null && !Array.isArray(parsed)) {
              return parsed as Record<string, Object>;
            }
          } catch (_e) {
            // 继续找下一个 {
          }
          // 找下一个 {
          const nextStart = text.indexOf('{', i + 1);
          if (nextStart < 0) {
            return undefined;
          }
          // 递归尝试从下一个位置开始
          return SensorDataStore.extractJsonFromText(text.substring(nextStart));
        }
      }
    }
    return undefined;
  }

  /** 将嵌套对象展平为一级键值对列表 */
  private static flattenEntries(obj: Record<string, Object>, prefix: string = ''): SensorEntry[] {
    const result: SensorEntry[] = [];
    const keys = Object.keys(obj);
    for (let i = 0; i < keys.length; i++) {
      const k = keys[i];
      const v = obj[k];
      const label = prefix.length > 0 ? `${prefix}.${k}` : k;
      if (typeof v === 'object' && v !== null && !Array.isArray(v)) {
        // 嵌套对象：递归展平
        const children = SensorDataStore.flattenEntries(v as Record<string, Object>, label);
        for (let j = 0; j < children.length; j++) {
          result.push(children[j]);
        }
      } else {
        result.push({ key: label, value: SensorDataStore.formatValue(v) });
      }
    }
    return result;
  }

  private static formatValue(v: Object): string {
    if (typeof v === 'number') {
      return Number.isInteger(v) ? v.toString() : (v as number).toFixed(2);
    }
    if (typeof v === 'string') {
      return v;
    }
    if (typeof v === 'boolean') {
      return v ? '是' : '否';
    }
    if (v === null || v === undefined) {
      return '-';
    }
    return JSON.stringify(v);
  }

  static setConnected(connected: boolean): void {
    AppStorage.set(SensorDataStore.KEY_CONNECTED, connected);
  }

  static markDisconnected(): void {
    AppStorage.set(SensorDataStore.KEY_CONNECTED, false);
    AppStorage.set(SensorDataStore.KEY_ENTRIES, []);
  }
}
