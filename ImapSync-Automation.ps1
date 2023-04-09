param (
    $ScriptLogLevel             = 'DEBUG',
    $LogFilePath                = "$PSScriptRoot\logs\$($MyInvocation.MyCommand.Name)-$(Get-Date -Format yyyyMMddHHmmss).log",
    $ModulesDirPath             = "$PSScriptRoot\modules\",
    $ConfigFilePath             = "$PSScriptRoot\conf\ImapSync-Automation.conf",
    $WorkingDirectory           = $PSScriptRoot
)
Set-Variable -Name 'ScriptLogLevel' -Value $ScriptLogLevel -Scope 'Global'

#region Import-Modules
Import-Module "$ModulesDirPath\Write-Log"
Import-Module "$ModulesDirPath\Import-Config"
#endregion Import-Modules

#region functions
function Test-ImapSyncLogDetectedErrors { 
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]
        $ImapSyncLogFilePath
    )
    try {    
        if ((Get-Content -Path $ImapSyncLogFilePath | Select-String -Pattern 'Detected 0 errors').Count -eq 1) {
            $message = 'Detected 0 errors'
            $status = 0
        }
        else {
           $message = 'There may have been errors. Check the log manually'
           $status = 1
        }
    }
    catch {
        $message = 'Could not check log'
        $status = 1
    }
    $result = @{
        status  = $status
        message = $message
    }
    return $result
}
#endregion functions

#region Main script
try {
    $ImapSyncParams = Import-Config -ConfigFilePath $ConfigFilePath
    Write-Log -Message "The following options have been imported: $($ImapSyncParams | Format-List | Out-String)" -LogFilePath $LogFilePath -LogLevel 'DEBUG'
}
catch {
    Write-Log -LogFilePath $LogFilePath -Message "$($_.Exception.Message) on line $($_.InvocationInfo.ScriptLineNumber)" -LogLevel 'ERROR'
    break
}

$funcWriteLog = ${function:Write-Log}.ToString()
$funcTestImapSyncLogDetectedErrors = ${function:Test-ImapSyncLogDetectedErrors}.ToString()
try {
    Write-Log -Message "Starting $($ImapSyncParams.Threads) imapsync processes in parallel" -LogFilePath $LogFilePath -LogLevel 'INFO'
    Get-Content $ImapSyncParams.AccountListCSVfile | ForEach-Object -ThrottleLimit $ImapSyncParams.Threads -Parallel {
        #region Переносим функции и переменнные в блок -Parallel
        ${function:Write-Log}                         = $using:funcWriteLog
        ${function:Test-ImapSyncLogDetectedErrors}    = $using:funcTestImapSyncLogDetectedErrors
        $ScriptLogLevel                               = $using:ScriptLogLevel
        $LogFilePath                                  = $using:LogFilePath
        $ImapSyncParams                               = $using:ImapSyncParams
        #$ImapSyncLogDir                               = $using:ImapSyncLogDir
        $WorkingDirectory                             = $using:WorkingDirectory
        #endregion Переносим функции и переменнные в блок -Parallel

        $Arguments = $_ -split(';')
        $ArgumentsHastable = [ordered]@{
            'host1'       = $Arguments[0]
            'user1'       = $Arguments[1]
            'password1'   = $Arguments[2]
            'host2'       = $Arguments[3]
            'user2'       = $Arguments[4]
            'password2'   = $Arguments[5]
        }
        $MailboxesPair = "$($Arguments[1])-$($Arguments[4])"
        $ImapSyncLogFileName = "$(Get-Date -Format yyyy-MM-dd-HH-mm-ss)_$MailboxesPair.log"
        $ImapSyncLogFilePath = "$WorkingDirectory\LOG_imapsync\$ImapSyncLogFileName"
        $ArgumentList = "$($ImapSyncParams.GlobalAdditionalParams)  --logfile $ImapSyncLogFileName"
        foreach ($AgrumentsPair in $ArgumentsHastable.GetEnumerator() ) {
            $ArgumentList += " --$($AgrumentsPair.Name) $($AgrumentsPair.Value)"
        }
        try {
            Write-Log -Message "Starting imapsync with arguments: $ArgumentList" -LogFilePath $LogFilePath -LogLevel 'DEBUG'
            $ImapSyncProcess = Start-Process -FilePath $ImapSyncParams.ImapSyncBin -ArgumentList $ArgumentList -Wait -PassThru -WindowStyle Hidden
            $LogFileTestResult = Test-ImapSyncLogDetectedErrors -ImapSyncLogFilePath $ImapSyncLogFilePath
            if ($ImapSyncProcess.ExitCode -eq 0) {
                if (($LogFileTestResult).status -eq 0) {
                    Write-Log -Message "Finished synchronization for Mailboxes pair $MailboxesPair with no error. $($LogFileTestResult.message). Logfile $ImapSyncLogFileName" -LogFilePath $LogFilePath -LogLevel 'INFO'
                }
            }
            else {
                Write-Log -Message "Finished synchronization for user $MailboxesPair with exit code $($ImapSyncProcess.ExitCode). $($LogFileTestResult.message). Logfile $ImapSyncLogFileName" -LogFilePath $LogFilePath -LogLevel 'ERROR'
            }
        }
        catch {
            Write-Log -LogFilePath $LogFilePath -Message "$($_.Exception.Message) on line $($_.InvocationInfo.ScriptLineNumber)" -LogLevel 'ERROR'
            break
        }
    }
    Write-Log -Message "Finished synchronization for all users" -LogFilePath $LogFilePath -LogLevel 'INFO'
}
catch {
    Write-Log -LogFilePath $LogFilePath -Message "$($_.Exception.Message) on line $($_.InvocationInfo.ScriptLineNumber)" -LogLevel 'ERROR'
    $_
}
#endregion Main script

#$null = Remove-Variable *
Remove-Module Write-Log
Remove-Module Import-Config