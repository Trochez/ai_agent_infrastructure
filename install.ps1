$ErrorActionPreference = "Stop"
Write-Host "AI Agent Infrastructure uses the Linux/WSL execution model."
$wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
if (-not $wsl) {
  Write-Host "WSL is not installed. Install it first with:"
  Write-Host "  wsl --install"
  exit 1
}
$argsJoined = ($args | ForEach-Object { "'" + ($_ -replace "'", "'\''") + "'" }) -join " "
$win = (Get-Location).Path
$linux = (wsl.exe wslpath -a "$win").Trim()
wsl.exe bash -lc "cd '$linux' && bash ./install.sh $argsJoined"
exit $LASTEXITCODE
