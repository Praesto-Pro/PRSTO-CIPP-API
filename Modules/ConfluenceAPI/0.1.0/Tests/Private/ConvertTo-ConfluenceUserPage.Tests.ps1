$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$privateDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'Private'

Describe 'ConvertTo-ConfluenceUserPage' {
    BeforeAll {
        # Dot-source all dependencies
        . "$privateDir\New-ADFDocument.ps1"
        . "$privateDir\Add-ADFContent.ps1"
        . "$privateDir\ConvertTo-ADF.ps1"
        . "$privateDir\New-ADFTable.ps1"
        . "$privateDir\New-ADFHeading.ps1"
        . "$privateDir\New-ADFParagraph.ps1"
        . "$privateDir\ConvertTo-ConfluenceUserPage.ps1"
    }

    Context 'Empty/Null Input Handling (AC8)' {
        It 'Returns valid ADF with message when Users is null' {
            $result = ConvertTo-ConfluenceUserPage -Users $null
            $result | Should Not Be $null
            $result | Should BeOfType [string]

            # Parse JSON and verify structure
            $adf = $result | ConvertFrom-Json
            $adf.version | Should Be 1
            $adf.type | Should Be 'doc'

            # Should contain "No user data available" message
            $result | Should Match 'No user data available'
        }

        It 'Returns valid ADF with message when Users is empty array' {
            $result = ConvertTo-ConfluenceUserPage -Users @()
            $result | Should Not Be $null

            $adf = $result | ConvertFrom-Json
            $adf.version | Should Be 1
            $result | Should Match 'No user data available'
        }

        It 'Does not throw error on empty input' {
            { ConvertTo-ConfluenceUserPage -Users $null } | Should Not Throw
            { ConvertTo-ConfluenceUserPage -Users @() } | Should Not Throw
        }
    }

    Context 'Single User Transformation (AC1, AC2)' {
        BeforeAll {
            $script:singleUser = @(
                [PSCustomObject]@{
                    id                = 'user-guid-1'
                    displayName       = 'John Doe'
                    userPrincipalName = 'john@contoso.com'
                    mail              = 'john@contoso.com'
                    accountEnabled    = $true
                    userType          = 'Member'
                    assignedLicenses  = @()
                }
            )
        }

        It 'Returns valid ADF JSON string' {
            $result = ConvertTo-ConfluenceUserPage -Users $script:singleUser
            $result | Should Not Be $null
            $result | Should BeOfType [string]

            # Should be valid JSON
            { $result | ConvertFrom-Json } | Should Not Throw
        }

        It 'Creates ADF document with correct structure' {
            $result = ConvertTo-ConfluenceUserPage -Users $script:singleUser
            $adf = $result | ConvertFrom-Json

            $adf.version | Should Be 1
            $adf.type | Should Be 'doc'
            $adf.content | Should Not Be $null
        }

        It 'Includes table with correct columns' {
            $result = ConvertTo-ConfluenceUserPage -Users $script:singleUser

            # Check for expected column headers
            $result | Should Match 'DisplayName'
            $result | Should Match 'Email'
            $result | Should Match 'Status'
            $result | Should Match 'Licenses'
            $result | Should Match 'MFAStatus'
        }

        It 'Includes user data in table' {
            $result = ConvertTo-ConfluenceUserPage -Users $script:singleUser

            $result | Should Match 'John Doe'
            $result | Should Match 'john@contoso.com'
        }
    }

    Context 'Multiple Users (AC1, AC2)' {
        BeforeAll {
            $script:multiUsers = @(
                [PSCustomObject]@{
                    id                = 'user-1'
                    displayName       = 'Alice Smith'
                    userPrincipalName = 'alice@contoso.com'
                    accountEnabled    = $true
                    userType          = 'Member'
                    assignedLicenses  = @()
                },
                [PSCustomObject]@{
                    id                = 'user-2'
                    displayName       = 'Bob Jones'
                    userPrincipalName = 'bob@contoso.com'
                    accountEnabled    = $false
                    userType          = 'Member'
                    assignedLicenses  = @()
                }
            )
        }

        It 'Creates table with multiple rows' {
            $result = ConvertTo-ConfluenceUserPage -Users $script:multiUsers

            $result | Should Match 'Alice Smith'
            $result | Should Match 'Bob Jones'
        }
    }

    Context 'Guest User Filtering (AC7)' {
        BeforeAll {
            $script:mixedUsers = @(
                [PSCustomObject]@{
                    id                = 'user-1'
                    displayName       = 'Regular User'
                    userPrincipalName = 'regular@contoso.com'
                    accountEnabled    = $true
                    userType          = 'Member'
                    assignedLicenses  = @()
                },
                [PSCustomObject]@{
                    id                = 'guest-1'
                    displayName       = 'Guest User'
                    userPrincipalName = 'guest@external.com'
                    accountEnabled    = $true
                    userType          = 'Guest'
                    assignedLicenses  = @()
                }
            )
        }

        It 'Excludes guest users from output' {
            $result = ConvertTo-ConfluenceUserPage -Users $script:mixedUsers

            $result | Should Match 'Regular User'
            $result | Should Not Match 'Guest User'
        }

        It 'Returns valid ADF when all users are guests' {
            $guestsOnly = @(
                [PSCustomObject]@{
                    id                = 'guest-1'
                    displayName       = 'Guest One'
                    userPrincipalName = 'guest1@external.com'
                    userType          = 'Guest'
                    assignedLicenses  = @()
                }
            )

            $result = ConvertTo-ConfluenceUserPage -Users $guestsOnly
            $result | Should Not Be $null
            $result | Should Match 'No user data available'
        }
    }

    Context 'User Status Mapping (AC3)' {
        It 'Maps accountEnabled=true to Active' {
            $activeUser = @(
                [PSCustomObject]@{
                    displayName       = 'Active User'
                    userPrincipalName = 'active@contoso.com'
                    accountEnabled    = $true
                    userType          = 'Member'
                    assignedLicenses  = @()
                }
            )

            $result = ConvertTo-ConfluenceUserPage -Users $activeUser
            $result | Should Match 'Active'
        }

        It 'Maps accountEnabled=false to Disabled' {
            $disabledUser = @(
                [PSCustomObject]@{
                    displayName       = 'Disabled User'
                    userPrincipalName = 'disabled@contoso.com'
                    accountEnabled    = $false
                    userType          = 'Member'
                    assignedLicenses  = @()
                }
            )

            $result = ConvertTo-ConfluenceUserPage -Users $disabledUser
            $result | Should Match 'Disabled'
        }

        It 'Maps null accountEnabled to Unknown' {
            $unknownUser = @(
                [PSCustomObject]@{
                    displayName       = 'Unknown User'
                    userPrincipalName = 'unknown@contoso.com'
                    userType          = 'Member'
                    assignedLicenses  = @()
                }
            )

            $result = ConvertTo-ConfluenceUserPage -Users $unknownUser
            $result | Should Match 'Unknown'
        }
    }

    Context 'License Lookup (AC4)' {
        BeforeAll {
            $script:licenses = @(
                [PSCustomObject]@{
                    skuId         = 'c7df2760-2c81-4ef7-b578-5b5392b571df'
                    skuPartNumber = 'ENTERPRISEPREMIUM'
                },
                [PSCustomObject]@{
                    skuId         = '05e9a617-0261-4cee-bb44-138d3ef5d965'
                    skuPartNumber = 'SPE_E3'
                }
            )
        }

        It 'Returns skuPartNumber for licensed user' {
            $licensedUser = @(
                [PSCustomObject]@{
                    displayName       = 'Licensed User'
                    userPrincipalName = 'licensed@contoso.com'
                    accountEnabled    = $true
                    userType          = 'Member'
                    assignedLicenses  = @(
                        @{ skuId = 'c7df2760-2c81-4ef7-b578-5b5392b571df' }
                    )
                }
            )

            $result = ConvertTo-ConfluenceUserPage -Users $licensedUser -Licenses $script:licenses
            $result | Should Match 'ENTERPRISEPREMIUM'
        }

        It 'Shows comma-separated licenses for multiple licenses' {
            $multiLicenseUser = @(
                [PSCustomObject]@{
                    displayName       = 'Multi License User'
                    userPrincipalName = 'multi@contoso.com'
                    accountEnabled    = $true
                    userType          = 'Member'
                    assignedLicenses  = @(
                        @{ skuId = 'c7df2760-2c81-4ef7-b578-5b5392b571df' },
                        @{ skuId = '05e9a617-0261-4cee-bb44-138d3ef5d965' }
                    )
                }
            )

            $result = ConvertTo-ConfluenceUserPage -Users $multiLicenseUser -Licenses $script:licenses
            $result | Should Match 'ENTERPRISEPREMIUM'
            $result | Should Match 'SPE_E3'
        }

        It 'Shows None for users without licenses' {
            $noLicenseUser = @(
                [PSCustomObject]@{
                    displayName       = 'No License User'
                    userPrincipalName = 'nolicense@contoso.com'
                    accountEnabled    = $true
                    userType          = 'Member'
                    assignedLicenses  = @()
                }
            )

            $result = ConvertTo-ConfluenceUserPage -Users $noLicenseUser -Licenses $script:licenses
            $result | Should Match 'None'
        }

        It 'Handles null assignedLicenses array' {
            $nullLicenseUser = @(
                [PSCustomObject]@{
                    displayName       = 'Null License User'
                    userPrincipalName = 'nulllicense@contoso.com'
                    accountEnabled    = $true
                    userType          = 'Member'
                }
            )

            $result = ConvertTo-ConfluenceUserPage -Users $nullLicenseUser -Licenses $script:licenses
            $result | Should Match 'None'
        }
    }

    Context 'MFA Status Lookup (AC5)' {
        BeforeAll {
            $script:mfaData = @(
                [PSCustomObject]@{
                    UPN             = 'mfa@contoso.com'
                    MFARegistration = $true
                },
                [PSCustomObject]@{
                    UPN             = 'nomfa@contoso.com'
                    MFARegistration = $false
                }
            )
        }

        It 'Shows Registered for users with MFA enabled' {
            $mfaUser = @(
                [PSCustomObject]@{
                    displayName       = 'MFA User'
                    userPrincipalName = 'mfa@contoso.com'
                    accountEnabled    = $true
                    userType          = 'Member'
                    assignedLicenses  = @()
                }
            )

            $result = ConvertTo-ConfluenceUserPage -Users $mfaUser -MFAData $script:mfaData
            $result | Should Match 'Registered'
        }

        It 'Shows Not Registered for users without MFA' {
            $noMfaUser = @(
                [PSCustomObject]@{
                    displayName       = 'No MFA User'
                    userPrincipalName = 'nomfa@contoso.com'
                    accountEnabled    = $true
                    userType          = 'Member'
                    assignedLicenses  = @()
                }
            )

            $result = ConvertTo-ConfluenceUserPage -Users $noMfaUser -MFAData $script:mfaData
            $result | Should Match 'Not Registered'
        }

        It 'Shows Unknown when user not in MFA report' {
            $missingMfaUser = @(
                [PSCustomObject]@{
                    displayName       = 'Missing MFA User'
                    userPrincipalName = 'missing@contoso.com'
                    accountEnabled    = $true
                    userType          = 'Member'
                    assignedLicenses  = @()
                }
            )

            $result = ConvertTo-ConfluenceUserPage -Users $missingMfaUser -MFAData $script:mfaData
            $result | Should Match 'Unknown'
        }

        It 'Shows Unknown when MFAData parameter is null' {
            $user = @(
                [PSCustomObject]@{
                    displayName       = 'Any User'
                    userPrincipalName = 'any@contoso.com'
                    accountEnabled    = $true
                    userType          = 'Member'
                    assignedLicenses  = @()
                }
            )

            $result = ConvertTo-ConfluenceUserPage -Users $user -MFAData $null
            $result | Should Match 'Unknown'
        }

        It 'Handles case-insensitive UPN matching for MFA lookup' {
            # MFA data has lowercase UPN
            $mfaCaseData = @(
                [PSCustomObject]@{
                    UPN             = 'john.doe@contoso.com'
                    MFARegistration = $true
                }
            )

            # User has mixed-case UPN
            $mixedCaseUser = @(
                [PSCustomObject]@{
                    displayName       = 'John Doe'
                    userPrincipalName = 'John.Doe@Contoso.COM'
                    accountEnabled    = $true
                    userType          = 'Member'
                    assignedLicenses  = @()
                }
            )

            $result = ConvertTo-ConfluenceUserPage -Users $mixedCaseUser -MFAData $mfaCaseData
            $result | Should Match 'Registered'
            $result | Should Not Match 'Unknown'
        }
    }

    Context 'Timestamp Display (AC6)' {
        It 'Includes timestamp in output' {
            $user = @(
                [PSCustomObject]@{
                    displayName       = 'Test User'
                    userPrincipalName = 'test@contoso.com'
                    accountEnabled    = $true
                    userType          = 'Member'
                    assignedLicenses  = @()
                }
            )

            $result = ConvertTo-ConfluenceUserPage -Users $user
            $result | Should Match 'Last updated:'
        }

        It 'Timestamp includes UTC indicator' {
            $user = @(
                [PSCustomObject]@{
                    displayName       = 'Test User'
                    userPrincipalName = 'test@contoso.com'
                    accountEnabled    = $true
                    userType          = 'Member'
                    assignedLicenses  = @()
                }
            )

            $result = ConvertTo-ConfluenceUserPage -Users $user
            $result | Should Match 'UTC'
        }
    }

    Context 'Output Format Validation' {
        It 'Output is valid JSON' {
            $user = @(
                [PSCustomObject]@{
                    displayName       = 'Test User'
                    userPrincipalName = 'test@contoso.com'
                    accountEnabled    = $true
                    userType          = 'Member'
                    assignedLicenses  = @()
                }
            )

            $result = ConvertTo-ConfluenceUserPage -Users $user
            { $result | ConvertFrom-Json } | Should Not Throw
        }

        It 'Output has ADF document structure' {
            $user = @(
                [PSCustomObject]@{
                    displayName       = 'Test User'
                    userPrincipalName = 'test@contoso.com'
                    accountEnabled    = $true
                    userType          = 'Member'
                    assignedLicenses  = @()
                }
            )

            $result = ConvertTo-ConfluenceUserPage -Users $user
            $adf = $result | ConvertFrom-Json

            $adf.version | Should Be 1
            $adf.type | Should Be 'doc'
            $adf.content | Should Not Be $null
            $adf.content.Count | Should BeGreaterThan 0
        }

        It 'Includes heading element' {
            $user = @(
                [PSCustomObject]@{
                    displayName       = 'Test User'
                    userPrincipalName = 'test@contoso.com'
                    accountEnabled    = $true
                    userType          = 'Member'
                    assignedLicenses  = @()
                }
            )

            $result = ConvertTo-ConfluenceUserPage -Users $user
            $result | Should Match 'User Inventory'
        }
    }
}
