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

    Context 'Test for path parameter' {    
        # Inherits the Mock of Test-Path { $true } from main Before Allblock. Path is correct then 
        # should not throw an error
        It 'Give a valid file path' {

            { Move-ADUserToTargetOU -Path TestDrive:\import.csv -OUGroup Something } | Should Not Throw
        }

        It 'Given an invalid file path, throws a terminating error' {
            # Add a mock to fail test-path which overrides the main BeforeAll block.
            Mock Test-Path { $false }            

            { Move-ADUserToTargetOU -Path TestDrive:\import.csv -OUGroup Something } | Should Throw 
        }
    }

    Context 'Parameter validation - User' {
        # BeforeAll added for items within this context block
        # Mocking Get-ADUser to throw a terminating error to test invalid user
        BeforeAll {
            Mock Get-ADUser { throw 'Invalid user' }
        }

        It 'Given an invalid AD user, throws a terminating error' {
            { Move-ADUserToTargetOU -Path TestDrive:\import.csv -OUGroup Something } | Should Throw 'Invalid user'
            Assert-MockCalled Get-ADOrganizationalUnit -Times 0
            Assert-MockCalled Move-ADObject -Times 0
        }
    }

    Context "OU Check" {
        It 'Given an invalid TargetOU, does not call Move-ADObject' {
            # Mock an empty Get-ADOrganizationalUnit so TargetOU will have an invalid entry ( Null ) 
            Mock Get-ADOrganizationalUnit { }

            { Move-ADUserToTargetOU -Path TestDrive:\import.csv -OUGroup Something } | Should Throw 'Invalid OU, cannot move user.'
            Assert-MockCalled Move-ADObject -Times 0 -Scope It
        }

        It 'Given an ambiguous TargetOU, does not call Move-ADObject' {
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
        It 'Given a valid user and OU, it moves the user' {
            { Move-ADUserToTargetOU -Path TestDrive:\import.csv -OUGroup Something } | Should Not Throw
           
            # Just passing an Assert-MockCalled without any parameters asserts it's been called one or more times.
            # For a certain number pass the -Times parameter
            Assert-MockCalled Get-ADUser
            Assert-MockCalled Get-ADOrganizationalUnit
            Assert-MockCalled Move-ADObject
        }
    }
}