$ErrorActionPreference = "Stop"

$archiveDest = "D:\ANTIGRAVITY_WORKSPACE\ANTIGRAVITY_C_ARCHIVE_20260829"
$convDir = "C:\Users\Atul1\.gemini\antigravity\conversations"
$currentConv = "c94751be-95fe-4805-89fc-2c2f7d37f585"

function getFreeSpace {
    return (Get-Volume -DriveLetter C).SizeRemaining
}

$targetBytes = 16.0 * 1024 * 1024 * 1024
$archivedFilesCount = 0
$matchedHashes = $true

$traceFiles = Get-ChildItem -Path $convDir -File -Include "*.pb", "*.tmp" -Recurse | Where-Object {
    $_.Name -notmatch $currentConv -and $_.LastWriteTime -lt (Get-Date).AddMinutes(-30)
} | Sort-Object Length -Descending

foreach ($f in $traceFiles) {
    if ((getFreeSpace) -ge $targetBytes) {
        break
    }

    $srcFile = $f.FullName
    $relPath = "conversations\" + $f.Name
    $dstFile = Join-Path $archiveDest $relPath
    $dstDir = Split-Path $dstFile -Parent
    if (-not (Test-Path $dstDir)) {
        New-Item -Path $dstDir -ItemType Directory -Force | Out-Null
    }

    Copy-Item -Path $srcFile -Destination $dstFile -Force
    $srcHash = (Get-FileHash -Path $srcFile -Algorithm SHA256).Hash
    $srcSize = (Get-Item -Path $srcFile).Length
    $dstHash = (Get-FileHash -Path $dstFile -Algorithm SHA256).Hash
    $dstSize = (Get-Item -Path $dstFile).Length

    if ($srcHash -eq $dstHash -and $srcSize -eq $dstSize) {
        Remove-Item -Path $srcFile -Force
        $archivedFilesCount++
    } else {
        $matchedHashes = $false
        Write-Error "Mismatch on $srcFile. Stopping."
    }
}

$finalSpace = getFreeSpace
Write-Output "ArchivedFiles: $archivedFilesCount"
Write-Output "HashMatch: $matchedHashes"
Write-Output "FreeSpaceGiB: $([math]::Round($finalSpace / 1GB, 2))"
