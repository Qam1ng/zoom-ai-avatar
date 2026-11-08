# Turn a short video of yourself into a digital-human avatar.
#   powershell -ExecutionPolicy Bypass -File make-avatar.ps1 -Video "C:\path\to\video.mp4"
#   ... -Start 3 -End 15      use only seconds 3 to 15 of the video
#   ... -Name work            give the avatar another name (default: my_avatar)
#   ... -Force                replace an avatar that already has this name
# Takes about a minute for a 5-second video. Stop the digital human first (stop-avatar.ps1).
# The first run downloads LiveTalking's face detector (about 86 MB, from www.adrianbulat.com).
param(
    [Parameter(Mandatory = $true)][string]$Video,
    [string]$Name = 'my_avatar',
    [double]$Start = 0,
    [double]$End = 0,
    [switch]$Force,
    [int]$BatchSize = 1,
    [string]$ProjectDir = ''
)

function Fail($m) { Write-Host "STOP: $m" -ForegroundColor Red; exit 1 }

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ProjectDir) { $ProjectDir = Join-Path $here 'LiveTalking' }

$vpy = Join-Path $ProjectDir '.venv\Scripts\python.exe'
if (-not (Test-Path $vpy)) { Fail 'LiveTalking is not installed yet. Run install.ps1 first.' }
if (-not (Test-Path -LiteralPath $Video)) { Fail "Video not found: $Video" }
if ($Name -notmatch '^[A-Za-z0-9_]+$') { Fail 'The avatar name may only contain letters, digits and _.' }
if (Get-NetTCPConnection -LocalPort 8010 -State Listen -ErrorAction SilentlyContinue) {
    Fail 'The digital human is running. Stop it first with stop-avatar.ps1 (both need the graphics card).'
}

$avatarDir = Join-Path $ProjectDir "data\avatars\$Name"
if (Test-Path $avatarDir) {
    if (-not $Force) { Fail "An avatar named '$Name' already exists. Add -Force to replace it, or pick another -Name." }
    Remove-Item $avatarDir -Recurse -Force
}

# Work on a copy with a plain name, so non-English characters in the path cannot cause trouble.
$work = Join-Path $ProjectDir 'data\_source'
New-Item -ItemType Directory -Force $work | Out-Null
$copy = Join-Path $work ("input" + [IO.Path]::GetExtension($Video))
Copy-Item -LiteralPath $Video $copy -Force
$cut = Join-Path $work "$Name.mp4"

$env:PYTHONIOENCODING = 'utf-8'
$env:PYTHONUTF8 = '1'
Write-Host '== 1/2 Preparing the video (25 frames per second)' -ForegroundColor Cyan
& $vpy -I (Join-Path $here 'tools\cut_video.py') $copy $cut $Start $End
if ($LASTEXITCODE -ne 0) { Fail 'Could not prepare the video.' }

Write-Host '== 2/2 Finding the face in every frame and building the avatar' -ForegroundColor Cyan
Push-Location $ProjectDir
# One frame at a time: LiveTalking's default of 16 frames at once needs more graphics memory than an
# 8 GB card has, and Windows then slows to a crawl instead of reporting an error (it looks frozen).
# Measured on an RTX 5060 with a 5-second 1280x720 video: 1 frame = 39 s and about 1 GB of graphics
# memory; 4 frames = 60 s and about 5 GB; 16 frames = not finished after 10 minutes.
& $vpy -m avatars.wav2lip.genavatar --video_path $cut --avatar_id $Name --img_size 256 --face_det_batch_size $BatchSize
$code = $LASTEXITCODE
Pop-Location
if ($code -ne 0 -or -not (Test-Path (Join-Path $avatarDir 'coords.pkl'))) {
    if (Test-Path $avatarDir) { Remove-Item $avatarDir -Recurse -Force }      # do not leave a half-made avatar behind
    Fail 'Avatar generation failed (see the messages above).'
}

Write-Host ''
Write-Host "Avatar '$Name' is ready." -ForegroundColor Green
Write-Host "Start it:  powershell -ExecutionPolicy Bypass -File start-avatar.ps1 -Avatar $Name"
