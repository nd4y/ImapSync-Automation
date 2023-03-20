<#
        .SYNOPSIS
        Пишет лог в логфайл и выводит на экран.
        В скрипте должна задаваться переменная $ScriptLogLevel со значениями: 'DEBUG', 'INFO', 'WARN', 'ERROR'

        .EXAMPLE
        Write-Log -Message "$($_.Exception.Message) on line $($_.InvocationInfo.ScriptLineNumber)" -LogLevel 'ERROR'
#>
function Write-Log { 
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]
        $LogFilePath,
        
        [Parameter(Mandatory = $true, Position = 1)]
        [System.String]
        $Message,

        [Parameter(Mandatory = $false, Position = 2)]
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
        [System.String]
        $LogLevel = 'DEBUG',

        [Parameter(Mandatory = $false, Position = 3)] # Отключает вывод лога в консоль
        [switch]
        $DoNotDisplay = $false
    )

    $LogLevelMap = @{
        'DEBUG'     = 0
        'INFO'      = 1
        'WARN'      = 2
        'ERROR'     = 3
    }
    $ColorMap = @{
        'DEBUG'     = 'Cyan'
        'INFO'      = 'White'
        'WARN'      = 'Yellow'
        'ERROR'     = 'Red'
    }

    if (!$ScriptLogLevel) {
        Write-Error '$ScriptLogLevel variable undefined'
        break
    }
    if ($LogLevelMap[$LogLevel] -ge $LogLevelMap[$($ScriptLogLevel)]) {
        $Stamp = (Get-Date).toString("yyyy-MM-dd HH:mm:ss.fff")
        $Line = "{0, 20} | {1, -5} | {2}" -f $Stamp, $LogLevel, $Message
        Add-Content $LogFilePath -Value $Line -Encoding 'utf8'
        if ($DoNotDisplay -eq $false) {
            Write-Host $Line -ForegroundColor $ColorMap[$LogLevel]
        }
    }
}