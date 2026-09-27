Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = "D:\ANTIGRAVITY_WORKSPACE\INDIA_GEOGRAPHY_MANUAL_DOWNLOAD_20260826"
$files = Get-ChildItem -Path $root -Recurse -File
$results = @()

foreach ($file in $files) {
    if ($file.Extension -eq ".zip") {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($file.FullName)
        foreach ($entry in $zip.Entries) {
            $results += [PSCustomObject]@{
                State = $file.Directory.Name
                FileName = $entry.Name
                Size = $entry.Length
                Type = "Inside Zip"
            }
        }
        $zip.Dispose()
    } else {
        $results += [PSCustomObject]@{
            State = "ALL_INDIA"
            FileName = $file.Name
            Size = $file.Length
            Type = "Standalone"
        }
    }
}

$grouped = $results | Group-Object State
foreach ($g in $grouped) {
    Write-Host "--- $($g.Name) ---"
    $filesInGroup = $g.Group | Select-Object FileName, Size
    foreach ($f in $filesInGroup) {
        Write-Host "  $($f.FileName) ($($f.Size) bytes)"
    }
}
