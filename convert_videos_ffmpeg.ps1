Import-Module .\convert_media.psm1 -Force

$InputDirectory = $args[0]
$InputFormats = "formats_videos.txt";
$OutputFormat = "mkv"
$Identifier = "libsvtav1"
$Command = {
    param($inputFilePath, $outputFilePath)
    ffmpeg -hide_banner -loglevel error -i $inputFilePath -c:v libsvtav1 -preset 8 -crf 26 -c:a aac -b:a 320k $outputFilePath
}

Convert-Media $InputFormats $OutputFormat $Identifier $Command $InputDirectory