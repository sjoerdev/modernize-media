$rootDir = "./" + $args[0]

Get-ChildItem -Path $rootDir -Recurse -File | Select-Object -ExpandProperty Extension | Sort-Object -Unique