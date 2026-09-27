$ErrorActionPreference = "Stop"

$archiveDest = "D:\ANTIGRAVITY_WORKSPACE\DOCKER_BACKUP_PRE_4_88_1_REFRESHED_20260829"
New-Item -Path $archiveDest -ItemType Directory -Force | Out-Null

$srcFile = "C:\Users\Atul1\AppData\Local\Docker\wsl\disk\docker_data.vhdx"
$dstFile = Join-Path $archiveDest "docker_data.vhdx"

Write-Output "Copying VHDX to refreshed backup..."
# We use Copy-Item instead of robocopy so we can track errors in PS easily, though robocopy is faster for huge files.
# Actually, robocopy is much better for 71GB.
robocopy "C:\Users\Atul1\AppData\Local\Docker\wsl\disk" $archiveDest docker_data.vhdx /J /Z

Write-Output "Hashing source..."
$srcHash = (Get-FileHash -Path $srcFile -Algorithm SHA256).Hash
$srcSize = (Get-Item -Path $srcFile).Length

Write-Output "Hashing backup..."
$dstHash = (Get-FileHash -Path $dstFile -Algorithm SHA256).Hash
$dstSize = (Get-Item -Path $dstFile).Length

if ($srcHash -eq $dstHash -and $srcSize -eq $dstSize) {
    Write-Output "REFRESHED BACKUP MATCH: $srcHash"
} else {
    Write-Error "Mismatch! SrcHash: $srcHash DstHash: $dstHash"
}
