Import-Module .\convert_media.psm1 -Force

$InputDirectory = $args[0]
$InputFormats = "formats_videos.txt";
$OutputFormat = "mkv"
$Identifier = "nvenc"
$Command = {
    param($inputFilePath, $outputFilePath)
    ffmpeg -hide_banner -loglevel error -i $inputFilePath -preset fast -c:v hevc_nvenc -cq 20 -c:a aac -b:a 320k $outputFilePath
}

Convert-Media $InputFormats $OutputFormat $Identifier $Command $InputDirectory