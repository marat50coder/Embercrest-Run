# Relaunch the game on the attached device and grab a few screenshots.
param(
  [int]$MenuWait = 14,
  [switch]$PlayRun
)

$ErrorActionPreference = 'Continue'
$out = Join-Path $PSScriptRoot 'preview'

function Grab($name) {
  adb shell screencap -p /sdcard/_s.png | Out-Null
  adb pull /sdcard/_s.png (Join-Path $out $name) 2>&1 | Out-Null
  Write-Output "captured $name"
}

adb shell input keyevent KEYCODE_WAKEUP | Out-Null
adb shell am force-stop com.embercrest.rungame | Out-Null
Start-Sleep -Seconds 1
adb shell am start -n com.embercrest.rungame/.MainActivity | Out-Null
Start-Sleep -Seconds $MenuWait
Grab 'shot_menu.png'

if ($PlayRun) {
  # START RUN sits in the right half of the landscape menu.
  adb shell input tap 1650 400 | Out-Null
  Start-Sleep -Seconds 4
  Grab 'shot_run_a.png'
  # Hold to steer for a moment so the crest curves.
  adb shell input swipe 1500 700 1900 700 900 | Out-Null
  Start-Sleep -Seconds 3
  Grab 'shot_run_b.png'
  adb shell input swipe 600 700 300 700 900 | Out-Null
  Start-Sleep -Seconds 4
  Grab 'shot_run_c.png'
}
