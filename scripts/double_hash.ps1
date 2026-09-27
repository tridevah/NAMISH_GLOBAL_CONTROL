$vhdx = "C:\Users\Atul1\AppData\Local\Docker\wsl\disk\docker_data.vhdx"
Write-Output "Hashing VHDX First Time..."
$hash1 = (Get-FileHash -Path $vhdx -Algorithm SHA256).Hash
Write-Output "Hash1: $hash1"

Write-Output "Waiting 30 seconds..."
Start-Sleep -Seconds 30

Write-Output "Hashing VHDX Second Time..."
$hash2 = (Get-FileHash -Path $vhdx -Algorithm SHA256).Hash
Write-Output "Hash2: $hash2"

if ($hash1 -eq $hash2) {
    Write-Output "DOUBLE HASH MATCH"
} else {
    Write-Output "DOUBLE HASH MISMATCH"
}
