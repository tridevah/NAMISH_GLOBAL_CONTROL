Write-Host 'Waiting for PID 21796 to exit...'
Wait-Process -Id 21796 -ErrorAction SilentlyContinue
Write-Host 'PID 21796 exited. Launching R7 scaffold...'
node scripts/lgd_import_r7.js
Write-Host 'R7 scaffold complete. Launching R7 physical...'
Remove-Item 'D:\ANTIGRAVITY_WORKSPACE\LGD_IMPORT_RUNTIME\R7\STOP_REQUESTED' -Force -ErrorAction SilentlyContinue
Remove-Item 'D:\ANTIGRAVITY_WORKSPACE\LGD_IMPORT_RUNTIME\R7\checkpoint.json' -Force -ErrorAction SilentlyContinue
node scripts/lgd_import_r7_physical.js
