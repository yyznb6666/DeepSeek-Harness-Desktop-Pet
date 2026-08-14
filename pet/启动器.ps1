# ============================================================================
#  DeepSeek Harness 桌面版 启动器
#  1. 检测 127.0.0.1:3080 的 Harness 服务, 未启动则自动拉起 `dsh web`
#  2. 用 Edge 无边框 app 模式打开 Harness 桌面窗口(专用独立配置目录)
#  3. 挂载爱弥斯桌宠(独立隐藏进程)
#  4. 挂载会话管家: 叉掉 Harness 窗口 → 自动关停 dsh web → 桌宠随之退场
# ============================================================================
param(
    [string]$HarnessUrl = "http://127.0.0.1:3080",
    [switch]$SkipEdge,
    [switch]$SkipPet
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$script:DshPid = 0

function Test-Harness([string]$url) {
    try {
        $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 3
        return $r.StatusCode -eq 200
    } catch {
        return $false
    }
}

function Find-HarnessPid([string]$url) {
    try {
        $u = New-Object System.Uri($url)
        $port = $u.Port
        $line = netstat -ano | Select-String (":$port\s+.*LISTENING") | Select-Object -First 1
        if ($line) {
            $pidStr = ($line.ToString() -split '\s+')[-1]
            $pidNum = 0
            if ([int]::TryParse($pidStr, [ref]$pidNum)) { return $pidNum }
        }
    } catch { }
    return 0
}

function Ensure-Harness {
    if (Test-Harness $HarnessUrl) {
        $script:DshPid = Find-HarnessPid $HarnessUrl
        Write-Host "DeepSeek Harness 服务已在运行: $HarnessUrl (PID=$script:DshPid)"
        return
    }
    Write-Host "未检测到 Harness 服务, 正在启动 dsh web ..."
    $logDir = Join-Path $root "logs"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $log = Join-Path $logDir "dsh-web.log"
    $proc = $null
    try {
        $proc = Start-Process cmd -ArgumentList @("/c", "dsh web >> `"$log`" 2>&1") -WindowStyle Hidden -PassThru
    } catch {
        $proc = Start-Process -FilePath "dsh" -ArgumentList @("web") -WindowStyle Hidden -PassThru
    }
    $script:DshPid = $proc.Id
    $ok = $false
    for ($i = 0; $i -lt 40; $i++) {
        Start-Sleep -Milliseconds 1000
        if (Test-Harness $HarnessUrl) { $ok = $true; break }
    }
    if ($ok) {
        Write-Host "Harness 服务已就绪: $HarnessUrl (PID=$script:DshPid)"
    } else {
        Write-Host "警告: 40 秒内未检测到 Harness 服务, 请查看日志: $log"
        Write-Host "可手动在终端执行: dsh web"
    }
}

function Open-EdgeWindow {
    if ($SkipEdge) { return }
    $edge = @(
        "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    $prof = Join-Path $root ".edge-profile"
    if ($edge) {
        $args = @(
            "--app=$HarnessUrl",
            "--window-size=1500,950",
            "--window-position=60,30",
            "--user-data-dir=`"$prof`"",
            "--no-first-run",
            "--no-default-browser-check"
        )
        Start-Process $edge -ArgumentList $args | Out-Null
        Write-Host "已打开 DeepSeek Harness 桌面窗口 (Edge app 模式)"
    } else {
        Start-Process $HarnessUrl | Out-Null
        Write-Host "未找到 Edge, 已用默认浏览器打开 $HarnessUrl"
    }
}

function Start-Pet {
    if ($SkipPet) { return }
    $petScript = Join-Path $PSScriptRoot "爱弥斯桌宠.ps1"
    if (-not (Test-Path $petScript)) {
        Write-Host "未找到桌宠脚本: $petScript"
        return
    }
    $ps = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
    $args = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-STA",
        "-WindowStyle", "Hidden",
        "-File", "`"$petScript`"",
        "-HarnessUrl", "`"$HarnessUrl`""
    )
    # 宿主看门狗: dsh 服务退出后桌宠自动退场
    if ($script:DshPid -gt 0) {
        $args += @("-ParentPid", "$script:DshPid")
    }
    Start-Process -FilePath $ps -ArgumentList $args -WindowStyle Hidden | Out-Null
    Write-Host "爱弥斯桌宠已挂载 (常驻托盘, 右键桌宠可打开菜单)"
}

function Start-SessionWatcher {
    # 会话管家: 叉掉 Harness GUI 窗口 → 关停 dsh web 服务树 → 桌宠看门狗退场
    if ($script:DshPid -le 0) { return }
    if ($SkipEdge) { return }
    $watcher = Join-Path $PSScriptRoot "watch-session.ps1"
    if (-not (Test-Path $watcher)) { return }
    $ps = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
    $args = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-WindowStyle", "Hidden",
        "-File", "`"$watcher`"",
        "-DshPid", "$script:DshPid",
        "-HarnessUrl", "`"$HarnessUrl`""
    )
    Start-Process -FilePath $ps -ArgumentList $args -WindowStyle Hidden | Out-Null
    Write-Host "会话管家已挂载 (叉掉 Harness 窗口将自动关停服务与桌宠)"
}

function Ensure-Shortcut {
    # 首次运行自动在桌面创建快捷方式
    $lnkPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "DeepSeek Harness 桌面版.lnk"
    if (Test-Path $lnkPath) { return }
    try {
        $bat = Join-Path $root "启动桌面版.bat"
        if (-not (Test-Path $bat)) { return }
        $ws = New-Object -ComObject WScript.Shell
        $sc = $ws.CreateShortcut($lnkPath)
        $sc.TargetPath = $bat
        $sc.WorkingDirectory = $root
        $sc.Description = "DeepSeek Harness 桌面版 + 爱弥斯桌宠"
        $ico = Join-Path $root "assets\爱弥斯.ico"
        if (Test-Path $ico) { $sc.IconLocation = $ico }
        $sc.Save()
        Write-Host "已在桌面创建快捷方式: DeepSeek Harness 桌面版.lnk"
    } catch {
        Write-Host "桌面快捷方式创建失败(可忽略): $($_.Exception.Message)"
    }
}

Ensure-Harness
Open-EdgeWindow
Start-Pet
Start-SessionWatcher
Ensure-Shortcut
Write-Host "启动完成! (叉掉 Harness 窗口即可全家下班: 服务/窗口/桌宠一起关闭)"
