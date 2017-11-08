$_scriptDirPath = $PSScriptRoot
$_msbuildPath = "C:\Program Files (x86)\MSBuild\14.0\bin\MSBuild.exe"
$_mstestRunnerPath = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\MSTest.exe"
$_mspecRunnerPath = Join-Path $_scriptDirPath "ThirdParty\MSpec\mspec.exe"
$_nugetExePath = Join-Path $_scriptDirPath "ThirdParty\NuGet\nuget.exe"
$_buildModulePath = Join-Path $_scriptDirPath "buildModule.psm1"
$_buildArtifactsPath = Join-Path $_scriptDirPath "BuildArtifacts"

function LogBlockOpenMessage([string]$message)
{
	Write-Host "##teamcity[blockOpened name='$message']"
}

function LogBlockCloseMessage([string]$message)
{
	Write-Host "##teamcity[blockClosed name='$message']"
}

function LogWarning([string]$message)
{
	Write-Host "##teamcity[message text='$message' status='WARNING']"
}

function LogBuildNumber([string]$buildNumber)
{
	Write-Host "##teamcity[buildNumber '$buildNumber']"
}

function LogBeginModuleMessage([string]$message)
{
	Write-Host "== BEGIN $message =="
}


function LogEndModuleMessage([string]$message)
{
	Write-Host "== END $message =="
}

function LogHashTable([hashtable]$hashTable, [string]$header)
{
	Write-Host $("-" * $header.length)
	Write-Host "$header"
	Write-Host $("-" * $header.length)

	# find the longest Key to determine the column width
	$columnWidth = $hashTable.Keys.length | Sort-Object| Select-Object -Last 1

	$hashTable.GetEnumerator() | ForEach-Object {
		Write-Host ("  {0,-$columnWidth} : {1}" -F $_.Key, $_.Value)
	}
}

function InvokeMsTestRunner([string]$testDllPath)
{
	LogBeginModuleMessage "$($MyInvocation.MyCommand.Name) $testDllPath"
	# resultsfile is mainly created to integrate the mstest results with teamcity
	$outputFileName = [guid]::NewGuid().ToString() + ".trx"
	$testArtifactsDirPath = "$_scriptDirPath\TestArtifacts"
	if(!(Test-Path $testArtifactsDirPath))
	{
		New-Item -ItemType Directory -Force -Path $testArtifactsDirPath
	}

	$outputFilePath = Join-Path $testArtifactsDirPath $outputFileName
	& $_mstestRunnerPath /testcontainer:$testDllPath /resultsfile:$outputFilePath

	CheckLastExitCode "MSTestRunner failed: $testDllPath"

	if(test-path $outputFilePath)
	{
		Write-Output "##teamcity[importData type='mstest' path='$outputFilePath']"
	}
	LogEndModuleMessage "$($MyInvocation.MyCommand.Name) $testDllPath"
}

function InvokeMSpecRunner([string]$testDllPath)
{
	LogBeginModuleMessage "$($MyInvocation.MyCommand.Name) $testDllPath"
	& $_mspecRunnerPath "$testDllPath" --teamcity
	CheckLastExitCode "MSpecRunner failed: $testDllPath"
	LogEndModuleMessage "$($MyInvocation.MyCommand.Name) $testDllPath"
}

function InvokeTests([string]$slnPath, [bool]$isSlnChanged, [string[]]$testsToBeExcluded)
{
	LogBeginModuleMessage "$($MyInvocation.MyCommand.Name)"
	$slnName = Split-Path -Path $slnPath -Leaf

	if($isSlnChanged)
	{
		$slnOutputPath = GetOutputPath $slnName
		$testDlls = GetTestsToBeExecuted $slnOutputPath $testsToBeExcluded
		foreach ($testDll in $testDlls)
		{
			$testDllPath = Join-Path $slnOutputPath $testDll
			InvokeMsTestRunner $testDllPath
			InvokeMSpecRunner $testDllPath
		}
	}
	else
	{
		# todo: need to find a way to display the skipped sln name
		LogWarning "Skipped $slnName Tests"
	}

	LogEndModuleMessage "$($MyInvocation.MyCommand.Name)"
}

function GetTestsToBeExecuted([string]$slnOutputPath, [string[]]$testsToBeExcluded)
{
	$allTestDlls = Get-ChildItem -Path $slnOutputPath "*Tests.dll" -Name

    if ($testsToBeExcluded.count -gt 0)
    {
       return $allTestDlls | Select-String -pattern $testsToBeExcluded -NotMatch
    }

	return $allTestDlls
}

function InvokeNuGetRestore([string]$slnPath)
{
	$slnName = Split-Path -Path $slnPath -Leaf
	LogBeginModuleMessage "$($MyInvocation.MyCommand.Name) $slnName"
	& $_nugetExePath restore "$slnPath"
	CheckLastExitCode "$slnName NuGet restoration failed!"
	LogEndModuleMessage "$($MyInvocation.MyCommand.Name) $slnName"
}

function InvokeMsBuild([string]$slnPath, [bool]$isChanged)
{
	$slnName = Split-Path -Path $slnPath -Leaf
	LogBeginModuleMessage "$($MyInvocation.MyCommand.Name) $slnName"

	if($isChanged)
	{
		InvokeNuGetRestore $slnPath
		$outputPath = GetOutputPath $slnName
		if(Test-Path $outputPath)
		{
			Get-ChildItem -Path $outputPath -Include * | Remove-Item -recurse
		}
		# verbosity levels q[uiet], m[inimal], n[ormal], d[etailed], and diag[nostic]
		# consoleloggerparameters overrides verbosity
		& $_msbuildPath $slnPath /t:rebuild /p:OutDir="$outputPath" /p:Configuration=Release `
			/consoleloggerparameters:ErrorsOnly #/verbosity:minimal
		# Write-Host $(Get-Date -Format G)
		CheckLastExitCode "$slnName build failed!"
	}
	else
	{
		LogWarning "Skipped $slnName"
	}

	LogEndModuleMessage "$($MyInvocation.MyCommand.Name) $slnName"
}

function InvokeMsBuildAndRunTests([string]$slnPath, [bool]$isChanged, [string[]]$testsToBeExcluded)
{
	InvokeMsBuild $slnPath $isChanged
	InvokeTests $slnPath $isChanged $testsToBeExcluded
}

function CheckLastExitCode([string]$exceptionMessage)
{
	if($LastExitCode -ne 0)
	{
		throw "<< BUILD FAILED >> $exceptionMessage"
	}
}

function GetOutputPath([string]$slnName)
{
	$outputPath = Join-Path $_buildArtifactsPath $slnName

	return $outputPath.Substring(0, $outputPath.LastIndexOf('.'))
}

function PreBuildCleanup {
    LogBlockOpenMessage "$($MyInvocation.MyCommand.Name)"
    if (Test-Path $_buildArtifactsPath) {
        Get-ChildItem -Path $_buildArtifactsPath -Include * | Remove-Item -recurse
    }
    LogBlockCloseMessage "$($MyInvocation.MyCommand.Name)"
}

function PostBuildCleanup {
    LogBlockOpenMessage "$($MyInvocation.MyCommand.Name)"

    Write-Host "Deleting the test artifacts..."
    $testArtifactsDirPath = Join-Path $_scriptDirPath "TestArtifacts"
    # cleanup all the mstest output files
    Get-ChildItem -Path $testArtifactsDirPath -Include * | Remove-Item -recurse

    LogBlockCloseMessage "$($MyInvocation.MyCommand.Name)"
}

function BuildSolution([string]$slnPath, [bool]$isChanged, [string[]]$testsToBeExcluded, [string]$nugetOutputDir) {
	LogBeginModuleMessage "$($MyInvocation.MyCommand.Name)"

    InvokeMsBuildAndRunTests $slnPath $isChanged $testsToBeExcluded

    if ($nugetOutputDir) {
    	$slnName = Split-Path -Path $slnPath -Leaf
    	$outputFolder = GetOutputPath $slnName

    	$fileName = $slnName -replace ".sln", ".dll"
    	$filePath = Join-Path $outputFolder $fileName
    	$version = (Get-Item $filePath).VersionInfo.ProductVersion

    	Write-Output "Version: $version"
    	LogBuildNumber($version)

        CreateNugets $outputFolder $version $_buildArtifactsPath

        PushNugets $_buildArtifactsPath $nugetOutputDir
    }

    LogEndModuleMessage "$($MyInvocation.MyCommand.Name)"
}

function Join-ArrayPath {
   param([parameter(Mandatory=$true)]
   [string[]]$PathElements)

   if ($PathElements.Length -eq "0")
   {
     $CombinedPath = ""
   }
   else
   {
     $CombinedPath = $PathElements[0]
     for($i=1; $i -lt $PathElements.Length; $i++)
     {
       $CombinedPath = Join-Path $CombinedPath $PathElements[$i]
     }
  }
  return $CombinedPath
}

function CreateNugets([string]$nuspecFolderPath, [string]$version, [string]$outputPath) {
    LogBlockOpenMessage "$($MyInvocation.MyCommand.Name)"

    $nuspecsPath = Join-Path $nuspecFolderPath "*.nuspec"
	Write-Output "Nuget Spec path: $nuspecsPath"
    $files = Get-ChildItem $nuspecsPath

    ForEach ($file in $files) {
		Write-Output "File: $file"
        & $_nugetExePath pack $file -version $version -outputdirectory $outputPath
    }

    LogBlockCloseMessage "$($MyInvocation.MyCommand.Name)"
}

function PushNugets([string]$nugetFolderPath, [string]$outputPath) {
    LogBlockOpenMessage "$($MyInvocation.MyCommand.Name)"

    $nugetsPath = Join-Path $nugetFolderPath "*.nupkg"
    $files = Get-ChildItem $nugetsPath

    ForEach ($file in $files) {
      & $_nugetExePath push -Source $outputPath $file.fullName
    }

    LogBlockCloseMessage "$($MyInvocation.MyCommand.Name)"
}


export-modulemember -function InvokeMsBuild, LogBlockOpenMessage, LogBlockCloseMessage,
	LogWarning, LogBeginModuleMessage, LogEndModuleMessage, LogHashTable,
	CheckLastExitCode, InvokeMsBuildAndRunTests, GetOutputPath,
	PreBuildCleanup, PostBuildCleanup, BuildSolution, Join-ArrayPath
