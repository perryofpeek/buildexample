$package = "ttl-powercli"


try
{
 
  $silentArgs = '/S /v/qn'
  $validExitCodes = @(0) 
  $url = $(Split-Path -parent $MyInvocation.MyCommand.Definition) + "\..\data\VMware-PowerCLI-5.1.0-793510.exe"
  $url64 = $url
  write-host $url 
  Start-ChocolateyProcessAsAdmin "$silentArgs" $url -validExitCodes @(0)
  
  Uninstall-ChocolateyPackage "$url" "exe" "/S /v/qn /V/x " "$file"

  Write-ChocolateySuccess $package
}
catch
{
  Write-ChocolateyFailure $package "$($_.Exception.Message)"
  throw
}