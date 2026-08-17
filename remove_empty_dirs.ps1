$InputNameNormalized = $args[0].TrimEnd('\','/').Replace('./','').Replace('.\','')
$rootDir = "./" + $InputNameNormalized

$emptyDirs = ls $rootDir -Directory -Recurse | where { @(ls $_.FullName -Force).Count -eq 0 }

foreach ($d in $emptyDirs) {
    if (Test-Path $d.FullName) {
        Remove-Item $d.FullName -Force
    }
}