properties {
  $name = "ApplicationName"
  $version = '1.0.0'
  $nuget_packages_uri = "https://nuget.org"
  $Build_Configuration = 'Release'
  $Company = "Company Name";
  $Description = "Application description";
  $Product = "$Name $version";
  $Title = "$Name $version";
  $chocolateySource = "http://192.168.1.99:8081/artifactory/api/nuget/chocolatey-packages"
  $apiKey = "admin:password"    
    
  
  ## Should not need to change these 
  if(Is-CIBuild -eq $true)
  {
    $buildNumber = $ENV:GO_PIPELINE_LABEL
    $version = "1.0.0.$buildNumber"
  }

  $year = Get-Date -UFormat "%Y"
  $Copyright = " (C) Copyright $company $year";
  $SourceUri = "$nuget_packages_uri/api/v2/"
  $tmp_files = Get-ChildItem *.sln 
  $Build_Solution =  $tmp_files.Name  
  $nuspecFile = "project.nuspec"    
  $pwd = pwd
  $msbuild = "C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe"
  $nunit =  "$pwd\packages\NUnit.Runners\tools\nunit-console-x86.exe"
  $openCover = "$pwd\packages\OpenCover\OpenCover.Console.exe"
  $reportGenerator = "$pwd\packages\ReportGenerator\ReportGenerator.exe"
  $TestOutput = "$pwd\BuildOutput"
  $UnitTestOutputFolder = "$TestOutput\UnitTestOutput"
  $Build_Artifacts = "$TestOutput\BuildArtifacts"    
}

task default -depends Init, Compile, Test, Report, Package , Create-ChocolateyPackage, Push-ChocolateyPackage #NugetPackage, Report

task Init -depends GetTools, GetNugetPackages {	

}

task Package {   
  Make-Folder -Name $Build_Artifacts
  Copy-item src\*\output\* $Build_Artifacts\
  Write-NuspecFile -dataPath $Build_Artifacts -version $version -title $Name -authors $company -owners $company -summary $Product -description $Description -tags $Product -copyright $copyright
}

task GetTools {
	Install-Package -name "NUnit.Runners" -testpath $nunit
  Install-Package -name "OpenCover" -testpath $openCover
  Install-Package -name "ReportGenerator" -testpath $reportGenerator
}

task GetNugetPackages {
    $files = Get-ChildItem .\* -recurse | Where-Object {$_.Fullname.Contains("packages.config")}
    foreach ($file in $files)
    {
        Write-host "installing nuget packages from " $file.FullName
        Exec {.\nuget.exe install $file.Fullname -Source $SourceUri -OutputDirectory "packages"}
    }
}

task PatchAssemblyInfo {

	$files = Get-ChildItem src\* -recurse | Where-Object {$_.Fullname.Contains("AssemblyInfo.cs")}
	foreach ($file in $files)
	{
		Generate-Assembly-Info `
        -file $file.Fullname `
        -title $Title `
        -description $Description `
        -company $Company `
        -product $Product `
        -version $version `
        -copyright $Copyright
	}
}

task Test -Depends Compile  { 			
	
    Make-Folder -Name $TestOutput
    Make-Folder -Name $UnitTestOutputFolder
     
	$unitTestFolders = Get-ChildItem test\* -recurse | Where-Object {$_.PSIsContainer -eq $True} | where-object {$_.Fullname.Contains("output")} | where-object {$_.Fullname.Contains("output\") -eq $false}| select-object FullName
	foreach($folder in $unitTestFolders)
	{
		$x = [string] $folder.FullName
		copy-item -force -path $x\* -Destination "$UnitTestOutputFolder\" 
	}
	#Copy all the unit test folders into one folder 
	cd $UnitTestOutputFolder
	foreach($file in Get-ChildItem *test*.dll)
	{
		$files = $files + " " + $file.Name
	}
	#write-host $files
	Exec { & $openCover "-target:$nunit" "-filter:-[.*test*]* +[*]* " -register:user -mergebyhash "-targetargs:$files /err=err.nunit.txt /noshadow /nologo /config=SqlToGraphite.UnitTests.dll.config" }     
	Exec { & $reportGenerator "-reports:results.xml" "-targetdir:..\report" "-verbosity:Error" "-reporttypes:Html;HtmlSummary;XmlSummary"}	
	cd $pwd	
}

task Compile -depends Init, PatchAssemblyInfo, Clean {  
   Exec {  & $msbuild /m:4 /verbosity:quiet /nologo /p:OutDir=""$Build_Artifacts\"" /t:Rebuild /p:Configuration=$Build_Configuration $Build_Solution }   	
}


task Clean {
	Delete-Folder -Name $Build_Artifacts
  Delete-Folder -Name $TestOutput
  Delete-File -Name  $nuspecFile
  Delete-File -Name  "*.nupkg"
  Exec {  & $msbuild /m:4 /verbosity:quiet /nologo /p:OutDir=""$Build_Artifacts\"" /t:Clean $Build_Solution }  
}

task Report -Depends Test {
	write-host "================================================================="	
	$xmldata = [xml](get-content BuildOutput\UnitTestOutput\testresult.xml)	
	write-host "Total tests "$xmldata."test-results".GetAttribute("total") " Errors "$xmldata."test-results".GetAttribute("errors") " Failures " $xmldata."test-results".GetAttribute("failures") "Not-run "$xmldata."test-results".GetAttribute("not-run") "Ignored "$xmldata."test-results".GetAttribute("ignored")
	$xmldata1 = [xml](get-content "$TestOutput\report\summary.xml")
	$xmldata1.SelectNodes("/CoverageReport/Summary")
}


task Create-ChocolateyPackage { 
    exec { cpack @(Get-Item *.nuspec)[0]}
}

task Push-ChocolateyPackage { 
    if (Is-CIBuild -eq $true)
    {
        & ".\NuGet.exe" setApiKey "$apiKey"  -Source "$chocolateySource"    
        $file = @(Get-Item *.nupkg)[0]
        Exec { cpush $file -Source "$chocolateySource" }
    }
    else
    {
        write-host "not pushing, this should be done in CI build"
    }   
}



task ? -Description "Helper to display task info" {
    Write-Documentation
}

function Is-CIBuild
{
   return $true
   Test-Path -path Env:\GO_PIPELINE_LABEL 
}

function Get-Git-Commit
{
    $gitLog = git log --oneline -1
    return $gitLog.Split(' ')[0]
}

function Generate-Assembly-Info
{
param(
    [string]$clsCompliant = "true",
    [string]$title, 
    [string]$description, 
    [string]$company, 
    [string]$product, 
    [string]$copyright, 
    [string]$version,
    [string]$file = $(Throw "file is a required parameter.")
)
  $commit = Get-Git-Commit
  $asmInfo = "using System;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

[assembly: CLSCompliantAttribute($clsCompliant)]
[assembly: ComVisibleAttribute(false)]
[assembly: AssemblyTitleAttribute(""$title"")]
[assembly: AssemblyDescriptionAttribute(""$description"")]
[assembly: AssemblyCompanyAttribute(""$company"")]
[assembly: AssemblyProductAttribute(""$product"")]
[assembly: AssemblyCopyrightAttribute(""$copyright"")]
[assembly: AssemblyVersionAttribute(""$version"")]
[assembly: AssemblyInformationalVersionAttribute(""$version / $commit"")]
[assembly: AssemblyFileVersionAttribute(""$version"")]
[assembly: AssemblyDelaySignAttribute(false)]
"

    $dir = [System.IO.Path]::GetDirectoryName($file)
    if ([System.IO.Directory]::Exists($dir) -eq $false)
    {
        Write-Host "Creating directory $dir"
        [System.IO.Directory]::CreateDirectory($dir)
    }
   # Write-Host "Generating assembly info file: $file"
    out-file -filePath $file -encoding UTF8 -inputObject $asmInfo
}

function Install-Package {
    param(
        $name, 
        $testpath  
    )
   if ((Test-Path $testpath) -eq $false)
    {       
        write-output "Installing $name from $SourceUri"
        .\nuget.exe install $name -Source $SourceUri -ExcludeVersion -OutputDirectory "packages" -Verbosity quiet
    } 
}

function Write-NuspecFile {
    param(
        $version,
        $title,
        $authors,
        $owners,
        $summary,
        $description,
        $tags,
        $copyright,
        $dataPath
        )

  $nuspecFile = "<?xml version=`"1.0`"?>
<package xmlns=`"http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd`">
  <metadata>
    <id>$title</id>
    <title>$title</title>
    <version>$version</version>
    <authors>$authors</authors>
    <owners>$owners</owners>
    <summary>$summary</summary>
    <description>$description</description>
    <projectUrl>http://www.example.com</projectUrl>
    <tags>$tags</tags>
    <copyright>$copyright</copyright>
    <licenseUrl>http://www.example.com</licenseUrl>
    <requireLicenseAcceptance>false</requireLicenseAcceptance>
    <releaseNotes>
    </releaseNotes>
  </metadata>
  <files>
    <file src=`"chocolatey\scripts\**`" target=`"tools`" />
    <file src=`"$dataPath\**`" target=`"data`" />    
  </files>
</package>
  "
  out-file -filePath "project.nuspec" -encoding UTF8 -inputObject $nuspecFile

}

function Make-Folder {
  param($Name)
  if ((Test-path -path $Name -pathtype container) -eq $false)
    {       
        mkdir $Name -verbose:$false
    }
}

function Delete-Folder {
  param($Name)
  if((test-path  $Name -pathtype container))
  {
    rmdir -Force -Recurse $Name -verbose:$false
  }  
}

function Delete-File {
  param($Name)
  if((test-path  $Name))
  {
    rmdir -Force -Recurse $Name -verbose:$false
  }  
}