Describe 'Move-ADUserToTargetOU' {   
    # Setup mock's first 
    # Mock's are overrided if added in a context or it block

    BeforeAll {
        Mock Get-ADForest {
            [PSCustomObject]@{
                Name = 'DomainName'
            }
        }

        Mock Get-ADOrganizationalUnit {
            [PSCustomObject]@{
                DistinguishedName = 'OU=something,DC=domain,DC=com'
            }
        } 

        Mock Get-ADUser {
            [PSCustomObject]@{ 
                DistinguishedName = 'CN=someone,OU=something,DC=domain,DC=root,DC=com' 
            }
        } 

        Mock Import-Csv {
            [PSCustomObject]@{
                UserPrincipalName = 'Header'
            }
            [PSCustomObject]@{
                UserPrincipalName = 'bob@domain.com'
            }
        }

        Mock Move-ADObject
        Mock Test-Path { $true }
    }

    Context 'Given path parameter' {    
        # Inherits the Mock of Test-Path { $true } from main BeforeAll block. Path is correct then 
        # should not throw an error
        It 'Should give a valid file path' {

            { Move-ADUserToTargetOU -Path TestDrive:\import.csv -OUGroup Something } | Should Not Throw
        }

        It 'Should given an invalid file path Then throw a terminating error' {
            # Add a mock to fail test-path which overrides the main BeforeAll block.
            Mock Test-Path { $false }            

            { Move-ADUserToTargetOU -Path TestDrive:\import.csv -OUGroup Something } | Should Throw 
        }
    }

    Context 'Given Parameter validation - User' {
        # Mocking Get-ADUser to throw a terminating error to test invalid user
        Mock Get-ADUser { throw 'Invalid user' }

        It 'Should give an invalid AD user, throws a terminating error' {
            { Move-ADUserToTargetOU -Path TestDrive:\import.csv -OUGroup Something } | Should Throw 'Invalid user'
            Assert-MockCalled Get-ADOrganizationalUnit -Times 0
            Assert-MockCalled Move-ADObject -Times 0
        }
    }

    Context "Given OU Checks" {
        It 'Should give an invalid TargetOU, does not call Move-ADObject' {
            # Mock an empty Get-ADOrganizationalUnit so TargetOU will have an invalid entry ( Null ) 
            Mock Get-ADOrganizationalUnit { }

            { Move-ADUserToTargetOU -Path TestDrive:\import.csv -OUGroup Something } | Should Throw 'Invalid OU, cannot move user.'
            Assert-MockCalled Move-ADObject -Times 0 -Scope It
        }

        It 'Should give an ambiguous TargetOU and not call Move-ADObject' {
            # Mock two DistinguishedName's in different child domains, but with same OU name. The results check in main
            # function should terminate if 2 or more with the same OU
            Mock Get-ADOrganizationalUnit {
                [PSCustomObject]@{
                    DistinguishedName = 'OU=something,OU=child1,DC=domain,DC=com'
                }
                [PSCustomObject]@{
                    DistinguishedName = 'OU=something,OU=child2,DC=domain,DC=com'
                }
            }
            
            { Move-ADUserToTargetOU -Path TestDrive:\import.csv -OUGroup Something } | Should Throw
            Assert-MockCalled Move-ADObject -Times 0 -Scope It
        }
    }

    Context 'Successful move' {
        It 'Should give a valid user and OU and it moves the user' {
            # Mock the the identity parameter
            Mock Get-ADUser -ParameterFilter { $Identity -eq 'bob@domain.com' } -MockWith {
                [PSCustomObject]@{ 
                    DistinguishedName = 'CN=someone,OU=something,DC=domain,DC=root,DC=com' 
                }
            } 

            { Move-ADUserToTargetOU -Path TestDrive:\import.csv -OUGroup Something } | Should Not Throw
           
            # Just passing an Assert-MockCalled without any parameters asserts it's been called one or more times.
            # For a certain number pass the -Times parameter and use switch 'Exactly' to confirm its only been run by the value in 'Times'
            Assert-MockCalled Get-ADUser -Times 1 -ParameterFilter { $Identity -eq 'bob@domain.com' } -Exactly
            Assert-MockCalled Get-ADOrganizationalUnit -Times 1 -Exactly
            Assert-MockCalled Move-ADObject -Times 1 -Exactly
        }
    }
} 