$InputNameNormalized = $args[0].TrimEnd('\','/').Replace('./','').Replace('.\','')
$rootDir = "./" + $InputNameNormalized

$emptyDirs = ls $rootDir -Directory -Recurse | where { @(ls $_.FullName -Force).Count -eq 0 }

Write-Host "total empty dirs: $($emptyDirs.Count)"
foreach ($d in $emptyDirs)
{
    Write-Host "$($d.FullName)"
}