# ============================================================================
#  DeepSeek Harness 桌面版 启动器
#  1. 检测 127.0.0.1:3080 的 Harness 服务, 未启动则自动拉起 `dsh web`
#  2. 用 Edge 无边框 app 模式打开 Harness 桌面窗口(专用独立配置目录)
#  3. 挂载爱弥斯桌宠(独立隐藏进程, 关闭本窗口不影响桌宠)
# ============================================================================
param(
    [string]$HarnessUrl = "http://127.0.0.1:3080",
    [switch]$SkipEdge,
    [switch]$SkipPet
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent

function Test-Harness([string]$url) {
    try {
        $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 3
        return $r.StatusCode -eq 200
    } catch {
        return $false
    }
}

function Ensure-Harness {
    if (Test-Harness $HarnessUrl) {
        Write-Host "DeepSeek Harness 服务已在运行: $HarnessUrl"
        return
    }
    Write-Host "未检测到 Harness 服务, 正在启动 dsh web ..."
    $logDir = Join-Path $root "logs"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $log = Join-Path $logDir "dsh-web.log"
    try {
        Start-Process cmd -ArgumentList @("/c", "dsh web >> `"$log`" 2>&1") -WindowStyle Hidden | Out-Null
    } catch {
        Start-Process -FilePath "dsh" -ArgumentList @("web") -WindowStyle Hidden | Out-Null
    }
    $ok = $false
    for ($i = 0; $i -lt 40; $i++) {
        Start-Sleep -Milliseconds 1000
        if (Test-Harness $HarnessUrl) { $ok = $true; break }
    }
    if ($ok) {
        Write-Host "Harness 服务已就绪: $HarnessUrl"
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
    Start-Process -FilePath $ps -ArgumentList $args -WindowStyle Hidden | Out-Null
    Write-Host "爱弥斯桌宠已挂载 (常驻托盘, 右键桌宠可打开菜单)"
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
Ensure-Shortcut
Write-Host "启动完成!"
