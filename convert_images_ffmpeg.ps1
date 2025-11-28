Import-Module .\convert_media.psm1 -Force

$InputDirectory = $args[0]
$InputFormats = "formats_images.txt";
$OutputFormat = "avif"
$Identifier = "libsvtav1"
$Command = {
    param($inputFilePath, $outputFilePath)
    $env:SVT_LOG = 1
    ffmpeg -hide_banner -loglevel error -i $inputFilePath -c:v libsvtav1 -preset 8 -crf 20 $outputFilePath
}

Convert-Media $InputFormats $OutputFormat $Identifier $Command $InputDirectory