const mapCanvas = document.getElementById("map");
const ctx = mapCanvas.getContext("2d");
const statusEl = document.getElementById("status");
const poseEl = document.getElementById("pose");
const visionInfoEl = document.getElementById("visionInfo");
const visionImg = document.getElementById("visionDebug");

const COLORS = {
  0: [40, 40, 60],    // unknown
  1: [240, 240, 240], // free
  2: [30, 30, 30],    // occupied
};

let ws = null;
let lastMap = null;

function connectWs() {
  if (ws) ws.close();
  const proto = location.protocol === "https:" ? "wss:" : "ws:";
  ws = new WebSocket(`${proto}//${location.host}/ws/map`);
  ws.onmessage = (ev) => {
    const msg = JSON.parse(ev.data);
    if (msg.type === "map") {
      lastMap = msg;
      drawMap(msg);
    }
  };
  ws.onclose = () => setTimeout(connectWs, 2000);
}

function drawMap(msg) {
  const { w, h, data, pose } = msg;
  mapCanvas.width = w;
  mapCanvas.height = h;
  const img = ctx.createImageData(w, h);
  for (let i = 0; i < data.length; i++) {
    const c = COLORS[data[i]] || COLORS[0];
    const o = i * 4;
    img.data[o] = c[0];
    img.data[o + 1] = c[1];
    img.data[o + 2] = c[2];
    img.data[o + 3] = 255;
  }
  ctx.putImageData(img, 0, 0);

  if (pose && msg.resolution && msg.origin) {
    const px = (pose.x - msg.origin[0]) / msg.resolution;
    const py = h - (pose.y - msg.origin[1]) / msg.resolution;
    ctx.strokeStyle = "#0f0";
    ctx.fillStyle = "#0f0";
    ctx.beginPath();
    ctx.arc(px, py, 4, 0, Math.PI * 2);
    ctx.fill();
    const len = 12;
    ctx.beginPath();
    ctx.moveTo(px, py);
    ctx.lineTo(px + len * Math.cos(pose.theta), py - len * Math.sin(pose.theta));
    ctx.stroke();
    poseEl.textContent = `x: ${pose.x.toFixed(2)} y: ${pose.y.toFixed(2)} θ: ${(pose.theta * 180 / Math.PI).toFixed(1)}°`;
  }
}

async function api(path, method = "POST", body) {
  const opt = { method, headers: {} };
  if (body !== undefined) {
    opt.headers["Content-Type"] = "application/json";
    opt.body = JSON.stringify(body);
  }
  const r = await fetch(path, opt);
  return r.json();
}

async function refreshStatus() {
  const s = await fetch("/api/status").then((r) => r.json());
  const sensorTxt = s.sensor_has_scan
    ? "雷达✓"
    : s.sensor_connected
      ? "雷达…"
      : "雷达✗";
  const parts = [
    sensorTxt,
    s.video_connected ? `视频✓` : `视频✗`,
    `建图:${s.mapping ? "开" : "关"}`,
    `探索:${s.exploring ? "开" : "关"}`,
    `沿墙:${s.wall_following ? (s.wall_side === "right" ? "右" : "左") : "关"}`,
  ];
  statusEl.textContent = `${s.car_ip} | ${parts.join(" | ")}`;

  const v = s.vision || {};
  const wallTxt = v.wall_found ? `${Math.round(v.distance_px)}px` : "未检测到";
  const vidTxt = s.video_connected ? (s.video_url || "已连接") : (s.video_error || "连接中");
  const obsTxt = v.obstacle_ahead ? " · 前方障碍" : "";
  let hintTxt = "";
  if (s.hints && s.hints.length) {
    hintTxt = " · " + s.hints[0];
  }
  visionInfoEl.textContent = `墙距: ${wallTxt} | 视频: ${vidTxt}${obsTxt}${hintTxt}`;
}

function refreshVisionImage() {
  visionImg.src = `/api/vision/debug.jpg?t=${Date.now()}`;
}

document.getElementById("btnConnect").onclick = () => api("/api/sensor/connect").then(refreshStatus);
document.getElementById("btnStartMap").onclick = () => api("/api/mapping/start").then(refreshStatus);
document.getElementById("btnStopMap").onclick = () =>
  api("/api/mapping/stop").then((r) => {
    alert(r.path ? `已保存: ${r.path}` : "已停止");
    refreshStatus();
  });
document.getElementById("btnExplore").onclick = () => api("/api/explore/start").then(refreshStatus);
document.getElementById("btnStopExplore").onclick = () => api("/api/explore/stop").then(refreshStatus);

function startWallFollow(side) {
  const dist = parseInt(document.getElementById("wallDistance").value, 10) || 120;
  return api("/api/wallfollow/start", "POST", { side, target_distance_px: dist }).then(refreshStatus);
}
document.getElementById("btnWallLeft").onclick = () => startWallFollow("left");
document.getElementById("btnWallRight").onclick = () => startWallFollow("right");
document.getElementById("btnStopWall").onclick = () => api("/api/wallfollow/stop").then(refreshStatus);

document.getElementById("btnStop").onclick = () => api("/api/control/stop").then(refreshStatus);

const keys = {};
document.addEventListener("keydown", (e) => {
  keys[e.key.toLowerCase()] = true;
  drive();
});
document.addEventListener("keyup", (e) => {
  keys[e.key.toLowerCase()] = false;
  if (["w", "a", "s", "d"].includes(e.key.toLowerCase())) {
    api("/api/control/stop");
  }
});

function drive() {
  let vx = 0, vy = 0;
  const sp = 35;
  if (keys.w) vy += sp;
  if (keys.s) vy -= sp;
  if (keys.a) vx -= sp;
  if (keys.d) vx += sp;
  if (vx !== 0 || vy !== 0) {
    api("/api/control/velocity", "POST", { vx, vy });
  }
}

connectWs();
refreshStatus();
setInterval(refreshStatus, 2000);
setInterval(refreshVisionImage, 500);
