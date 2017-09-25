Function Move-ADUserToTargetOU {
    
    [cmdletbinding()]
    param (
        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $True)]
        [ValidateScript( { Test-Path $_ } )]
        [string]$Path,

        [parameter(ValueFromPipelineByPropertyName = $True)]
        [string]$OUGroup
    )

    Begin {
        Write-Verbose -Message "[BEGIN  ] Function to move Users to '$OUGroup' OU"
    }

    Process {
        $csv = @{
            Path     = $Path 
            Encoding = 'UTF8' 
            Header   = 'UserPrincipalName'
        }

        # import CSV and set header
        $UPNlist = Import-Csv @csv | Select-Object -Skip 1

        # Obtain Forest
        $forest = (Get-ADForest).name

        foreach ($upn in $UPNlist.UserPrincipalName) {
    
            # Get User Parameters
            $params = @{
                Identity    = $upn
                Server      = "${forest}:3268"
                ErrorAction = 'Stop'
            }

            # Set Get-ADOrganizationalUnit Parameters
            $targetOUParams = @{
                Filter      = { Name -eq $OUGroup } 
                ErrorAction = 'Stop'
            }
        
            # Find User
            Try {
                Write-Verbose -Message "[PROCESS] Getting User details from Active Directory"
                $ADAccount = Get-ADUser @params

                # Get child domain user is in with string manipulation on DistinguishedName
                $null, $targetOUParams.Server = $ADAccount.DistinguishedName -split 'DC=', 2 -replace ',DC=', '.'
                
                $UserOU = ($ADAccount.DistinguishedName -split ",", 2)[1]
                $targetOU = Get-ADOrganizationalUnit @targetOUParams

                if (-not $targetOU) {
                    throw 'Invalid OU, cannot move user.'
                } elseif (@($targetOU).Count -gt 1) {
                    throw 'Ambiguous OU, cannot move user.'
                } elseif ($targetOU.DistinguishedName -ne $userOU) {
                    $Move = @{
                        Identity    = $ADAccount.DistinguishedName
                        TargetPath  = $TargetOU
                        Server      = $targetOUParams.Server
                        ErrorAction = 'Stop'
                    }

                    # Perform Move
                    Write-Verbose -Message "[PROCESS] Moving user: $($ADAccount.UserPrincipalName)"
                    Move-ADObject @Move
    
                    Write-Verbose -Message "[PROCESS] Target Server: $domain"
                    Write-Verbose -Message "[PROCESS] User moved to Target OU: $($Move.TargetPath)"
                } else {
                    Write-Verbose -Message "[PROCESS] No changes were required: $($ADAccount.UserPrincipalName)"
                }
            } catch {
                Write-Error -Message $_.Exception.Message -ErrorAction Stop
            }
        }
    }
    
    End {
        Write-Verbose -Message "[END    ] Completed OU moves"
    }
}