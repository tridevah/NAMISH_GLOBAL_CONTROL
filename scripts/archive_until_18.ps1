$ErrorActionPreference = "Stop"

$archiveDest = "D:\ANTIGRAVITY_WORKSPACE\ANTIGRAVITY_C_ARCHIVE_20260829"
$convDir = "C:\Users\Atul1\.gemini\antigravity\conversations"
$currentConv = "c94751be-95fe-4805-89fc-2c2f7d37f585"

function getFreeSpace {
    return (Get-Volume -DriveLetter C).SizeRemaining
}

$targetBytes = 18.001 * 1GB
$archivedFilesCount = 0
$matchedHashes = $true

$dbFiles = Get-ChildItem -Path $convDir -Filter "*.db" | Where-Object { $_.Name -notmatch $currentConv } | Sort-Object Length -Descending

foreach ($db in $dbFiles) {
    if ((getFreeSpace) -ge $targetBytes) {
        break
    }

    $baseName = $db.Name
    $filesToMove = @()
    if (Test-Path "$convDir\$baseName") { $filesToMove += "$convDir\$baseName" }
    if (Test-Path "$convDir\${baseName}-wal") { $filesToMove += "$convDir\${baseName}-wal" }
    if (Test-Path "$convDir\${baseName}-shm") { $filesToMove += "$convDir\${baseName}-shm" }

    foreach ($srcFile in $filesToMove) {
        $relPath = "conversations\" + (Split-Path $srcFile -Leaf)
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
}

$finalSpace = getFreeSpace
Write-Output "ArchivedFiles: $archivedFilesCount"
Write-Output "HashMatch: $matchedHashes"
Write-Output "FreeSpaceGB: $([math]::Round($finalSpace / 1GB, 2))"
