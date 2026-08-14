# 一键把本仓库推送到 GitHub
# 首次推送会自动弹出 GitHub 浏览器登录窗口(Git Credential Manager)
$ErrorActionPreference = "Continue"

# ---- 自动定位仓库: 从脚本所在目录向上查找 .git ----
$scriptPath = $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($scriptPath) -and $PSCommandPath) { $scriptPath = $PSCommandPath }
$startDir = if ($scriptPath) { Split-Path $scriptPath -Parent } else { (Get-Location).Path }
$repo = $null
$dir = $startDir
for ($i = 0; $i -lt 6; $i++) {
    if (Test-Path (Join-Path $dir ".git")) { $repo = $dir; break }
    $parent = Split-Path $dir -Parent
    if (-not $parent -or $parent -eq $dir) { break }
    $dir = $parent
}
if (-not $repo) {
    Write-Host "[错误] 没有找到 git 仓库。"
    Write-Host "请直接打开项目文件夹(里面有 pet、assets 等目录的那个), 双击里面的 推送GitHub.bat。"
    Read-Host "按回车退出"
    exit 1
}
Set-Location $repo
Write-Host "[仓库] $repo"
Write-Host ""

# ---- 收集信息 ----
$user = Read-Host "请输入 GitHub 用户名(如 zhangsan)"
$repoName = Read-Host "请输入仓库名(如 DeepSeek-Harness-Desktop-Pet)"
if ([string]::IsNullOrWhiteSpace($user) -or [string]::IsNullOrWhiteSpace($repoName)) {
    Write-Host "[错误] 用户名和仓库名不能为空"
    Read-Host "按回车退出"
    exit 1
}

Write-Host ""
Write-Host "[提示] 若还没有仓库, 请先打开浏览器访问 https://github.com/new"
Write-Host "       创建名为 $repoName 的【私有】空仓库, 不要勾选任何初始化选项(README/gitignore/许可证都不要)。"
Read-Host "准备好后按回车继续"

git remote remove origin 2>$null
git remote add origin "https://github.com/$user/$repoName.git"
git branch -M main
Write-Host ""
Write-Host "[开始推送] 首次推送会弹出 GitHub 登录窗口, 请用浏览器完成授权..."
git push -u origin main
if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "===== 推送成功! ====="
    Write-Host "仓库地址: https://github.com/$user/$repoName"
    Write-Host "以后代码有更新, 直接再运行一次本脚本即可增量推送。"
} else {
    Write-Host ""
    Write-Host "[推送失败] 常见原因:"
    Write-Host " 1. 仓库名/用户名拼写错误, 或仓库还没创建"
    Write-Host " 2. 网络不通(检查代理/VPN)"
    Write-Host " 3. 登录未完成——再运行一次, 弹出的窗口里点 Sign in with your browser"
}
Read-Host "按回车退出"
