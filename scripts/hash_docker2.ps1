function hashFile($path) {
  \ = [System.IO.File]::OpenRead($path)
  \ = [System.Security.Cryptography.SHA256]::Create()
  \ = \.ComputeHash(\)
  \.Close()
  return [BitConverter]::ToString(\).Replace('-','').ToLower()
}
Write-Output "Hashing source..."
\ = hashFile "C:\Users\Atul1\AppData\Local\Docker\wsl\disk\docker_data.vhdx"
Write-Output "Source: \"
Write-Output "Hashing backup..."
\ = hashFile "D:\ANTIGRAVITY_WORKSPACE\DOCKER_BACKUP_PRE_4_88_1_20260828\docker_data.vhdx"
Write-Output "Backup: \"
if (\ -eq \) {
  Write-Output "HASH MATCH"
} else {
  Write-Output "HASH MISMATCH"
}
