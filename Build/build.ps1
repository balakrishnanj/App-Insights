# build arguments
$_isFullBuild = $args[0]
$_branchPath = $args[1]
$_targetBranchName = $args[2]
$_nugetOutputDirPath = $args[3]

$_changedFiles = ''
$_scriptDirPath = $PSScriptRoot
$_rootDirPath = Split-Path $_scriptDirPath
$_appInsightsDirPath = Join-Path $_rootDirPath "AppInsights"
$_appInsightsSlnPath = Join-Path $_appInsightsDirPath "Identifi.AppInsights.sln"
$_keepWindowOpen = $true

$_buildModulePath = Join-Path $_scriptDirPath "buildModule.psm1"
$_buildArtifactsPath = Join-Path $_scriptDirPath "BuildArtifacts"
$_testsToBeExcluded = @()

function Main {
    try {
        Import-Module $_buildModulePath -Force
        PreBuildCleanup
        $buildParams = Setup
        LogBlockOpenMessage "Build"
        BuildWorkflow $buildParams
        LogBlockCloseMessage "Build"
    }
    catch {
        if (!$_keepWindowOpen) {
            $host.SetShouldExit(1)
        }
        Write-Error $_.Exception.Message
        throw $_.Exception
    }
    finally {
        PostBuildCleanup
    }
}

function Setup {
    LogBlockOpenMessage "$($MyInvocation.MyCommand.Name)"

	if ($_branchPath) {
        git fetch origin
        $_changedFiles = git diff "origin/$_targetBranchName...HEAD" --no-commit-id --name-only
    }

    Write-Host "Files Changed:" $_changedFiles

    Write-Host "Full build:" $_isFullBuild
	
    $buildParams =
    @{
        AppInsightsSlnPath  = $_appInsightsSlnPath;
        BuildModulePath        = $_buildModulePath;
        TestsToBeExcluded      = $_testsToBeExcluded;
		ChangeStatus           = GetChangeStatus;
        NugetOutputDirPath     = $_nugetOutputDirPath;
    }

    LogHashTable $buildParams "Build Params"

    LogBlockCloseMessage "$($MyInvocation.MyCommand.Name)"

    return $buildParams
}

function GetChangeStatus {
    $changeStatus = @{}

    if ($_changedFiles.Length -eq 0 -or $_isFullBuild) {
        # if we manually trigger a build after a failed build, it isn't getting any changed files.
        # in that case, we should build everything
        $changeStatus = @{
            IsAppInsightsChanged = $true;
        }
    }
    else {        
        $changeStatus = @{
            IsAppInsightsChanged   = IsDirectoryChanged($_appInsightsDirPath);
        }
    }

    LogHashTable $changeStatus "Change Status"

    return $changeStatus;
}

function IsDirectoryChanged([string] $dirPath) {
    return ($_changedFiles | Where-Object `
            { $_.ToString().StartsWith($dirPath, 1) }).Length -gt 0
}

function Build([hashtable]$buildParams)
{
	Import-Module $buildParams.BuildModulePath
	LogBeginModuleMessage "$($MyInvocation.MyCommand.Name)"

	BuildSolution $buildParams.AppInsightsSlnPath $buildParams.ChangeStatus.IsAppInsightsChanged $buildParams.TestsToBeExcluded $buildParams.NugetOutputDirPath

	LogEndModuleMessage "$($MyInvocation.MyCommand.Name)"
}

# Unable to handle exceptions within workflows.
# Problems:
# 1. The main code block that invokes the workflow is unable to capture the exceptions
# thrown inside the workflows.
# 2. If we add try catch with Exception, too many exceptions are caught, probably all the
# Write-Host are handled. If we throw a specific exception (like InvalidOperationException)
# and catch that particular exception then the logs that teamcity captures are missing
# To overcome all these issues, within TeamCity, failure condition needs to be added looking for
# << BUILD FAILED >> in the log

Workflow BuildWorkflow
{
    param
    (
        [hashtable]$buildParams
    )

	Sequence
	{
		try
		{                  
			Build $buildParams
		}
		catch
		{
			throw "<< BUILD FAILED >>  $_.Exception.Message"
		}
	}
}

Main
