while ($true) {
    $freeSpace = (Get-Volume -DriveLetter D).SizeRemaining / 1GB
    if ($freeSpace -lt 35) {
        New-Item -ItemType File -Force -Path "D:\ANTIGRAVITY_WORKSPACE\LGD_IMPORT_RUNTIME\R12\STOP_REQUESTED"
        Write-Output "D drive space below 35 GiB ($freeSpace). Created STOP_REQUESTED."
        break
    }
    Start-Sleep -Seconds 30
}
