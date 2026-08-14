# 一键把本仓库推送到 GitHub
# 首次推送会自动弹出 GitHub 浏览器登录窗口(Git Credential Manager)
$ErrorActionPreference = "Continue"
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

if (-not (Test-Path ".git")) {
    Write-Host "[错误] 当前目录不是 git 仓库, 请先运行 git init"
    Read-Host "按回车退出"
    exit 1
}

Write-Host ""
Write-Host "===== 推送仓库到 GitHub ====="
$user = Read-Host "请输入 GitHub 用户名(如 zhangsan)"
$repo = Read-Host "请输入仓库名(如 DeepSeek-Harness-Desktop-Pet)"
if ([string]::IsNullOrWhiteSpace($user) -or [string]::IsNullOrWhiteSpace($repo)) {
    Write-Host "[错误] 用户名和仓库名不能为空"
    Read-Host "按回车退出"
    exit 1
}

Write-Host ""
Write-Host "[提示] 若还没有仓库, 请先打开浏览器访问 https://github.com/new"
Write-Host "       创建名为 $repo 的【私有】空仓库, 不要勾选任何初始化选项(README/gitignore/许可证都不要)。"
Write-Host "       创建好后回到本窗口。"
Read-Host "准备好后按回车继续"

git remote remove origin 2>$null
git remote add origin "https://github.com/$user/$repo.git"
git branch -M main
Write-Host ""
Write-Host "[开始推送] 首次推送会弹出 GitHub 登录窗口, 请用浏览器完成授权..."
git push -u origin main
if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "===== 推送成功! ====="
    Write-Host "仓库地址: https://github.com/$user/$repo"
    Write-Host "以后代码有更新, 直接运行本脚本即可再次推送。"
} else {
    Write-Host ""
    Write-Host "[推送失败] 常见原因:"
    Write-Host " 1. 仓库名/用户名拼写错误, 或仓库还没创建"
    Write-Host " 2. 网络不通(检查代理/VPN)"
    Write-Host " 3. 登录未完成——再运行一次本脚本, 弹出的窗口里点 Sign in with your browser"
}
Read-Host "按回车退出"
