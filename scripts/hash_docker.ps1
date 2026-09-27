function hashFile($path) {
  $stream = [System.IO.File]::OpenRead($path)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  $hash = $sha.ComputeHash($stream)
  $stream.Close()
  return [BitConverter]::ToString($hash).Replace('-','').ToLower()
}

Write-Output "Hashing source..."
$hashSrc = hashFile "C:\Users\Atul1\AppData\Local\Docker\wsl\disk\docker_data.vhdx"
Write-Output "Source: $hashSrc"
Write-Output "Hashing backup..."
$hashDst = hashFile "D:\ANTIGRAVITY_WORKSPACE\DOCKER_BACKUP_PRE_4_88_1_20260828\docker_data.vhdx"
Write-Output "Backup: $hashDst"

if ($hashSrc -eq $hashDst) {
  Write-Output "HASH MATCH"
} else {
  Write-Output "HASH MISMATCH"
}
