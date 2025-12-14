$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$privateDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'Private'

Describe 'ConvertTo-ConfluenceLicensePage' {
    BeforeAll {
        # Dot-source dependencies (real implementations for unit tests)
        . "$privateDir\New-ADFDocument.ps1"
        . "$privateDir\Add-ADFContent.ps1"
        . "$privateDir\ConvertTo-ADF.ps1"
        . "$privateDir\New-ADFTable.ps1"
        . "$privateDir\New-ADFHeading.ps1"
        . "$privateDir\New-ADFParagraph.ps1"
        . "$privateDir\ConvertTo-ConfluenceLicensePage.ps1"
    }

    Context 'Empty/Null Input Handling (AC5)' {
        It 'Returns valid ADF with message when Licenses is null' {
            $result = ConvertTo-ConfluenceLicensePage -Licenses $null
            $result | Should Not Be $null
            $result | Should Match 'No license data available'
        }

        It 'Returns valid ADF with message when Licenses is empty array' {
            $result = ConvertTo-ConfluenceLicensePage -Licenses @()
            $result | Should Not Be $null
            $result | Should Match 'No license data available'
        }

        It 'Returns valid JSON when Licenses is null' {
            $result = ConvertTo-ConfluenceLicensePage -Licenses $null
            { $result | ConvertFrom-Json } | Should Not Throw
        }

        It 'Includes License Report heading when Licenses is null' {
            $result = ConvertTo-ConfluenceLicensePage -Licenses $null
            $result | Should Match 'License Report'
        }

        It 'Includes timestamp in empty state (FR44 compliance)' {
            $result = ConvertTo-ConfluenceLicensePage -Licenses $null
            $result | Should Match 'Data as of:'
            $result | Should Match 'UTC'
        }

        It 'Uses UTC format in empty state timestamp' {
            $result = ConvertTo-ConfluenceLicensePage -Licenses @()
            $result | Should Match '\d{4}-\d{2}-\d{2} \d{2}:\d{2}'
        }
    }

    Context 'Valid ADF Output (AC1)' {
        It 'Returns a non-null string' {
            $license = [PSCustomObject]@{
                skuPartNumber = 'TEST'
                prepaidUnits = @{ enabled = 10 }
                consumedUnits = 5
            }

            $result = ConvertTo-ConfluenceLicensePage -Licenses @($license)
            $result | Should Not Be $null
            $result | Should BeOfType [string]
        }

        It 'Returns valid JSON' {
            $license = [PSCustomObject]@{
                skuPartNumber = 'TEST'
                prepaidUnits = @{ enabled = 10 }
                consumedUnits = 5
            }

            $result = ConvertTo-ConfluenceLicensePage -Licenses @($license)
            { $result | ConvertFrom-Json } | Should Not Throw
        }

        It 'Returns valid ADF document structure' {
            $license = [PSCustomObject]@{
                skuPartNumber = 'TEST'
                prepaidUnits = @{ enabled = 10 }
                consumedUnits = 5
            }

            $result = ConvertTo-ConfluenceLicensePage -Licenses @($license)
            $json = $result | ConvertFrom-Json
            $json.type | Should Be 'doc'
            $json.version | Should Be 1
        }
    }

    Context 'License Summary Table (AC2)' {
        It 'Creates table with License Name column' {
            $license = [PSCustomObject]@{
                skuId = 'test-sku-id'
                skuPartNumber = 'ENTERPRISEPREMIUM'
                prepaidUnits = @{ enabled = 50 }
                consumedUnits = 25
            }

            $result = ConvertTo-ConfluenceLicensePage -Licenses @($license)
            $result | Should Match 'ENTERPRISEPREMIUM'
        }

        It 'Creates table with Total column showing prepaidUnits.enabled' {
            $license = [PSCustomObject]@{
                skuPartNumber = 'TEST'
                prepaidUnits = @{ enabled = 100 }
                consumedUnits = 40
            }

            $result = ConvertTo-ConfluenceLicensePage -Licenses @($license)
            $result | Should Match '100'
        }

        It 'Creates table with Used column showing consumedUnits' {
            $license = [PSCustomObject]@{
                skuPartNumber = 'TEST'
                prepaidUnits = @{ enabled = 50 }
                consumedUnits = 25
            }

            $result = ConvertTo-ConfluenceLicensePage -Licenses @($license)
            $result | Should Match '25'
        }

        It 'Handles multiple licenses' {
            $licenses = @(
                [PSCustomObject]@{
                    skuPartNumber = 'LICENSE_A'
                    prepaidUnits = @{ enabled = 100 }
                    consumedUnits = 50
                },
                [PSCustomObject]@{
                    skuPartNumber = 'LICENSE_B'
                    prepaidUnits = @{ enabled = 200 }
                    consumedUnits = 75
                }
            )

            $result = ConvertTo-ConfluenceLicensePage -Licenses $licenses
            $result | Should Match 'LICENSE_A'
            $result | Should Match 'LICENSE_B'
        }

        It 'Uses Unknown for missing skuPartNumber' {
            $license = [PSCustomObject]@{
                skuId = 'some-id'
                prepaidUnits = @{ enabled = 10 }
                consumedUnits = 5
            }

            $result = ConvertTo-ConfluenceLicensePage -Licenses @($license)
            $result | Should Match 'Unknown'
        }
    }

    Context 'Available Calculation (AC7)' {
        It 'Calculates Available as Total minus Used' {
            $license = [PSCustomObject]@{
                skuPartNumber = 'TEST'
                prepaidUnits = @{ enabled = 100 }
                consumedUnits = 40
            }

            $result = ConvertTo-ConfluenceLicensePage -Licenses @($license)
            # Available should be 60 (100 - 40)
            $result | Should Match '60'
        }

        It 'Shows 0 for negative Available (over-allocation)' {
            $license = [PSCustomObject]@{
                skuPartNumber = 'OVERALLOCATED'
                prepaidUnits = @{ enabled = 10 }
                consumedUnits = 15
            }

            $result = ConvertTo-ConfluenceLicensePage -Licenses @($license)
            # Should contain 0 for available, not -5
            $json = $result | ConvertFrom-Json

            # Parse the table data to check available value
            # The negative case should result in 0
            $result | Should Not Match '"-5"'
        }

        It 'Handles zero consumedUnits' {
            $license = [PSCustomObject]@{
                skuPartNumber = 'UNUSED'
                prepaidUnits = @{ enabled = 50 }
                consumedUnits = 0
            }

            $result = ConvertTo-ConfluenceLicensePage -Licenses @($license)
            $result | Should Match '50'  # Available = Total when Used = 0
        }

        It 'Handles missing prepaidUnits' {
            $license = [PSCustomObject]@{
                skuPartNumber = 'NO_PREPAID'
                consumedUnits = 5
            }

            $result = ConvertTo-ConfluenceLicensePage -Licenses @($license)
            # Should not throw, Total = 0
            { $result | ConvertFrom-Json } | Should Not Throw
        }

        It 'Handles missing consumedUnits' {
            $license = [PSCustomObject]@{
                skuPartNumber = 'NO_CONSUMED'
                prepaidUnits = @{ enabled = 25 }
            }

            $result = ConvertTo-ConfluenceLicensePage -Licenses @($license)
            # Used = 0, Available = 25
            $result | Should Match '25'
        }
    }

    Context 'Timestamp (AC4)' {
        It 'Includes Data as of prefix' {
            $license = [PSCustomObject]@{
                skuPartNumber = 'TEST'
                prepaidUnits = @{ enabled = 10 }
                consumedUnits = 5
            }

            $result = ConvertTo-ConfluenceLicensePage -Licenses @($license)
            $result | Should Match 'Data as of:'
        }

        It 'Includes UTC suffix' {
            $license = [PSCustomObject]@{
                skuPartNumber = 'TEST'
                prepaidUnits = @{ enabled = 10 }
                consumedUnits = 5
            }

            $result = ConvertTo-ConfluenceLicensePage -Licenses @($license)
            $result | Should Match 'UTC'
        }

        It 'Uses yyyy-MM-dd HH:mm format' {
            $license = [PSCustomObject]@{
                skuPartNumber = 'TEST'
                prepaidUnits = @{ enabled = 10 }
                consumedUnits = 5
            }

            $result = ConvertTo-ConfluenceLicensePage -Licenses @($license)
            # Match pattern like 2025-12-13 14:30
            $result | Should Match '\d{4}-\d{2}-\d{2} \d{2}:\d{2}'
        }
    }

    Context 'License Assignments Table (AC3)' {
        It 'Creates assignments table when Users provided' {
            $license = [PSCustomObject]@{
                skuId = 'sku-123'
                skuPartNumber = 'ENTERPRISEPREMIUM'
                prepaidUnits = @{ enabled = 50 }
                consumedUnits = 25
            }
            $user = [PSCustomObject]@{
                displayName = 'John Smith'
                userPrincipalName = 'john@contoso.com'
                assignedLicenses = @(
                    @{ skuId = 'sku-123' }
                )
            }

            $result = ConvertTo-ConfluenceLicensePage -Licenses @($license) -Users @($user)

            $result | Should Match 'License Assignments'
            $result | Should Match 'John Smith'
        }

        It 'Skips assignments table when Users not provided' {
            $license = [PSCustomObject]@{
                skuPartNumber = 'TEST'
                prepaidUnits = @{ enabled = 10 }
                consumedUnits = 5
            }

            $result = ConvertTo-ConfluenceLicensePage -Licenses @($license)

            $result | Should Not Match 'License Assignments'
        }

        It 'Skips assignments table when Users is empty array' {
            $license = [PSCustomObject]@{
                skuPartNumber = 'TEST'
                prepaidUnits = @{ enabled = 10 }
                consumedUnits = 5
            }

            $result = ConvertTo-ConfluenceLicensePage -Licenses @($license) -Users @()

            $result | Should Not Match 'License Assignments'
        }

        It 'Shows license name in assignments table' {
            $license = [PSCustomObject]@{
                skuId = 'sku-456'
                skuPartNumber = 'STANDARD_LICENSE'
                prepaidUnits = @{ enabled = 10 }
                consumedUnits = 5
            }
            $user = [PSCustomObject]@{
                displayName = 'Jane Doe'
                assignedLicenses = @(
                    @{ skuId = 'sku-456' }
                )
            }

            $result = ConvertTo-ConfluenceLicensePage -Licenses @($license) -Users @($user)

            $result | Should Match 'STANDARD_LICENSE'
            $result | Should Match 'Jane Doe'
        }

        It 'Creates multiple rows for user with multiple licenses' {
            $licenses = @(
                [PSCustomObject]@{
                    skuId = 'sku-a'
                    skuPartNumber = 'LICENSE_A'
                    prepaidUnits = @{ enabled = 100 }
                    consumedUnits = 50
                },
                [PSCustomObject]@{
                    skuId = 'sku-b'
                    skuPartNumber = 'LICENSE_B'
                    prepaidUnits = @{ enabled = 100 }
                    consumedUnits = 50
                }
            )
            $user = [PSCustomObject]@{
                displayName = 'Multi License User'
                assignedLicenses = @(
                    @{ skuId = 'sku-a' },
                    @{ skuId = 'sku-b' }
                )
            }

            $result = ConvertTo-ConfluenceLicensePage -Licenses $licenses -Users @($user)

            $result | Should Match 'LICENSE_A'
            $result | Should Match 'LICENSE_B'
            # User should appear for both licenses
            $matches = [regex]::Matches($result, 'Multi License User')
            $matches.Count | Should Be 2
        }

        It 'Sorts assignments by user displayName' {
            $license = [PSCustomObject]@{
                skuId = 'sku-x'
                skuPartNumber = 'TEST_LIC'
                prepaidUnits = @{ enabled = 100 }
                consumedUnits = 50
            }
            $users = @(
                [PSCustomObject]@{
                    displayName = 'Zack Last'
                    assignedLicenses = @(@{ skuId = 'sku-x' })
                },
                [PSCustomObject]@{
                    displayName = 'Alice First'
                    assignedLicenses = @(@{ skuId = 'sku-x' })
                }
            )

            $result = ConvertTo-ConfluenceLicensePage -Licenses @($license) -Users $users

            # Alice should appear before Zack in the output
            $aliceIndex = $result.IndexOf('Alice First')
            $zackIndex = $result.IndexOf('Zack Last')
            $aliceIndex | Should BeLessThan $zackIndex
        }

        It 'Uses userPrincipalName when displayName is missing' {
            $license = [PSCustomObject]@{
                skuId = 'sku-y'
                skuPartNumber = 'TEST_LIC'
                prepaidUnits = @{ enabled = 10 }
                consumedUnits = 5
            }
            $user = [PSCustomObject]@{
                userPrincipalName = 'noname@contoso.com'
                assignedLicenses = @(@{ skuId = 'sku-y' })
            }

            $result = ConvertTo-ConfluenceLicensePage -Licenses @($license) -Users @($user)

            $result | Should Match 'noname@contoso.com'
        }

        It 'Handles user with no assignedLicenses' {
            $license = [PSCustomObject]@{
                skuId = 'sku-z'
                skuPartNumber = 'TEST_LIC'
                prepaidUnits = @{ enabled = 10 }
                consumedUnits = 5
            }
            $users = @(
                [PSCustomObject]@{
                    displayName = 'Licensed User'
                    assignedLicenses = @(@{ skuId = 'sku-z' })
                },
                [PSCustomObject]@{
                    displayName = 'Unlicensed User'
                    assignedLicenses = @()
                }
            )

            $result = ConvertTo-ConfluenceLicensePage -Licenses @($license) -Users $users

            $result | Should Match 'Licensed User'
            $result | Should Not Match 'Unlicensed User'
        }

        It 'Truncates unknown skuId in assignments' {
            $license = [PSCustomObject]@{
                skuId = 'known-sku'
                skuPartNumber = 'KNOWN_LICENSE'
                prepaidUnits = @{ enabled = 10 }
                consumedUnits = 5
            }
            $user = [PSCustomObject]@{
                displayName = 'User With Unknown'
                assignedLicenses = @(@{ skuId = 'unknown-very-long-sku-id-12345' })
            }

            $result = ConvertTo-ConfluenceLicensePage -Licenses @($license) -Users @($user)

            # Unknown SKU should be truncated to 8 chars + ...
            $result | Should Match 'unknown-\.\.\.'
        }

        It 'Uses Unknown User when displayName and UPN are missing' {
            $license = [PSCustomObject]@{
                skuId = 'sku-unknown-user'
                skuPartNumber = 'TEST_LIC'
                prepaidUnits = @{ enabled = 10 }
                consumedUnits = 5
            }
            $user = [PSCustomObject]@{
                assignedLicenses = @(@{ skuId = 'sku-unknown-user' })
            }

            $result = ConvertTo-ConfluenceLicensePage -Licenses @($license) -Users @($user)

            $result | Should Match 'Unknown User'
        }
    }

    Context 'Verbose Logging (AC6)' {
        It 'Writes verbose message with license count' {
            $license = [PSCustomObject]@{
                skuPartNumber = 'TEST'
                prepaidUnits = @{ enabled = 10 }
                consumedUnits = 5
            }

            $verboseOutput = ConvertTo-ConfluenceLicensePage -Licenses @($license) -Verbose 4>&1

            ($verboseOutput -join ' ') | Should Match 'Transforming 1 license type'
        }

        It 'Writes verbose message for multiple licenses' {
            $licenses = @(
                [PSCustomObject]@{
                    skuPartNumber = 'A'
                    prepaidUnits = @{ enabled = 10 }
                    consumedUnits = 5
                },
                [PSCustomObject]@{
                    skuPartNumber = 'B'
                    prepaidUnits = @{ enabled = 20 }
                    consumedUnits = 10
                }
            )

            $verboseOutput = ConvertTo-ConfluenceLicensePage -Licenses $licenses -Verbose 4>&1

            ($verboseOutput -join ' ') | Should Match 'Transforming 2 license type'
        }

        It 'Writes verbose message for empty input' {
            $verboseOutput = ConvertTo-ConfluenceLicensePage -Licenses $null -Verbose 4>&1

            ($verboseOutput -join ' ') | Should Match 'No licenses provided'
        }

        It 'Writes verbose message for user processing' {
            $license = [PSCustomObject]@{
                skuId = 'sku-v'
                skuPartNumber = 'TEST'
                prepaidUnits = @{ enabled = 10 }
                consumedUnits = 5
            }
            $users = @(
                [PSCustomObject]@{
                    displayName = 'User1'
                    assignedLicenses = @(@{ skuId = 'sku-v' })
                },
                [PSCustomObject]@{
                    displayName = 'User2'
                    assignedLicenses = @(@{ skuId = 'sku-v' })
                }
            )

            $verboseOutput = ConvertTo-ConfluenceLicensePage -Licenses @($license) -Users $users -Verbose 4>&1

            ($verboseOutput -join ' ') | Should Match 'Processing 2 user'
        }

        It 'Writes verbose message for assignments table creation' {
            $license = [PSCustomObject]@{
                skuId = 'sku-w'
                skuPartNumber = 'TEST'
                prepaidUnits = @{ enabled = 10 }
                consumedUnits = 5
            }
            $user = [PSCustomObject]@{
                displayName = 'Test User'
                assignedLicenses = @(@{ skuId = 'sku-w' })
            }

            $verboseOutput = ConvertTo-ConfluenceLicensePage -Licenses @($license) -Users @($user) -Verbose 4>&1

            ($verboseOutput -join ' ') | Should Match 'Created assignments table with 1 assignment'
        }
    }

    Context 'Heading Content' {
        It 'Includes License Report heading' {
            $license = [PSCustomObject]@{
                skuPartNumber = 'TEST'
                prepaidUnits = @{ enabled = 10 }
                consumedUnits = 5
            }

            $result = ConvertTo-ConfluenceLicensePage -Licenses @($license)
            $result | Should Match 'License Report'
        }

        It 'Uses level 2 heading for License Report' {
            $license = [PSCustomObject]@{
                skuPartNumber = 'TEST'
                prepaidUnits = @{ enabled = 10 }
                consumedUnits = 5
            }

            $result = ConvertTo-ConfluenceLicensePage -Licenses @($license)
            $json = $result | ConvertFrom-Json

            # Find heading node
            $headingNode = $json.content | Where-Object { $_.type -eq 'heading' } | Select-Object -First 1
            $headingNode.attrs.level | Should Be 2
        }

        It 'Uses level 3 heading for License Assignments' {
            $license = [PSCustomObject]@{
                skuId = 'sku-h'
                skuPartNumber = 'TEST'
                prepaidUnits = @{ enabled = 10 }
                consumedUnits = 5
            }
            $user = [PSCustomObject]@{
                displayName = 'Test User'
                assignedLicenses = @(@{ skuId = 'sku-h' })
            }

            $result = ConvertTo-ConfluenceLicensePage -Licenses @($license) -Users @($user)
            $json = $result | ConvertFrom-Json

            # Find all heading nodes
            $headings = $json.content | Where-Object { $_.type -eq 'heading' }
            $assignmentsHeading = $headings | Where-Object { $_.attrs.level -eq 3 }
            $assignmentsHeading | Should Not Be $null
        }
    }
}
