$lockFile = 'D:\ANTIGRAVITY_WORKSPACE\LGD_IMPORT_RUNTIME\R13\STOP_REQUESTED'
while ($true) {
    $free = (Get-Volume -DriveLetter D).SizeRemaining
    if ($free -lt 59055800320) { # 55 GiB
        New-Item -Path $lockFile -ItemType File -Force
        break
    }
    Start-Sleep -Seconds 30
}
