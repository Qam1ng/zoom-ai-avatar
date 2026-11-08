# Install LiveTalking (free, open-source real-time digital human) for the Zoom stand-in.
# Needs: Windows, an NVIDIA graphics card, Python 3.12, Git, OBS Studio. About 7 GB of disk and 6 GB of downloads.
# Safe to run again: finished steps are skipped.
#
#   powershell -ExecutionPolicy Bypass -File install.ps1
param(
    [string]$ProjectDir = (Join-Path $PSScriptRoot 'LiveTalking')
)

$Commit = 'c7269433a2b6ecebcd9342445d2ecc882c98b0da'   # the LiveTalking version this kit was tested with
$RepoUrl = 'https://github.com/lipku/LiveTalking.git'
$ModelsUrl = 'https://drive.google.com/drive/folders/1FOC_MD6wdogyyX_7V1d4NDIO7P9NlSAJ'

function Step($m) { Write-Host ''; Write-Host "== $m" -ForegroundColor Cyan }
function Fail($m) { Write-Host ''; Write-Host "STOP: $m" -ForegroundColor Red; exit 1 }

# ---------------------------------------------------------------- 1. requirements
Step '1/7 Checking this computer'
if (-not (Get-Command nvidia-smi -ErrorAction SilentlyContinue)) {
    Fail 'No NVIDIA graphics card (or driver) found. The digital human needs one; use the OBS looping video instead.'
}
Write-Host ('Graphics card: ' + ((& nvidia-smi --query-gpu=name,memory.total --format=csv,noheader) -join '; '))

$py = $null
if (Get-Command py -ErrorAction SilentlyContinue) {
    $found = & py -3.12 -c "import sys; print(sys.executable)" 2>$null
    if ($LASTEXITCODE -eq 0 -and $found) { $py = "$found".Trim() }
}
if (-not $py) {
    $guess = Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312\python.exe'
    if (Test-Path $guess) { $py = $guess }
}
if (-not $py) { Fail 'Python 3.12 not found. Install it, then run this script again:  winget install --id Python.Python.3.12 -e' }
Write-Host "Python: $py"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Fail 'Git not found. Install it, open a NEW PowerShell window, then run this script again:  winget install --id Git.Git -e'
}
if (-not (Test-Path 'C:\Program Files\obs-studio\bin\64bit\obs64.exe')) {
    Fail 'OBS Studio not found (it provides the virtual camera). Install it, then run this script again:  winget install --id OBSProject.OBSStudio -e'
}

# ---------------------------------------------------------------- 2. source code
Step '2/7 Getting the LiveTalking source code'
if (Test-Path (Join-Path $ProjectDir 'app.py')) {
    Write-Host 'Already there.'
} else {
    New-Item -ItemType Directory -Force $ProjectDir | Out-Null
    & git -C $ProjectDir init -q
    & git -C $ProjectDir fetch -q --depth 1 $RepoUrl $Commit
    if ($LASTEXITCODE -ne 0) { Fail 'Could not download the source code from GitHub. Check the network and run again.' }
    & git -C $ProjectDir checkout -q FETCH_HEAD
    if ($LASTEXITCODE -ne 0) { Fail 'git checkout failed. If it says "Filename too long", move this folder to a shorter path (for example C:\zoom-standin) and run again.' }
}

# ---------------------------------------------------------------- 3. python environment
Step '3/7 Creating the Python environment'
$vpy = Join-Path $ProjectDir '.venv\Scripts\python.exe'
if (Test-Path $vpy) {
    Write-Host 'Already there.'
} else {
    & $py -m venv (Join-Path $ProjectDir '.venv')
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $vpy)) { Fail 'Could not create the Python environment.' }
}
& $vpy -m pip install --upgrade pip --quiet --disable-pip-version-check

# ---------------------------------------------------------------- 4. PyTorch
Step '4/7 Installing PyTorch for the graphics card (largest download, about 3 GB)'
& $vpy -c "import torch, torchvision, torchaudio; assert torch.__version__.startswith('2.9.1')" 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host 'Already installed.'
} else {
    & $vpy -m pip install torch==2.9.1 torchvision==0.24.1 torchaudio==2.9.1 --index-url https://download.pytorch.org/whl/cu128 --disable-pip-version-check
    if ($LASTEXITCODE -ne 0) { Fail 'PyTorch install failed. Check the network and run again.' }
}

# ---------------------------------------------------------------- 5. other packages
Step '5/7 Installing the other packages'
& $vpy -m pip install -r (Join-Path $ProjectDir 'requirements.txt') pyvirtualcam pyaudio gdown --quiet --disable-pip-version-check
if ($LASTEXITCODE -ne 0) { Fail 'Package install failed. Check the network and run again.' }
$gpu = & $vpy -c "import torch; print('yes: ' + torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'NO')"
Write-Host "Graphics card usable by PyTorch: $gpu"
if ("$gpu" -notmatch '^yes') {
    Write-Host 'WARNING: PyTorch cannot use the graphics card. Update the NVIDIA driver; without it the picture will stutter.' -ForegroundColor Yellow
}

# ---------------------------------------------------------------- 6. model + sample avatar
Step '6/7 Downloading the lip-sync model (205 MB) and the sample avatar (337 MB)'
$dl = Join-Path $ProjectDir '_downloads'
$model = Join-Path $ProjectDir 'models\wav2lip.pth'
$sample = Join-Path $ProjectDir 'data\avatars\wav2lip256_avatar1'
$needModel = -not (Test-Path $model)
$needSample = -not (Test-Path (Join-Path $sample 'coords.pkl'))
if (-not $needModel -and -not $needSample) {
    Write-Host 'Already there.'
} else {
    New-Item -ItemType Directory -Force $dl, (Join-Path $ProjectDir 'models'), (Join-Path $ProjectDir 'data\avatars') | Out-Null
    $pth = Join-Path $dl 'wav2lip256.pth'
    $tgz = Join-Path $dl 'wav2lip256_avatar1.tar.gz'
    if (-not (Test-Path $pth) -or -not (Test-Path $tgz)) {
        $env:PYTHONIOENCODING = 'utf-8'
        & (Join-Path $ProjectDir '.venv\Scripts\gdown.exe') --folder $ModelsUrl -O $dl
    }
    if (-not (Test-Path $pth) -or -not (Test-Path $tgz)) {
        Write-Host ''
        Write-Host 'The automatic download from Google Drive did not work (it is sometimes blocked or over quota).' -ForegroundColor Yellow
        Write-Host "Open this folder in a browser:  $ModelsUrl"
        Write-Host 'Download  wav2lip256.pth  and  wav2lip256_avatar1.tar.gz  and put both files into:'
        Write-Host "  $dl"
        Fail 'Then run this script again.'
    }
    if ($needModel) { Copy-Item $pth $model -Force }
    if ($needSample) {
        & $vpy -I (Join-Path $PSScriptRoot 'tools\untar_safe.py') $tgz (Join-Path $ProjectDir 'data\avatars')
        if ($LASTEXITCODE -ne 0) { Fail 'Could not unpack the sample avatar.' }
    }
}

# ---------------------------------------------------------------- 7. keep the control page private
Step '7/7 Limiting the control page to this computer'
$app = Join-Path $ProjectDir 'app.py'
$text = [IO.File]::ReadAllText($app, [Text.Encoding]::UTF8)
$open = "web.TCPSite(runner, '0.0.0.0', opt.listenport)"
if ($text.Contains($open)) {
    $text = $text.Replace($open, "web.TCPSite(runner, '127.0.0.1', opt.listenport)")
    [IO.File]::WriteAllText($app, $text, (New-Object Text.UTF8Encoding($false)))
    Write-Host 'Done (the original setting lets every device on the network open the control page).'
} else {
    Write-Host 'Already done.'
}

Write-Host ''
Write-Host 'Installed.' -ForegroundColor Green
Write-Host 'Try the sample avatar:   powershell -ExecutionPolicy Bypass -File start-avatar.ps1 -Avatar wav2lip256_avatar1'
Write-Host 'Make your own avatar:    powershell -ExecutionPolicy Bypass -File make-avatar.ps1 -Video "C:\path\to\video.mp4"'
