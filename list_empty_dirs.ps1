$InputNameNormalized = $args[0].TrimEnd('\','/').Replace('./','').Replace('.\','')
$rootDir = "./" + $InputNameNormalized

$e = ls $rootDir -Directory -Recurse | where { @(ls $_.FullName -Force).Count -eq 0 }

foreach ($d in $e)
{
    Write-Host "$($e.Count) empty dirs: $($e.Name -join ', ')"
}