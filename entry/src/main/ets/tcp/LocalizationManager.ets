/** 定位帧管理：解析 @POSE / @MAPINFO，构造 @LOCALIZE / @INITPOSE */

export interface PoseState {
  x: number;
  y: number;
  theta: number;
  conf: number;
  converged: boolean;
}

export interface MapInfo {
  url: string;
  resolution: number;
  origin: number[];
  w: number;
  h: number;
  ready: boolean;
}

/** 导航路径点（世界坐标，后续由车端推送） */
export interface NavPathPoint {
  x: number;
  y: number;
}

/** 地图像素坐标 */
export interface PixelPoint {
  px: number;
  py: number;
}

interface LocalizePayload {
  mode: string;
}

interface InitPosePayload {
  px: number;
  py: number;
  heading: number;
  imgW: number;
  imgH: number;
}

const POSE_PREFIX = '@POSE';
const MAPINFO_PREFIX = '@MAPINFO';

export class LocalizationManager {
  private static pose: PoseState = { x: 0, y: 0, theta: 0, conf: 0, converged: false };
  private static mapInfo: MapInfo | undefined = undefined;
  private static navPath: NavPathPoint[] = [];
  private static poseListeners: Array<(p: PoseState) => void> = [];
  private static mapListeners: Array<(m: MapInfo) => void> = [];
  private static pathListeners: Array<(path: NavPathPoint[]) => void> = [];

  static getPose(): PoseState {
    return LocalizationManager.pose;
  }

  static getMapInfo(): MapInfo | undefined {
    return LocalizationManager.mapInfo;
  }

  static getNavPath(): NavPathPoint[] {
    return LocalizationManager.navPath;
  }

  static subscribePose(listener: (p: PoseState) => void): void {
    LocalizationManager.poseListeners.push(listener);
  }

  static subscribeMap(listener: (m: MapInfo) => void): void {
    LocalizationManager.mapListeners.push(listener);
  }

  static subscribeNavPath(listener: (path: NavPathPoint[]) => void): void {
    LocalizationManager.pathListeners.push(listener);
  }

  static setNavPath(path: NavPathPoint[]): void {
    LocalizationManager.navPath = path;
    for (const l of LocalizationManager.pathListeners) {
      l(LocalizationManager.navPath);
    }
  }

  static dispatch(message: string): boolean {
    const frames = LocalizationManager.splitFrames(message);
    let handled = false;
    for (const f of frames) {
      if (LocalizationManager.tryParsePose(f)) {
        handled = true;
      } else if (LocalizationManager.tryParseMapInfo(f)) {
        handled = true;
      }
    }
    return handled;
  }

  private static splitFrames(message: string): string[] {
    const frames: string[] = [];
    let start = 0;
    while (start < message.length) {
      const pIdx = message.indexOf(POSE_PREFIX, start);
      const mIdx = message.indexOf(MAPINFO_PREFIX, start);
      let nextIdx = -1;
      if (pIdx >= 0) {
        nextIdx = pIdx;
      }
      if (mIdx >= 0 && (nextIdx < 0 || mIdx < nextIdx)) {
        nextIdx = mIdx;
      }
      if (nextIdx < 0) {
        break;
      }
      const endIdx = message.indexOf('#', nextIdx);
      if (endIdx < 0) {
        break;
      }
      frames.push(message.substring(nextIdx, endIdx + 1));
      start = endIdx + 1;
    }
    return frames;
  }

  private static tryParsePose(frame: string): boolean {
    if (!frame.startsWith(POSE_PREFIX) || !frame.endsWith('#')) {
      return false;
    }
    const json = frame.substring(POSE_PREFIX.length, frame.length - 1);
    try {
      const d = JSON.parse(json) as Record<string, number | boolean>;
      LocalizationManager.pose = {
        x: Number(d['x']),
        y: Number(d['y']),
        theta: Number(d['theta']),
        conf: Number(d['conf']),
        converged: Boolean(d['converged'])
      };
      for (const l of LocalizationManager.poseListeners) {
        l(LocalizationManager.pose);
      }
      return true;
    } catch (e) {
      console.error('parse @POSE fail', JSON.stringify(e));
      return false;
    }
  }

  private static tryParseMapInfo(frame: string): boolean {
    if (!frame.startsWith(MAPINFO_PREFIX) || !frame.endsWith('#')) {
      return false;
    }
    const json = frame.substring(MAPINFO_PREFIX.length, frame.length - 1);
    try {
      const d = JSON.parse(json) as Record<string, string | number | boolean | number[]>;
      LocalizationManager.mapInfo = {
        url: `${d['url']}`,
        resolution: Number(d['resolution']),
        origin: d['origin'] as number[],
        w: Number(d['w']),
        h: Number(d['h']),
        ready: Boolean(d['ready'])
      };
      for (const l of LocalizationManager.mapListeners) {
        l(LocalizationManager.mapInfo);
      }
      return true;
    } catch (e) {
      console.error('parse @MAPINFO fail', JSON.stringify(e));
      return false;
    }
  }

  static buildLocalize(mode: string): string {
    const payload: LocalizePayload = { mode: mode };
    return `@LOCALIZE${JSON.stringify(payload)}#`;
  }

  static buildInitPose(px: number, py: number, heading: number, imgW: number, imgH: number): string {
    const payload: InitPosePayload = {
      px: px,
      py: py,
      heading: heading,
      imgW: imgW,
      imgH: imgH
    };
    return `@INITPOSE${JSON.stringify(payload)}#`;
  }

  /** 世界坐标 → 地图控件像素（用于画车位箭头） */
  static worldToPixel(x: number, y: number, mapW: number, mapH: number,
    resolution: number, origin: number[]): PixelPoint {
    const ox = origin[0];
    const oy = origin[1];
    const px = (x - ox) / resolution;
    const py = mapH - (y - oy) / resolution;
    const result: PixelPoint = { px: px, py: py };
    return result;
  }
}
