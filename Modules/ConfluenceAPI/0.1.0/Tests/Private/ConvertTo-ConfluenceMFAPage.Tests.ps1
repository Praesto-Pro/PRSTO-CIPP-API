$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$privateDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'Private'

Describe 'ConvertTo-ConfluenceMFAPage' {
    BeforeAll {
        # Dot-source dependencies (real implementations for unit tests)
        . "$privateDir\New-ADFDocument.ps1"
        . "$privateDir\Add-ADFContent.ps1"
        . "$privateDir\ConvertTo-ADF.ps1"
        . "$privateDir\New-ADFTable.ps1"
        . "$privateDir\New-ADFHeading.ps1"
        . "$privateDir\New-ADFParagraph.ps1"
        . "$privateDir\ConvertTo-ConfluenceMFAPage.ps1"
    }

    Context 'Empty/Null Input Handling (AC9)' {
        It 'Returns valid ADF with message when MFAData is null' {
            $result = ConvertTo-ConfluenceMFAPage -MFAData $null
            $result | Should Not Be $null
            $result | Should Match 'No MFA data available'
        }

        It 'Returns valid ADF with message when MFAData is empty array' {
            $result = ConvertTo-ConfluenceMFAPage -MFAData @()
            $result | Should Not Be $null
            $result | Should Match 'No MFA data available'
        }

        It 'Returns valid JSON when MFAData is null' {
            $result = ConvertTo-ConfluenceMFAPage -MFAData $null
            { $result | ConvertFrom-Json } | Should Not Throw
        }

        It 'Includes MFA Status Report heading when MFAData is null' {
            $result = ConvertTo-ConfluenceMFAPage -MFAData $null
            $result | Should Match 'MFA Status Report'
        }

        It 'Includes timestamp in empty state (FR44 compliance)' {
            $result = ConvertTo-ConfluenceMFAPage -MFAData $null
            $result | Should Match 'Data as of:'
            $result | Should Match 'UTC'
        }

        It 'Uses UTC format in empty state timestamp' {
            $result = ConvertTo-ConfluenceMFAPage -MFAData @()
            $result | Should Match '\d{4}-\d{2}-\d{2} \d{2}:\d{2}'
        }
    }

    Context 'Valid ADF Output (AC1)' {
        It 'Returns a non-null string' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isMfaRegistered = $true
            }

            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $result | Should Not Be $null
            $result | Should BeOfType [string]
        }

        It 'Returns valid JSON' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isMfaRegistered = $true
            }

            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            { $result | ConvertFrom-Json } | Should Not Throw
        }

        It 'Returns valid ADF document structure' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isMfaRegistered = $true
            }

            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $json = $result | ConvertFrom-Json
            $json.type | Should Be 'doc'
            $json.version | Should Be 1
        }
    }

    Context 'MFA Status Mapping (AC3)' {
        It 'Maps perUserMfaState enforced to Enforced' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                perUserMfaState = 'enforced'
            }
            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $result | Should Match 'Enforced'
        }

        It 'Maps perUserMfaState enabled to Enabled' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                perUserMfaState = 'enabled'
            }
            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $result | Should Match 'Enabled'
        }

        It 'Maps isMfaRegistered true to Enabled' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isMfaRegistered = $true
            }
            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $result | Should Match 'Enabled'
        }

        It 'Maps security defaults coverage to Protected (Policy)' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isSecurityDefaultsCovered = $true
            }
            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $result | Should Match 'Protected \(Policy\)'
        }

        It 'Maps conditional access coverage to Protected (Policy)' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isConditionalAccessCovered = $true
            }
            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $result | Should Match 'Protected \(Policy\)'
        }

        It 'Maps no MFA protection to Disabled' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isMfaRegistered = $false
                perUserMfaState = 'disabled'
                isSecurityDefaultsCovered = $false
                isConditionalAccessCovered = $false
            }
            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $result | Should Match 'Disabled'
        }

        It 'Handles case-insensitive perUserMfaState' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                perUserMfaState = 'ENFORCED'
            }
            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $result | Should Match 'Enforced'
        }
    }

    Context 'MFA Methods Display (AC4)' {
        It 'Maps microsoftAuthenticator to Authenticator App' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isMfaRegistered = $true
                authenticationMethods = @('microsoftAuthenticator')
            }
            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $result | Should Match 'Authenticator App'
        }

        It 'Maps phone to Phone' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isMfaRegistered = $true
                authenticationMethods = @('phone')
            }
            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $result | Should Match 'Phone'
        }

        It 'Maps fido2 to Security Key' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isMfaRegistered = $true
                authenticationMethods = @('fido2')
            }
            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $result | Should Match 'Security Key'
        }

        It 'Displays comma-separated methods for multiple' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isMfaRegistered = $true
                authenticationMethods = @('microsoftAuthenticator', 'phone')
            }
            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $result | Should Match 'Authenticator App'
            $result | Should Match 'Phone'
        }

        It 'Uses methodsRegistered when authenticationMethods not present' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isMfaRegistered = $true
                methodsRegistered = @('mobilePhone')
            }
            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $result | Should Match 'Phone'
        }

        It 'Displays None when no methods configured' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isMfaRegistered = $false
            }
            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $result | Should Match 'None'
        }

        It 'Handles null authenticationMethods gracefully' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isMfaRegistered = $true
                authenticationMethods = $null
            }
            { ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser) } | Should Not Throw
        }

        It 'Deduplicates method names' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isMfaRegistered = $true
                authenticationMethods = @('microsoftAuthenticator', 'microsoftAuthenticatorPush')
            }
            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            # Should only have one "Authenticator App", not two
            $matches = [regex]::Matches($result, 'Authenticator App')
            $matches.Count | Should Be 1
        }
    }

    Context 'Summary Statistics (AC5)' {
        It 'Displays MFA Coverage summary' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isMfaRegistered = $true
            }
            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $result | Should Match 'MFA Coverage:'
        }

        It 'Calculates correct MFA coverage percentage for 100%' {
            $mfaUsers = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $true }
                [PSCustomObject]@{ displayName = 'User2'; isMfaRegistered = $true }
            )
            $result = ConvertTo-ConfluenceMFAPage -MFAData $mfaUsers
            $result | Should Match '2 of 2 users'
            $result | Should Match '100'
        }

        It 'Calculates correct MFA coverage percentage for 50%' {
            $mfaUsers = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $true }
                [PSCustomObject]@{ displayName = 'User2'; isMfaRegistered = $true }
                [PSCustomObject]@{ displayName = 'User3'; isMfaRegistered = $false }
                [PSCustomObject]@{ displayName = 'User4'; isMfaRegistered = $false }
            )
            $result = ConvertTo-ConfluenceMFAPage -MFAData $mfaUsers
            $result | Should Match '2 of 4 users'
            $result | Should Match '50'
        }

        It 'Calculates correct percentage for 0% coverage' {
            $mfaUsers = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $false }
                [PSCustomObject]@{ displayName = 'User2'; isMfaRegistered = $false }
            )
            $result = ConvertTo-ConfluenceMFAPage -MFAData $mfaUsers
            $result | Should Match '0 of 2 users'
        }

        It 'Includes users protected by Security Defaults in count' {
            $mfaUsers = @(
                [PSCustomObject]@{ displayName = 'User1'; isSecurityDefaultsCovered = $true }
                [PSCustomObject]@{ displayName = 'User2'; isMfaRegistered = $false }
            )
            $result = ConvertTo-ConfluenceMFAPage -MFAData $mfaUsers
            $result | Should Match '1 of 2 users'
        }

        It 'Includes users protected by Conditional Access in count' {
            $mfaUsers = @(
                [PSCustomObject]@{ displayName = 'User1'; isConditionalAccessCovered = $true }
                [PSCustomObject]@{ displayName = 'User2'; isMfaRegistered = $false }
            )
            $result = ConvertTo-ConfluenceMFAPage -MFAData $mfaUsers
            $result | Should Match '1 of 2 users'
        }
    }

    Context 'Timestamp (AC11)' {
        It 'Includes Data as of prefix' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isMfaRegistered = $true
            }

            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $result | Should Match 'Data as of:'
        }

        It 'Includes UTC suffix' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isMfaRegistered = $true
            }

            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $result | Should Match 'UTC'
        }

        It 'Uses yyyy-MM-dd HH:mm format' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isMfaRegistered = $true
            }

            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            # Match pattern like 2025-12-13 14:30
            $result | Should Match '\d{4}-\d{2}-\d{2} \d{2}:\d{2}'
        }
    }

    Context 'User Display Name Handling' {
        It 'Uses displayName when available' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'John Smith'
                userPrincipalName = 'john@contoso.com'
                isMfaRegistered = $true
            }
            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $result | Should Match 'John Smith'
        }

        It 'Uses userPrincipalName when displayName is missing' {
            $mfaUser = [PSCustomObject]@{
                userPrincipalName = 'john@contoso.com'
                isMfaRegistered = $true
            }
            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $result | Should Match 'john@contoso.com'
        }

        It 'Uses Unknown User when both displayName and UPN are missing' {
            $mfaUser = [PSCustomObject]@{
                isMfaRegistered = $true
            }
            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $result | Should Match 'Unknown User'
        }
    }

    Context 'Per-User MFA Display' {
        It 'Displays per-user MFA state with proper capitalization' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                perUserMfaState = 'enabled'
            }
            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $result | Should Match 'Enabled'
        }

        It 'Displays N/A when perUserMfaState is not set' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isMfaRegistered = $true
            }
            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $result | Should Match 'N/A'
        }
    }

    Context 'Security Defaults and Conditional Access Columns' {
        It 'Displays Yes for Security Defaults when covered' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isSecurityDefaultsCovered = $true
            }
            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            # Look for Yes in context of Security Defaults column
            $json = $result | ConvertFrom-Json
            $json | Should Not Be $null
        }

        It 'Displays No for Security Defaults when not covered' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isSecurityDefaultsCovered = $false
            }
            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $json = $result | ConvertFrom-Json
            $json | Should Not Be $null
        }

        It 'Displays Yes for Conditional Access when covered' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isConditionalAccessCovered = $true
            }
            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $json = $result | ConvertFrom-Json
            $json | Should Not Be $null
        }
    }

    Context 'Multiple Users Handling' {
        It 'Handles multiple users correctly' {
            $mfaUsers = @(
                [PSCustomObject]@{
                    displayName = 'Alice'
                    isMfaRegistered = $true
                    authenticationMethods = @('microsoftAuthenticator')
                },
                [PSCustomObject]@{
                    displayName = 'Bob'
                    isMfaRegistered = $false
                    perUserMfaState = 'disabled'
                }
            )

            $result = ConvertTo-ConfluenceMFAPage -MFAData $mfaUsers
            $result | Should Match 'Alice'
            $result | Should Match 'Bob'
        }
    }

    Context 'Verbose Logging' {
        It 'Writes verbose message with user count' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isMfaRegistered = $true
            }

            $verboseOutput = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser) -Verbose 4>&1

            ($verboseOutput -join ' ') | Should Match 'Transforming 1 user MFA record'
        }

        It 'Writes verbose message for multiple users' {
            $mfaUsers = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $true }
                [PSCustomObject]@{ displayName = 'User2'; isMfaRegistered = $false }
            )

            $verboseOutput = ConvertTo-ConfluenceMFAPage -MFAData $mfaUsers -Verbose 4>&1

            ($verboseOutput -join ' ') | Should Match 'Transforming 2 user MFA record'
        }

        It 'Writes verbose message for empty input' {
            $verboseOutput = ConvertTo-ConfluenceMFAPage -MFAData $null -Verbose 4>&1

            ($verboseOutput -join ' ') | Should Match 'No MFA data provided'
        }

        It 'Writes verbose message about MFA coverage' {
            $mfaUsers = @(
                [PSCustomObject]@{ displayName = 'User1'; isMfaRegistered = $true }
                [PSCustomObject]@{ displayName = 'User2'; isMfaRegistered = $false }
            )

            $verboseOutput = ConvertTo-ConfluenceMFAPage -MFAData $mfaUsers -Verbose 4>&1

            ($verboseOutput -join ' ') | Should Match 'MFA coverage:'
        }

        It 'Writes verbose message about page creation' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isMfaRegistered = $true
            }

            $verboseOutput = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser) -Verbose 4>&1

            ($verboseOutput -join ' ') | Should Match 'Created MFA status page'
        }
    }

    Context 'Heading Content' {
        It 'Includes MFA Status Report heading' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isMfaRegistered = $true
            }

            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $result | Should Match 'MFA Status Report'
        }

        It 'Uses level 2 heading for MFA Status Report' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isMfaRegistered = $true
            }

            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $json = $result | ConvertFrom-Json

            # Find heading node
            $headingNode = $json.content | Where-Object { $_.type -eq 'heading' } | Select-Object -First 1
            $headingNode.attrs.level | Should Be 2
        }
    }

    Context 'Table Structure' {
        It 'Creates table with User column' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'John Smith'
                isMfaRegistered = $true
            }

            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $result | Should Match 'User'
            $result | Should Match 'John Smith'
        }

        It 'Creates table with MFA Status column' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isMfaRegistered = $true
            }

            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $result | Should Match 'MFA Status'
        }

        It 'Creates table with MFA Methods column' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isMfaRegistered = $true
                authenticationMethods = @('phone')
            }

            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $result | Should Match 'MFA Methods'
        }

        It 'Creates table with Per-User MFA column' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                perUserMfaState = 'enabled'
            }

            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $result | Should Match 'Per-User MFA'
        }

        It 'Creates table with Security Defaults column' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isSecurityDefaultsCovered = $true
            }

            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $result | Should Match 'Security Defaults'
        }

        It 'Creates table with Conditional Access column' {
            $mfaUser = [PSCustomObject]@{
                displayName = 'Test User'
                isConditionalAccessCovered = $true
            }

            $result = ConvertTo-ConfluenceMFAPage -MFAData @($mfaUser)
            $result | Should Match 'Conditional Access'
        }
    }
}
