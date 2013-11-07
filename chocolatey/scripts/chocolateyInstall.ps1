$package = 'Application' 
$destination = "c:\apps\Application"
$appPath = "$destination\Application.exe"
try {
    Make-Folder -name $destination
    $files = $(Split-Path -parent $MyInvocation.MyCommand.Definition) + "\..\data\*.*"
    Copy-item  -recurse -Path $file -destination $destination -force
    Start-ChocolateyProcessAsAdmin "install" $appPath -validExitCodes @(0)
    #Start service?
    Write-ChocolateySuccess $package
}
catch {
  Write-ChocolateyFailure $package "$($_.Exception.Message)"
  throw
}

function Make-Folder {
  param($Name)
  if ((Test-path -path $Name -pathtype container) -eq $false)
    {       
        mkdir $Name -verbose:$false
    }
}