# 桌宠插件开关: 切换 web profile 中 dsh-desktop-pet 插件的启用状态
# 用法:
#   plugin-toggle.ps1                 # 自动翻转(禁用<->启用)
#   plugin-toggle.ps1 -Disable        # 强制禁用
#   plugin-toggle.ps1 -Enable         # 强制启用
#   plugin-toggle.ps1 -Status         # 只查看状态
#   plugin-toggle.ps1 -NoPause        # 不等待回车(脚本调用用)
param([switch]$Disable, [switch]$Enable, [switch]$Status, [switch]$NoPause)

$ErrorActionPreference = "Stop"
$patch = Join-Path $env:USERPROFILE ".dsh\profiles\web\cordis.patch.yml"

if (-not (Test-Path $patch)) {
    Write-Host "[错误] 找不到配置文件: $patch"
    if (-not $NoPause) { Read-Host "按回车退出" }
    exit 1
}

$content = [System.IO.File]::ReadAllText($patch, [System.Text.Encoding]::UTF8)
$lines = [System.Collections.ArrayList]@($content -split "`r?`n")

$nameIdx = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*name:\s*dsh-desktop-pet\s*$') { $nameIdx = $i; break }
}
if ($nameIdx -lt 0) {
    Write-Host "[错误] 未找到 dsh-desktop-pet 的注册条目"
    if (-not $NoPause) { Read-Host "按回车退出" }
    exit 1
}

$isDisabled = ($nameIdx + 1 -lt $lines.Count) -and ($lines[$nameIdx + 1] -match '^\s*disabled:\s*true\s*$')
$indent = ($lines[$nameIdx] -replace '^(\s*).*$', '$1')

if ($Status) {
    Write-Host ("桌宠插件当前状态: " + $(if ($isDisabled) { "已禁用 (Harness 启动时不会出现桌宠)" } else { "已启用 (随 Harness 启动/关闭)" }))
    if (-not $NoPause) { Read-Host "按回车退出" }
    exit 0
}

$target = if ($Disable) { $true } elseif ($Enable) { $false } else { -not $isDisabled }

if ($target -and -not $isDisabled) {
    $lines.Insert($nameIdx + 1, "${indent}disabled: true")
    Write-Host "[OK] 桌宠插件已禁用"
} elseif (-not $target -and $isDisabled) {
    $lines.RemoveAt($nameIdx + 1)
    Write-Host "[OK] 桌宠插件已启用"
} else {
    Write-Host "状态未变化"
}

[System.IO.File]::WriteAllText($patch, ($lines -join "`r`n"), (New-Object System.Text.UTF8Encoding($false)))

$after = [System.IO.File]::ReadAllText($patch, [System.Text.Encoding]::UTF8) -split "`r?`n"
$nowDisabled = $false
for ($i = 0; $i -lt $after.Count; $i++) {
    if ($after[$i] -match '^\s*name:\s*dsh-desktop-pet\s*$' -and $i + 1 -lt $after.Count -and $after[$i + 1] -match '^\s*disabled:\s*true\s*$') { $nowDisabled = $true; break }
}
Write-Host ("当前状态: " + $(if ($nowDisabled) { "已禁用" } else { "已启用" }))
Write-Host "提示: 重启 dsh web 后生效(重启前请先退出当前桌宠)"
if (-not $NoPause) { Read-Host "按回车退出" }
