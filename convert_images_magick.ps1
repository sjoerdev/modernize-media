Import-Module .\convert_media.psm1 -Force

$InputDirectory = $args[0]
$InputFormats = "formats_images.txt";
$OutputFormat = "avif"
$Identifier = "magick"
$Command = {
    param($inputFilePath, $outputFilePath)
    magick $inputFilePath $outputFilePath
}

Convert-Media $InputFormats $OutputFormat $Identifier $Command $InputDirectory