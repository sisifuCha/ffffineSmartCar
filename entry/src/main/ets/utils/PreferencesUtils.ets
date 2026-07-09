import preferences from '@ohos.data.preferences';

/**首选项对象*/
export class PreferencesUtils {
  /**私有静态实例，懒汉式单例*/
  private static instance: PreferencesUtils | undefined = undefined;
  /**网络工具对象*/
  private netUtilsValue: NetInfoPreferencesUtils | undefined = undefined;
  private initPromise: Promise<void> | undefined = undefined;

  /**私有构造方法，防止外部直接实例化*/
  private constructor() {
  }

  /**提供一个公共的静态方法返回实例对象*/
  public static getInstance(): PreferencesUtils {
    if (!PreferencesUtils.instance)
      PreferencesUtils.instance = new PreferencesUtils();
    return PreferencesUtils.instance;
  }

  get netUtils(): NetInfoPreferencesUtils {
    if (!this.netUtilsValue) {
      throw new Error('PreferencesUtils not initialized. Call init() first.')
    }
    return this.netUtilsValue;
  }

  async init(context: Context): Promise<void> {
    if (!this.initPromise) {
      const netUtils = new NetInfoPreferencesUtils();
      this.netUtilsValue = netUtils;
      this.initPromise = netUtils.init(context);
    }
    return this.initPromise;
  }
}

/**
 * 网络配置首选项工具
 */
export class NetInfoPreferencesUtils {
  public static readonly NAME = "net_preferences_utils"
  public static readonly KEY_IP = "KEY_IP";
  public static readonly KEY_TCP_PORT = "KEY_TCP_PORT";
  public static readonly KEY_VIDEO_PORT = "KEY_TCP_VIDEO";
  public static readonly KEY_SLAVE_IP = "KEY_SLAVE_IP";
  public static readonly KEY_SLAVE_PORT = "KEY_SLAVE_PORT";
  public static readonly KEY_DUAL_MODE = "KEY_DUAL_MODE";

  private prefValue: preferences.Preferences | undefined = undefined;
  private initPromise: Promise<void> | undefined = undefined;

  init(context: Context): Promise<void> {
    if (!this.initPromise) {
      this.initPromise = this.loadPreferences(context);
    }
    return this.initPromise;
  }

  private async loadPreferences(context: Context): Promise<void> {
    let name = NetInfoPreferencesUtils.NAME;
    try {
      this.prefValue = await preferences.getPreferences(context, name)
      console.log(`preferences[${name}]初始化成功`)
    } catch (err) {
      console.error(`preferences[${name}]初始化失败`)
      console.error('err: ', JSON.stringify(err))
      throw new Error('Preferences not initialized')
    }
  }

  private async ensureReady(): Promise<preferences.Preferences> {
    if (!this.initPromise) {
      throw new Error('Preferences not initialized')
    }
    await this.initPromise;
    if (!this.prefValue) {
      throw new Error('Preferences not initialized')
    }
    return this.prefValue;
  }

  async getIP(): Promise<string> {
    const pref = await this.ensureReady();
    const v = await pref.get(NetInfoPreferencesUtils.KEY_IP, '192.168.1.11');
    return `${v}`;
  }

  async setIp(v: string): Promise<void> {
    const pref = await this.ensureReady();
    await pref.put(NetInfoPreferencesUtils.KEY_IP, v);
    await pref.flush();
  }

  async getTcpPort(): Promise<string> {
    const pref = await this.ensureReady();
    const v = await pref.get(NetInfoPreferencesUtils.KEY_TCP_PORT, '6000');
    return `${v}`;
  }

  async setTcpPort(v: string): Promise<void> {
    const pref = await this.ensureReady();
    await pref.put(NetInfoPreferencesUtils.KEY_TCP_PORT, v);
    await pref.flush();
  }

  async setVideoPort(v: string): Promise<void> {
    const pref = await this.ensureReady();
    await pref.put(NetInfoPreferencesUtils.KEY_VIDEO_PORT, v);
    await pref.flush();
  }

  async getVideoPort(): Promise<string> {
    const pref = await this.ensureReady();
    const v = await pref.get(NetInfoPreferencesUtils.KEY_VIDEO_PORT, '6500');
    return `${v}`;
  }

  async getSlaveIp(): Promise<string> {
    const pref = await this.ensureReady();
    const v = await pref.get(NetInfoPreferencesUtils.KEY_SLAVE_IP, '192.168.1.12');
    return `${v}`;
  }

  async setSlaveIp(v: string): Promise<void> {
    const pref = await this.ensureReady();
    await pref.put(NetInfoPreferencesUtils.KEY_SLAVE_IP, v);
    await pref.flush();
  }

  async getSlavePort(): Promise<string> {
    const pref = await this.ensureReady();
    const v = await pref.get(NetInfoPreferencesUtils.KEY_SLAVE_PORT, '6001');
    return `${v}`;
  }

  async setSlavePort(v: string): Promise<void> {
    const pref = await this.ensureReady();
    await pref.put(NetInfoPreferencesUtils.KEY_SLAVE_PORT, v);
    await pref.flush();
  }

  async getDualMode(): Promise<boolean> {
    const pref = await this.ensureReady();
    const v = await pref.get(NetInfoPreferencesUtils.KEY_DUAL_MODE, false);
    return Boolean(v);
  }

  async setDualMode(enabled: boolean): Promise<void> {
    const pref = await this.ensureReady();
    await pref.put(NetInfoPreferencesUtils.KEY_DUAL_MODE, enabled);
    await pref.flush();
  }
}
