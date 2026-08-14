# ============================================================================
#  会话管家: 监视 Harness GUI 窗口, 窗口关闭后自动关停 dsh web 服务
#  由启动器在后台挂载(隐藏进程); dsh 死后桌宠的宿主看门狗会随之退场
# ============================================================================
param(
    [int]$DshPid = 0,                    # dsh web 进程树根 PID
    [string]$ProcessName = "msedge",     # GUI 窗口所属进程名(可注入以便测试)
    [string]$WindowTitle = "DeepSeek Harness",   # 窗口标题匹配片段
    [string]$HarnessUrl = "",            # 用于按端口定位服务进程(降级击杀)
    [string]$LogPath = ""                # 调试日志路径(可选)
)

$ErrorActionPreference = "SilentlyContinue"
$seen = $false
$missCount = 0

function Watch-Log([string]$msg) {
    if ($LogPath) {
        try { Add-Content -Path $LogPath -Value ("{0} {1}" -f (Get-Date -Format "HH:mm:ss"), $msg) -Encoding UTF8 } catch { }
    }
}

# 枚举窗口: 标题包含片段且属于目标进程
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class WinWatch {
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
}
'@

function Find-HarnessWindow {
    $script:foundWindow = $false
    $procMap = @{}
    foreach ($p in Get-Process -Name $ProcessName -ErrorAction SilentlyContinue) {
        $procMap[[int]$p.Id] = $true
    }
    $cb = [WinWatch+EnumProc]{
        param($h, $l)
        $pid2 = 0
        [WinWatch]::GetWindowThreadProcessId($h, [ref]$pid2) | Out-Null
        $sb = New-Object System.Text.StringBuilder 256
        [WinWatch]::GetWindowText($h, $sb, 256) | Out-Null
        if ($procMap.ContainsKey([int]$pid2) -and $sb.ToString() -like "*$WindowTitle*") {
            $script:foundWindow = $true
        }
        return $true
    }
    [WinWatch]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
    return $script:foundWindow
}

function Kill-DshTree {
    # 击杀链: taskkill 整树 → 按端口杀监听进程 → 兜底杀根进程
    if ($DshPid -gt 0) {
        Watch-Log "尝试 taskkill /F /T /PID $DshPid"
        taskkill /F /T /PID $DshPid 2>$null
        Start-Sleep -Seconds 1
        if (Get-Process -Id $DshPid -ErrorAction SilentlyContinue) {
            Watch-Log "taskkill 未生效, 降级: 按端口定位监听进程"
            if ($HarnessUrl) {
                try {
                    $port = (New-Object System.Uri($HarnessUrl)).Port
                    $line = netstat -ano | Select-String (":$port\s+.*LISTENING") | Select-Object -First 1
                    if ($line) {
                        $np = ($line.ToString() -split '\s+')[-1]
                        Watch-Log "杀掉端口监听进程 $np"
                        Stop-Process -Id $np -Force -ErrorAction SilentlyContinue
                        Start-Sleep -Seconds 1
                    }
                } catch { }
            }
            Stop-Process -Id $DshPid -Force -ErrorAction SilentlyContinue
            Watch-Log "兜底: 直接终止根进程"
        }
    }
}

while ($true) {
    Start-Sleep -Seconds 3

    # 1) dsh 服务自己没了(其他方式关闭) → 管家功成身退
    if ($DshPid -gt 0) {
        $alive = Get-Process -Id $DshPid -ErrorAction SilentlyContinue
        if (-not $alive) {
            Watch-Log "dsh 进程已不存在, 管家退出"
            exit 0
        }
    }

    # 2) 检测 Harness GUI 窗口
    $winFound = Find-HarnessWindow
    if ($winFound) {
        if (-not $seen) { Watch-Log "检测到 Harness 窗口" }
        $seen = $true
        $missCount = 0
    } elseif ($seen) {
        # 窗口打开过又消失 → 连续确认两次(6秒)后关停整个服务树
        $missCount++
        Watch-Log "窗口消失, 连续计数 $missCount/2"
        if ($missCount -ge 2) {
            Kill-DshTree
            exit 0
        }
    }
}
