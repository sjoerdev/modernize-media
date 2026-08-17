$InputNameNormalized = $args[0].TrimEnd('\','/').Replace('./','').Replace('.\','')
$rootDir = "./" + $InputNameNormalized

$emptyDirs = ls $rootDir -Directory -Recurse | where { @(ls $_.FullName -Force).Count -eq 0 }

foreach ($d in $emptyDirs)
{
    Write-Host "$($emptyDirs.Count) empty dirs: $($emptyDirs.Name -join ', ')"
}