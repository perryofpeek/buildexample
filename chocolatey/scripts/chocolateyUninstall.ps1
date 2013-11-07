$package = 'Application' 
$destination = "c:\apps\Application"
$appPath = "$destination\Application.exe"
try {

    #Stop service?      
    Start-ChocolateyProcessAsAdmin "uninstall" $appPath -validExitCodes @(0)
    Delete-Folder -name $destination    
    Write-ChocolateySuccess $package
}
catch {
  Write-ChocolateyFailure $package "$($_.Exception.Message)"
  throw
}

function Delete-Folder {
  param($Name)
  if ((Test-path -path $Name -pathtype container) -eq $ture)
  {       
        rmdir $Name -verbose:$false -force
  }
}