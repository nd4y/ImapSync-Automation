<#
        .SYNOPSIS
        Импортирует конфигурацию из файла.
        Пример файла конфигурации:
        
        Author=Alexandr Vorontsov
        Purpose=ImapSync Easy Management
        Param1=Value1
#>
function Import-Config {
    param (
        [Parameter(Position=0,mandatory=$true)]
        [System.String]$ConfigFilePath
    )
    try {
        $result = @{}
        Get-Content -Path $ConfigFilePath | Foreach-Object {
            if ($_.Split('=')[0] -notmatch "^;|#.*") { # Исключить закомментированные строки
                $result += [hashtable]@{
                    $_.Split('=')[0] = ($_.Split('=')[1]).TrimStart(' ').TrimEnd(' ') # Удалить лишние пробелы в начале и в конце Value
                }
            }
        }
    }
    catch {
        $_
        break
    }
    return $result
}