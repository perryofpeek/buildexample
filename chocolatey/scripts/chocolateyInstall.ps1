
$packageName = 'powercli' 
Set-ExecutionPolicy -ExecutionPolicy "RemoteSigned"


$silentArgs = '/q /v /qn'
$validExitCodes = @(0) 
$url = $(Split-Path -parent $MyInvocation.MyCommand.Definition) + "\..\data\VMware-vix-1.11.2-591240.exe"
$url64 = $url
write-host $url 
Start-ChocolateyProcessAsAdmin "$silentArgs" $url -validExitCodes @(0)
#Install-ChocolateyPackage $packageName "exe" "$silentArgs" "$url" "$url64" -validExitCodes $validExitCodes

$silentArgs = '/S /v/qn'
$validExitCodes = @(0) 
$url = $(Split-Path -parent $MyInvocation.MyCommand.Definition) + "\..\data\VMware-PowerCLI-5.1.0-793510.exe"
$url64 = $url
write-host $url 
Start-ChocolateyProcessAsAdmin "$silentArgs" $url -validExitCodes @(0)
#Install-ChocolateyPackage $packageName "exe" "$silentArgs" "$url" "$url64" -validExitCodes $validExitCodes

