while ($true) {
    Start-Sleep -Seconds 30
    $freeSpace = [math]::Round((Get-Volume -DriveLetter D).SizeRemaining / 1GB, 2)
    if ($freeSpace -lt 40) {
        New-Item -Path "D:\ANTIGRAVITY_WORKSPACE\LGD_IMPORT_RUNTIME\R12\STOP_REQUESTED" -ItemType File -Force
        Add-Content -Path "D:\ANTIGRAVITY_WORKSPACE\LGD_IMPORT_RUNTIME\R12\STOP_REQUESTED" -Value "Disk space critical: $freeSpace GiB remaining"
        break
    }
}
