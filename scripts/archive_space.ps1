$ErrorActionPreference = "Stop"

$archiveDest = "D:\ANTIGRAVITY_WORKSPACE\ANTIGRAVITY_C_ARCHIVE_20260829"
New-Item -Path $archiveDest -ItemType Directory -Force | Out-Null

$currentConv = "c94751be-95fe-4805-89fc-2c2f7d37f585"

# Target conversations
$targetConvs = @(
    "33634b6a-7649-45aa-8627-e8eb044551de",
    "7c11d87f-b463-4a3c-95b9-248f1515777c",
    "f681041f-6488-4fa3-9f6e-0bc30574c3ac",
    "62811c86-0a26-4be6-a0db-81f83f736da9"
)

$filesToArchive = @()
$convDir = "C:\Users\Atul1\.gemini\antigravity\conversations"
foreach ($cid in $targetConvs) {
    if (Test-Path "$convDir\$cid.db") { $filesToArchive += "$convDir\$cid.db" }
    if (Test-Path "$convDir\$cid.db-wal") { $filesToArchive += "$convDir\$cid.db-wal" }
    if (Test-Path "$convDir\$cid.db-shm") { $filesToArchive += "$convDir\$cid.db-shm" }
}

# Target scratch contents
$scratchDir = "C:\Users\Atul1\.gemini\antigravity\scratch"
if (Test-Path $scratchDir) {
    $scratchFiles = Get-ChildItem -Path $scratchDir -Recurse -File | Where-Object {
        $_.FullName -notmatch "node_modules" -and $_.FullName -notmatch "\.git" -and
        $_.LastWriteTime -lt (Get-Date).AddMinutes(-30)
    }
    foreach ($f in $scratchFiles) {
        $filesToArchive += $f.FullName
    }
}

Write-Output "Found $($filesToArchive.Count) files to archive."

$manifest = @()

foreach ($srcFile in $filesToArchive) {
    # Generate relative path inside the archive
    # Base is C:\Users\Atul1\.gemini\antigravity
    $relPath = $srcFile.Substring("C:\Users\Atul1\.gemini\antigravity\".Length)
    $dstFile = Join-Path $archiveDest $relPath
    $dstDir = Split-Path $dstFile -Parent
    if (-not (Test-Path $dstDir)) {
        New-Item -Path $dstDir -ItemType Directory -Force | Out-Null
    }

    # Copy file
    Copy-Item -Path $srcFile -Destination $dstFile -Force

    # Hash source
    $srcHash = (Get-FileHash -Path $srcFile -Algorithm SHA256).Hash
    $srcSize = (Get-Item -Path $srcFile).Length

    # Hash dest
    $dstHash = (Get-FileHash -Path $dstFile -Algorithm SHA256).Hash
    $dstSize = (Get-Item -Path $dstFile).Length

    if ($srcHash -eq $dstHash -and $srcSize -eq $dstSize) {
        # Delete source if matched perfectly
        Remove-Item -Path $srcFile -Force
        $manifest += [PSCustomObject]@{
            RelativePath = $relPath
            Size = $dstSize
            SHA256 = $dstHash
        }
    } else {
        Write-Error "Mismatch on $srcFile. SrcHash: $srcHash DstHash: $dstHash. Stopping."
    }
}

$manifestPath = Join-Path $archiveDest "manifest.csv"
$manifest | Export-Csv -Path $manifestPath -NoTypeInformation

$totalRecovered = ($manifest | Measure-Object -Property Size -Sum).Sum
Write-Output "Archived $($manifest.Count) files."
Write-Output "Recovered space: $([math]::Round($totalRecovered / 1MB, 2)) MB"
