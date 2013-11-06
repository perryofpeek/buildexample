properties {
  $version = '1.0.0.0'
  $nuget_packages_uri = "https://nuget.org"
  $Build_Configuration = 'Release'
  $Company = "Company Name";
  $Description = "Application description";
  $Product = "Product Name $version";
  $Title = "Product Title $version";
    
  
  ## Should not need to change these 
  $year = Get-Date -UFormat "%Y"
  $Copyright = " (C) Copyright $company $year";
  $SourceUri = "$nuget_packages_uri/api/v2/"
  $tmp_files = Get-ChildItem *.sln 
  $Build_Solution =  $tmp_files.Name  
  $Build_Artifacts = 'output'
  $fullPath= 'src\SqlToGraphite.host\output'
  $Debug = 'Debug'
  $pwd = pwd
  $msbuild = "C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe"
  $nunit =  "$pwd\packages\NUnit.Runners\tools\nunit-console-x86.exe"
  $openCover = "$pwd\packages\OpenCover\OpenCover.Console.exe"
  $reportGenerator = "$pwd\packages\ReportGenerator\ReportGenerator.exe"
  $TestOutput = "$pwd\BuildOutput"
  $UnitTestOutputFolder = "$TestOutput\UnitTestOutput";
  $TestReport = "";
  $nuspecFile = "SqlToGraphite.nuspec"
}

task default -depends Init, Compile, Test, Report #, #NugetPackage, Report

task Init -depends GetTools, GetNugetPackages {	

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
        write-host "installing nuget packages from " $file.FullName
        .\nuget.exe install $file.Fullname -Source $SourceUri -OutputDirectory "packages"
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
	$sinkoutput = mkdir $TestOutput -Verbose:$false;  
    $sinkoutput = mkdir $UnitTestOutputFolder -Verbose:$false;  
	
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
	write-host $files
	#write-host " $openCover -target:$nunit -filter:+[SqlToGraphite*]* -register:user -mergebyhash -targetargs:$files /err=err.nunit.txt /noshadow /nologo /config=SqlToGraphite.UnitTests.dll.config"
	Exec { & $openCover "-register:user -target:$nunit" "-filter:-[.*test*]* +[*]* " -register:user -mergebyhash "-targetargs:$files /err=err.nunit.txt /noshadow /nologo /config=SqlToGraphite.UnitTests.dll.config" }     
	Exec { & $reportGenerator "-reports:results.xml" "-targetdir:..\report" "-verbosity:Error" "-reporttypes:Html;HtmlSummary;XmlSummary"}	
	cd $pwd	
}

task Compile -depends Init, PatchAssemblyInfo, Clean {  
   Exec {  & $msbuild /m:4 /verbosity:quiet /nologo /p:OutDir=""$Build_Artifacts\"" /t:Rebuild /p:Configuration=$Build_Configuration $Build_Solution }   	
}

task Clean {
  if((test-path  $Build_Artifacts -pathtype container))
  {
	rmdir -Force -Recurse $Build_Artifacts;
  }     
  if (Test-Path $TestOutput) 
  {
	Remove-Item -force -recurse $TestOutput
  }  
  Exec {  & $msbuild /m:4 /verbosity:quiet /nologo /p:OutDir=""$Build_Artifacts\"" /t:Clean $Build_Solution }  
}

task NugetPackage {
    if ((Test-path -path $Build_Artifacts -pathtype container) -eq $false)
    {		
		mkdir $Build_Artifacts
    }
    write-host $nuspecFile $Build_Artifacts
	Copy-item src\SqlToGraphite.host\output\SqlToGraphite.host.exe  $Build_Artifacts\
	Copy-item src\SqlToGraphite.host\output\SqlToGraphite.dll  $Build_Artifacts\
	Copy-item src\SqlToGraphite.host\output\app.config.Template $Build_Artifacts\SqlToGraphite.host.exe.config
	Copy-item src\SqlToGraphite.host\output\Graphite.dll  $Build_Artifacts\
	Copy-item src\SqlToGraphite.host\output\SqlToGraphite.Plugin.Wmi.dll  $Build_Artifacts\
    Copy-item src\SqlToGraphite.host\output\Topshelf.dll  $Build_Artifacts\
	Copy-item src\SqlToGraphite.host\output\log4net.dll  $Build_Artifacts\	
	Copy-item src\Configurator\output\Configurator.exe	$Build_Artifacts\ConfigUi.exe
	Copy-Item  src\ConfigPatcher\output\configpatcher.exe $Build_Artifacts\configpatcher.exe;	
	Copy-Item  src\Configurator\output\Configurator.exe.config $Build_Artifacts\ConfigUi.exe.config;
	Copy-Item  src\SqlToGraphite.host\output\DefaultConfig.xml $Build_Artifacts\DefaultConfig.xml;

	write-host $nuspecFile $Build_Artifacts
	Copy-item $nuspecFile $Build_Artifacts\
	Exec { packages\NuGet.CommandLine.1.7.0\tools\NuGet.exe Pack $nuspecFile -BasePath $Build_Artifacts -outputdirectory .  -Version  $version }		
	#Exec { c:\Apps\NSIS\makensis.exe /p4 /v2 sqlToGraphite.nsi }
    #Move-item -Force SqlToGraphite-Setup.exe "SqlToGraphite-Setup-$version.exe"	
}

task Package {   
	Exec { c:\Apps\NSIS\makensis.exe /p4 /v2 sqlToGraphite.nsi }
    Move-item -Force SqlToGraphite-Setup.exe "SqlToGraphite-Setup-$version.exe"	
}

task Report -Depends Test {
	write-host "================================================================="	
	$xmldata = [xml](get-content BuildOutput\UnitTestOutput\testresult.xml)
	
	write-host "Total tests "$xmldata."test-results".GetAttribute("total") " Errors "$xmldata."test-results".GetAttribute("errors") " Failures " $xmldata."test-results".GetAttribute("failures") "Not-run "$xmldata."test-results".GetAttribute("not-run") "Ignored "$xmldata."test-results".GetAttribute("ignored")
	#write-host "Total errors "$xmldata."test-results".GetAttribute("errors")
	#write-host "Total failures "$xmldata."test-results".GetAttribute("failures")
	#write-host "Total not-run "$xmldata."test-results".GetAttribute("not-run")
	#write-host "Total inconclusive "$xmldata."test-results".GetAttribute("inconclusive")
	#write-host "Total ignored "$xmldata."test-results".GetAttribute("ignored")
	#write-host "Total skipped "$xmldata."test-results".GetAttribute("skipped")
	#write-host "Total invalid "$xmldata."test-results".GetAttribute("invalid")

	$xmldata1 = [xml](get-content "$TestOutput\report\summary.xml")
	$xmldata1.SelectNodes("/CoverageReport/Summary")
}

task ? -Description "Helper to display task info" {
    Write-Documentation
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
