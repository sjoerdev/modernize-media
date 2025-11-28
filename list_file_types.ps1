$InputNameNormalized = $args[0].TrimEnd('\','/').Replace('./','').Replace('.\','')
$rootDir = "./" + $InputNameNormalized

Get-ChildItem -Path $rootDir -Recurse -File | Select-Object -ExpandProperty Extension | Sort-Object -Unique