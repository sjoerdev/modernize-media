$RootPath = "./wdmycloud_backup"

$Files = Get-ChildItem -Path $RootPath -Recurse -File

$FileTypeCounts = $Files | Group-Object -Property Extension | Sort-Object Count -Descending

Write-Host "File type counts in $RootPath"
foreach ($Type in $FileTypeCounts)
{
    $Extension = if ([string]::IsNullOrWhiteSpace($Type.Name)) { "[No Extension]" } else { $Type.Name }
    Write-Host "$Extension : $($Type.Count)"
}