param([string]$task, [string]$version="unset")
$ErrorActionPreference = "Stop"
$nuget_packages_uri = "https://nuget.org"

if ((Test-Path ".\nuget.exe") -eq $false)
{ 
	$download = "$nuget_packages_uri/nuget.exe"
    write-output "downloading nuget.exe from $download " 	
	$webClient = new-object net.webclient
	$webClient.DownloadFile($download,'nuget.exe')
}

if ((Test-Path ".\packages\psake\tools\psake.cmd") -eq $false)
{ 
	$SourceUri = "$nuget_packages_uri/api/v2/"
	write-output "Installing psake from $SourceUri"
	.\nuget.exe install psake -Source $SourceUri -ExcludeVersion -OutputDirectory "packages"
}

# Get the buildscript package here: 
#.\nuget.exe install ttl-chocolateypackager -Source "$nuget_packages_uri/api/v2/" -ExcludeVersion -OutputDirectory "packages"


Import-Module '.\packages\psake\tools\psake.psm1'; 
Invoke-psake  default.ps1 -t $task; 
if (($Error -ne '') -and ($error.count -gt 1)) 
{ 
        Write-Host "ERROR: $error" -fore RED; 
        exit $error.Count
} 
else {
  exit 0;
}  