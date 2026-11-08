# Start the digital human and send it to "OBS Virtual Camera".
#   powershell -ExecutionPolicy Bypass -File start-avatar.ps1                              your own avatar (my_avatar)
#   powershell -ExecutionPolicy Bypass -File start-avatar.ps1 -Avatar wav2lip256_avatar1   the official sample
# Control page (type text for it to say): http://localhost:8010/virtualcam.html
param(
    [string]$Avatar = 'my_avatar',
    [string]$ProjectDir = (Join-Path $PSScriptRoot 'LiveTalking')
)

function Fail($m) { Write-Host "STOP: $m" -ForegroundColor Red; exit 1 }

$vpy = Join-Path $ProjectDir '.venv\Scripts\python.exe'
if (-not (Test-Path $vpy)) { Fail 'LiveTalking is not installed yet. Run install.ps1 first.' }
if (-not (Test-Path (Join-Path $ProjectDir "data\avatars\$Avatar\coords.pkl"))) {
    Fail "Avatar '$Avatar' not found. Make it with make-avatar.ps1, or use -Avatar wav2lip256_avatar1."
}
if (Get-NetTCPConnection -LocalPort 8010 -State Listen -ErrorAction SilentlyContinue) {
    Fail 'Already running (port 8010 is in use). Run stop-avatar.ps1 first.'
}
if (Get-Process obs64 -ErrorAction SilentlyContinue) {
    Write-Host 'WARNING: OBS is open. If its own virtual camera is started, stop it: only one program can feed the camera.' -ForegroundColor Yellow
}

$out = Join-Path $ProjectDir 'logs_standin'
New-Item -ItemType Directory -Force $out | Out-Null
$log = Join-Path $out 'app_err.txt'
$env:PYTHONIOENCODING = 'utf-8'
$env:PYTHONUTF8 = '1'
$p = Start-Process -FilePath $vpy `
    -ArgumentList 'app.py', '--transport', 'virtualcam', '--model', 'wav2lip', '--avatar_id', $Avatar `
    -WorkingDirectory $ProjectDir -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput (Join-Path $out 'app_out.txt') -RedirectStandardError $log

Write-Host "Starting avatar '$Avatar', loading the model (about 20 seconds)..."
$deadline = (Get-Date).AddSeconds(180)
while ((Get-Date) -lt $deadline) {
    if ($p.HasExited) { Fail "It stopped by itself. Look at the end of: $log" }
    if (Select-String -Path $log -Pattern 'VirtualCam output started' -Quiet) {
        Write-Host 'Ready.' -ForegroundColor Green
        Write-Host 'In Zoom choose the camera "OBS Virtual Camera".'
        Write-Host 'Control page: http://localhost:8010/virtualcam.html'
        exit 0
    }
    Start-Sleep -Seconds 2
}
Fail "Still not ready after 3 minutes. Look at the end of: $log"
