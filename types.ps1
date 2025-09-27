$rootDir = "./" + $args[0]

Get-ChildItem -Path $rootDir -Recurse -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Extension | Sort-Object -Unique