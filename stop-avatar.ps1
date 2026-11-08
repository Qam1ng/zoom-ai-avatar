# Stop the digital human (frees the virtual camera and the graphics card).
#   powershell -ExecutionPolicy Bypass -File stop-avatar.ps1
$procs = Get-CimInstance Win32_Process -Filter "name='python.exe'" |
    Where-Object { $_.CommandLine -match 'app\.py' -and $_.CommandLine -match 'virtualcam' }
if (-not $procs) { Write-Host 'Not running.'; exit 0 }
foreach ($p in $procs) {
    Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
    Write-Host "Stopped process $($p.ProcessId)"
}
