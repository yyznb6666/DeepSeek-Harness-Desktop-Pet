import { fileURLToPath } from "node:url";

/**
 * @module dsh-desktop-pet
 * 爱弥斯桌宠插件(零依赖): Harness 主机启动时自动挂载 WPF 桌宠进程,
 * 主机关闭时自动回收。桌宠自带任务完成提醒
 * (监听 events.host WebSocket, 主会话任务完成时气泡+托盘弹窗+提示音)。
 *
 * 注册方式(profile 的 cordis.patch.yml):
 *   - insert:
 *       - id: desktop-pet
 *         name: dsh-desktop-pet
 */

/** Stable Cordis plugin name. */
const name = "desktop-pet";

/** webServer 用于推导实际监听端口; subprocess 走官方托管子进程通道。 */
const inject = ["webServer", "subprocess"];

/** 插件内置桌宠脚本位置 */
const DEFAULT_PET_SCRIPT = fileURLToPath(
  new URL("../pet/爱弥斯桌宠.ps1", import.meta.url),
);

/**
 * 挂载桌宠: 在主机启动时通过 ctx.subprocess 托管运行 WPF 桌宠进程;
 * 服务销毁/插件卸载时自动终止进程树。
 * @param ctx - Cordis 插件上下文(含 webServer / subprocess 服务)
 * @param config - 配置对象(均可选): { enabled, powerShell, petScript, harnessUrl, noTaskWatch }
 */
function apply(ctx, config) {
  config = config || {};
  if (config.enabled === false) return;
  let url = config.harnessUrl || "";
  if (!url) {
    let port;
    try {
      port = ctx.webServer?.port;
    } catch {
      port = undefined;
    }
    url = port ? `http://127.0.0.1:${String(port)}` : "http://127.0.0.1:3080";
  }
  const script = config.petScript || DEFAULT_PET_SCRIPT;
  const powerShell = config.powerShell || "powershell.exe";
  const argv = [
    powerShell,
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-STA",
    "-WindowStyle",
    "Hidden",
    "-File",
    script,
    "-HarnessUrl",
    url,
  ];
  if (config.noTaskWatch) argv.push("-NoTaskWatch");
  const handle = ctx.subprocess.spawn({
    argv,
    cwd: process.cwd(),
    stdio: { stdin: "ignore", stdout: "inherit", stderr: "inherit" },
    graceMs: 5000,
  });
  handle.done.then(
    (outcome) => {
      console.log(`[desktop-pet] 桌宠进程退出 (code=${String(outcome.exitCode)})`);
    },
    (err) => {
      console.error(`[desktop-pet] 桌宠启动失败: ${String(err?.message ?? err)}`);
    },
  );
  console.log(`[desktop-pet] 爱弥斯桌宠已挂载 (${url})`);
  ctx.on("dispose", () => {
    try {
      handle.terminate();
    } catch {
      /* 服务销毁时已统一回收 */
    }
  });
}

export { apply, inject, name };
