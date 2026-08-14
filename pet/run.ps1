# ASCII-name shim: forward to the launcher (启动器.ps1) with any args
& (Join-Path $PSScriptRoot "启动器.ps1") @args
