# DeepSeek Harness 桌面版 + 爱弥斯桌宠

把 [DeepSeek Harness](https://127.0.0.1:3080) 变成真正的**桌面应用**：一个干净的 Harness 桌面窗口 +
一只常驻屏幕角落的 **Q 版「爱弥斯」桌宠**（鸣潮 3.1 粉发赛博幽灵，默认使用官方 Q 版立绘形象）。

**零外部依赖**：不装 Electron、不联网下载，只用 Windows 自带的 WPF / WinForms / Edge，开箱即用。

---

## ✨ 特性

| 组件 | 说明 |
|---|---|
| 🖥️ Harness 桌面窗口 | Edge `--app` 无边框模式打开本地 Harness（专用独立配置，不污染日常浏览器） |
| ⚙️ 服务自启 | 若 `dsh web` 未运行，启动器自动拉起并等待就绪 |
| 🧩 DSH 插件 | `dsh-desktop-pet` Cordis 插件：**Harness 启动时自动挂载桌宠、关闭时自动回收**（已注册到 web profile，重启 `dsh web` 生效） |
| 👧 爱弥斯桌宠 | WPF 全透明置顶窗口，默认显示**官方 Q 版立绘**（`pet\portrait.png`，已自动去白底+裁边） |
| 🔔 任务完成提醒 | 常驻监听 Harness 事件流（WebSocket），**主会话任务完成时自动提醒**：气泡台词 + 爱心特效 + 托盘弹窗 + 提示音 + 自动唤起隐藏窗口 |
| 🎬 动态 | 呼吸浮动、立绘下方光影 + 全息环旋转 + 星光闪烁（立绘模式）；删除立绘后回退到自绘矢量 Q 版（眨眼/幽灵尾等全套动画） |
| 🗨️ 对话 | 随机闲聊 + 点按/摸头/喂食/睡觉等互动气泡（赛博幽灵人设台词） |
| 🖱️ 交互 | 左键点按互动、按住拖动、右键菜单（夸夸/摸摸/喂食/休息/回角落/打开 Harness/退出） |
| 🎛️ 托盘 | 常驻托盘：显示/隐藏桌宠、打开 Harness、退出 |
| 🖼️ 立绘切换 | 把任意透明背景 PNG 存为 `pet\portrait.png` 即可换形象；删除该文件恢复自绘矢量 Q 版 |

---

## 🚀 快速开始

双击运行根目录的 **`启动桌面版.bat`**，一切自动完成：

1. 检测 `http://127.0.0.1:3080`，未启动则自动执行 `dsh web`
2. 打开 DeepSeek Harness 桌面窗口（Edge app 模式）
3. 挂载爱弥斯桌宠（隐藏进程常驻，关闭启动窗口不影响桌宠）
4. 首次运行自动在桌面创建「DeepSeek Harness 桌面版」快捷方式

其他入口：

| 脚本 | 作用 |
| --- | --- |
| `桌宠单独启动.bat` | 只启动桌宠 |
| `打开Harness窗口.bat` | 只启动服务 + 打开 Harness 窗口 |
| `推送GitHub.bat` | 一键推送本仓库到 GitHub（见下） |

---

## ☁️ 同步到 GitHub

1. 在 GitHub 新建一个**私有**空仓库（`https://github.com/new`，不要勾选任何初始化选项）
2. 双击 `推送GitHub.bat`，输入你的 GitHub 用户名和仓库名
3. 首次推送会弹出 GitHub 浏览器登录窗口，授权后自动完成
4. 之后代码有更新，再次运行 `推送GitHub.bat` 即可增量推送

> 注意：仓库内含官方 Q 版立绘素材（`pet\portrait.png` 等），仅限个人私有使用；如计划转公开，请先删除这些素材。
| 托盘图标 / 桌宠右键菜单 | 「打开 DeepSeek Harness」随时唤回主窗口 |

---

## 🎮 桌宠玩法

- **单击**：随机互动（夸夸 / 摸摸头 / 卖萌台词），会开心跳一下
- **按住拖动**：拖到任意位置；用力甩出屏幕边缘会惹她生气 😠
- **右键菜单**：✨夸夸我 ・ 💗摸摸头（爱心特效）・ 🍡喂食（能量球飞入嘴里）・ 🌙休息/起床（Zzz 充电）・ 🧹回到屏幕右下角 ・ 🖥️打开 DeepSeek Harness ・ 🎨关于 ・ 🚪退出
- **托盘**：双击图标或右键可显示/隐藏桌宠、退出

> 桌宠永远置顶且不抢焦点、不进任务栏/Alt-Tab，不影响你写代码。

---

## 🖼️ 立绘形象（默认已启用）

桌宠默认使用**工作区提供的 Q 版爱弥斯立绘**（`50.webp` → 已裁边处理为 `pet\portrait.png`，底部对齐，带光影/全息环/星光氛围）。

- **换形象**：把任意透明背景 PNG 存为 `pet\portrait.png`（主体居中、全身或半身皆可），重启桌宠即可
- **回到自绘矢量版**：删除 `pet\portrait.png` 后重启，桌宠恢复为自绘矢量 Q 版（含眨眼、幽灵尾等全套动画）
- **图标同步**：运行 `tools\make-icon.ps1` 会用当前立绘重新生成托盘/快捷方式图标

> 版权提示：官方素材仅限个人本地使用，请勿传播与商用。

---

## 🧩 作为 DSH 插件使用

桌宠已封装为 **`dsh-desktop-pet`** Cordis 插件（零依赖），并已安装到本机 Harness：

- **插件包**：`dsh-desktop-pet\`（`lib\index.js` 入口 + 内置桌宠脚本与立绘素材）
- **已注册**：`$DSH_HOME\profiles\web\cordis.patch.yml` 已插入 `desktop-pet` 条目，并创建了 `profiles\node_modules\dsh-desktop-pet` 链接
- **生效方式**：重启 Harness（结束当前 `dsh web` 进程后重新运行 `启动桌面版.bat` 或 `dsh web`）。之后桌宠随 Harness **启动自动出现、关闭自动消失**
- **端口自适应**：插件从 `webServer` 服务读取实际端口并传给桌宠，改端口启动（如 `dsh web --port 8080`）桌宠会自动跟随
- **配置**（可选，加在补丁条目下）：`config: { enabled: false }` 禁用；`noTaskWatch: true` 关闭任务提醒；`petScript: "..."` 指定外部桌宠脚本
- **卸载**：删除 `cordis.patch.yml` 里的 `desktop-pet` 插入条目并重启即可
- **其他机器安装**：把 `dsh-desktop-pet\` 目录放到任意位置，在 `$DSH_HOME\profiles\node_modules\` 下建同名目录链接，再按 `dsh-desktop-pet\profile-patch.yml` 的模板补丁注册

> 注意：插件内置的是桌宠脚本的副本；改动 `pet\爱弥斯桌宠.ps1`（独立版）不会影响插件版，需要同步复制到 `dsh-desktop-pet\pet\`。
> 桌宠有互斥锁保护：插件版与独立启动版同时存在时只会出现一个，不会重复。

---

## 📂 文件结构

```
deekseep桌面版/
├── 启动桌面版.bat          # 一键启动（推荐）
├── 桌宠单独启动.bat
├── 打开Harness窗口.bat
├── 推送GitHub.bat          # 一键推送仓库到 GitHub
├── pet/
│   ├── 爱弥斯桌宠.ps1      # 桌宠主程序（形象/动画/交互/台词都在这里，可自行改）
│   ├── 启动器.ps1          # 服务自启 + Edge 窗口 + 桌宠挂载
│   ├── run.ps1             # ASCII 转发器（bat → 启动器，避免 cmd 编码问题）
│   ├── run-pet.ps1         # ASCII 转发器（bat → 桌宠）
│   └── portrait.png        # 官方 Q 版立绘（默认形象；删除即回退自绘矢量版）
├── dsh-desktop-pet/        # DSH Cordis 插件包（随 Harness 启停桌宠）
│   ├── lib/index.js        # 插件入口（ctx.subprocess 托管桌宠进程）
│   ├── pet/                # 插件内置的桌宠脚本与立绘副本
│   ├── assets/爱弥斯.ico
│   └── profile-patch.yml   # 注册模板（cordis.patch.yml 的插入条目）
├── assets/
│   ├── 爱弥斯.ico          # 桌宠/快捷方式图标
│   └── 爱弥斯.png
├── tools/
│   └── make-icon.ps1       # 重新生成图标
└── logs/                   # dsh web 日志（首次启动自动创建）
```

---

## ❓ 常见问题

- **桌宠没出现？** 确认已启动 `dsh web`（或先运行 `打开Harness窗口.bat`）；Windows 若弹安全警告，选择「仍要运行」。
- **任务完成提醒怎么工作的？** 桌宠通过 WebSocket 监听 Harness 的 `events.host` 事件流（`host/session-status` 运行状态翻转），自动过滤子代理会话，只对**主会话**的任务完成做出反应；运行日志见 `logs\pet-notify.log`。若不想用，启动时加 `-NoTaskWatch`。
- **杀毒软件误报？** 纯脚本无任何可执行载荷；可把本文件夹加入白名单。
- **没有 Edge？** 启动器会自动改用默认浏览器打开 Harness，桌宠不受影响。
- **想改台词/配色？** 打开 `pet\爱弥斯桌宠.ps1`，搜索 `LINES`（台词池，含 `taskdone` 提醒台词）或 `#ff9fd8` 等十六进制色值即可。
- **想调整桌宠大小？** 修改脚本中 `$script:win.Width/Height`（默认 280×360）与画布坐标比例。

---

## 📝 技术说明

- 桌宠：`Windows PowerShell 5.1 + WPF`（透明置顶窗口、矢量图形、DispatcherTimer 动画、WinForms 托盘）
- 任务提醒：独立 Runspace 后台监听 Harness `/api/events.host` WebSocket + `/api/session.list` 基线，事件经线程安全队列回到 UI 线程触发
- 主窗口：`msedge --app=...` 独立用户目录，不干扰日常 Edge 配置
- 完全离线可用；Harness 服务仍由 `dsh` CLI 提供（本机 3080 端口）

祝你和爱弥斯相处愉快 ♡
