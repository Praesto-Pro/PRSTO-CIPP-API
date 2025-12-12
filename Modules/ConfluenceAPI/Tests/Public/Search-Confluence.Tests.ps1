#Requires -Modules Pester

Describe 'Search-Confluence' {
    BeforeAll {
        $ModulePath = (Get-Item "$PSScriptRoot\..\..\ConfluenceAPI.psd1").FullName
        Import-Module $ModulePath -Force
    }

    BeforeEach {
        InModuleScope ConfluenceAPI {
            $script:ConfluenceAPIKey = 'test-token'
            $script:ConfluenceBaseURL = 'https://test.atlassian.net'
        }
    }

    AfterEach {
        InModuleScope ConfluenceAPI {
            $script:ConfluenceAPIKey = $null
            $script:ConfluenceBaseURL = $null
        }
    }

    Context 'Basic Search Returns Results' {
        It 'Returns results with expected properties (Id, Title, Type, SpaceKey, Url, Excerpt) - wrapped response' {
            InModuleScope ConfluenceAPI {
                # Mock returns wrapped object (backward compatibility)
                Mock Invoke-ConfluenceRequest {
                    @{
                        results = @(
                            @{
                                content = @{
                                    id = '12345678'
                                    type = 'page'
                                    space = @{ key = 'CONTOSO' }
                                }
                                title = 'User Inventory'
                                url = '/spaces/CONTOSO/pages/12345678/User+Inventory'
                                excerpt = 'Matching text context...'
                            },
                            @{
                                content = @{
                                    id = '87654321'
                                    type = 'page'
                                    space = @{ key = 'CONTOSO' }
                                }
                                title = 'Endpoint Inventory'
                                url = '/spaces/CONTOSO/pages/87654321/Endpoint+Inventory'
                                excerpt = 'Another match...'
                            }
                        )
                    }
                }

                $result = Search-Confluence -CQL "space = 'CONTOSO' AND type = page"
                $result.Count | Should Be 2
                $result[0].Id | Should Be '12345678'
                $result[0].Title | Should Be 'User Inventory'
                $result[0].Type | Should Be 'page'
                $result[0].SpaceKey | Should Be 'CONTOSO'
                $result[0].Url | Should Be '/spaces/CONTOSO/pages/12345678/User+Inventory'
                $result[0].Excerpt | Should Be 'Matching text context...'
            }
        }

        It 'Returns results when Invoke-ConfluenceRequest returns array directly (production behavior)' {
            InModuleScope ConfluenceAPI {
                # Mock returns array directly (real Invoke-ConfluenceRequest behavior for paginated responses)
                Mock Invoke-ConfluenceRequest {
                    @(
                        @{
                            content = @{
                                id = '11111111'
                                type = 'page'
                                space = @{ key = 'PROD' }
                            }
                            title = 'Production Page'
                            url = '/spaces/PROD/pages/11111111/Production+Page'
                            excerpt = 'Real API response...'
                        },
                        @{
                            content = @{
                                id = '22222222'
                                type = 'page'
                                space = @{ key = 'PROD' }
                            }
                            title = 'Another Production Page'
                            url = '/spaces/PROD/pages/22222222/Another+Production+Page'
                            excerpt = 'Another result...'
                        }
                    )
                }

                $result = Search-Confluence -CQL "space = 'PROD'"
                $result.Count | Should Be 2
                $result[0].Id | Should Be '11111111'
                $result[0].Title | Should Be 'Production Page'
                $result[0].SpaceKey | Should Be 'PROD'
                $result[1].Id | Should Be '22222222'
            }
        }

        It 'Returns PSCustomObject for each result' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        results = @(
                            @{
                                content = @{ id = '123'; type = 'page'; space = @{ key = 'TEST' } }
                                title = 'Test Page'
                                url = '/spaces/TEST/pages/123'
                                excerpt = 'test'
                            }
                        )
                    }
                }

                $result = Search-Confluence -CQL "type = page"
                $result[0].GetType().Name | Should Be 'PSCustomObject'
                $propNames = $result[0].PSObject.Properties.Name
                ($propNames -contains 'Id') | Should Be $true
                ($propNames -contains 'Title') | Should Be $true
                ($propNames -contains 'Type') | Should Be $true
                ($propNames -contains 'SpaceKey') | Should Be $true
                ($propNames -contains 'Url') | Should Be $true
                ($propNames -contains 'Excerpt') | Should Be $true
            }
        }
    }

    Context 'Search by Label' {
        It 'Returns pages matching label query' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        results = @(
                            @{
                                content = @{ id = '111'; type = 'page'; space = @{ key = 'CLIENTS' } }
                                title = 'Client User Inventory'
                                url = '/spaces/CLIENTS/pages/111'
                                excerpt = 'User inventory for client'
                            }
                        )
                    }
                }

                $result = @(Search-Confluence -CQL "label = 'user-inventory'")
                $result.Count | Should Be 1
                $result[0].Title | Should Be 'Client User Inventory'
            }
        }
    }

    Context 'Text Search' {
        It 'Returns pages containing text with excerpts' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        results = @(
                            @{
                                content = @{ id = '222'; type = 'page'; space = @{ key = 'HR' } }
                                title = 'Employee Directory'
                                url = '/spaces/HR/pages/222'
                                excerpt = 'Contact information for <b>john smith</b> in the directory'
                            }
                        )
                    }
                }

                $result = @(Search-Confluence -CQL "text ~ 'john smith'")
                $result.Count | Should Be 1
                $result[0].Excerpt | Should Match 'john smith'
            }
        }
    }

    Context 'Empty Results' {
        It 'Returns empty array when no results found' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{ results = @() }
                }

                $result = @(Search-Confluence -CQL "space = 'NONEXISTENT'")
                $result.Count | Should Be 0
            }
        }

        It 'Returns empty array when results is null' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{ results = $null }
                }

                $result = Search-Confluence -CQL "type = page"
                @($result).Count | Should Be 0
            }
        }
    }

    Context 'Limit Parameter' {
        It 'Includes limit in request when specified' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{ results = @() }
                }

                $null = Search-Confluence -CQL "type = page" -Limit 50
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -match 'limit=50'
                }
            }
        }

        It 'Does not include limit when not specified or zero' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{ results = @() }
                }

                $null = Search-Confluence -CQL "type = page"
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -notmatch 'limit='
                }
            }
        }
    }

    Context 'Expand Parameter' {
        It 'Includes expand in request when specified' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{ results = @() }
                }

                $null = Search-Confluence -CQL "space = 'TEST'" -Expand 'content.body.view'
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -match 'expand=content\.body\.view'
                }
            }
        }

        It 'Verbose output logs expand parameter when specified' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{ results = @() }
                }

                $verboseOutput = @()
                Search-Confluence -CQL "type = page" -Expand 'content.body.view' -Verbose 4>&1 | ForEach-Object {
                    if ($_ -is [System.Management.Automation.VerboseRecord]) {
                        $verboseOutput += $_.Message
                    }
                }

                ($verboseOutput -join ' ') | Should Match 'content\.body\.view'
            }
        }
    }

    Context 'CQL URL Encoding' {
        It 'URL-encodes the CQL query string' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{ results = @() }
                }

                $null = Search-Confluence -CQL "space = 'CONTOSO'"
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    # CQL should be URL-encoded - spaces become %20, = becomes %3D, ' becomes %27
                    $Endpoint -match 'cql=' -and $Endpoint -match '%'
                }
            }
        }

        It 'Uses correct v1 API search endpoint' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{ results = @() }
                }

                $null = Search-Confluence -CQL "type = page"
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -match '^/wiki/rest/api/search\?' -and $Method -eq 'GET'
                }
            }
        }
    }

    Context 'Error Handling' {
        It '400 Invalid CQL throws with "Invalid CQL query" message' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Bad request (400): Invalid CQL')
                }

                { Search-Confluence -CQL "invalid cql syntax =" } | Should Throw 'Invalid CQL query'
            }
        }

        It '403 throws with "Access denied" message' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Forbidden (403)')
                }

                { Search-Confluence -CQL "space = 'SECRET'" } | Should Throw 'Access denied'
            }
        }

        It 'Generic error includes CQL query in message' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Connection timeout')
                }

                try {
                    Search-Confluence -CQL "space = 'TEST'"
                }
                catch {
                    $_.Exception.Message | Should Match "space = 'TEST'"
                    $_.Exception.Message | Should Match 'Failed to search'
                }
            }
        }
    }

    Context 'Verbose Output' {
        It 'Verbose output logs CQL query' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{ results = @() }
                }

                $verboseOutput = @()
                Search-Confluence -CQL "space = 'CONTOSO' AND type = page" -Verbose 4>&1 | ForEach-Object {
                    if ($_ -is [System.Management.Automation.VerboseRecord]) {
                        $verboseOutput += $_.Message
                    }
                }

                ($verboseOutput -join ' ') | Should Match 'CONTOSO'
            }
        }

        It 'Verbose output does not contain API token' {
            InModuleScope ConfluenceAPI {
                Mock Invoke-ConfluenceRequest {
                    @{
                        results = @(
                            @{
                                content = @{ id = '123'; type = 'page'; space = @{ key = 'TEST' } }
                                title = 'Test'
                                url = '/test'
                                excerpt = 'test'
                            }
                        )
                    }
                }

                $verboseOutput = @()
                Search-Confluence -CQL "type = page" -Verbose 4>&1 | ForEach-Object {
                    if ($_ -is [System.Management.Automation.VerboseRecord]) {
                        $verboseOutput += $_.Message
                    }
                }

                foreach ($msg in $verboseOutput) {
                    $msg | Should Not Match 'test-token'
                }
            }
        }
    }

    Context 'Parameter Validation' {
        It 'Requires CQL parameter' {
            { Search-Confluence } | Should Throw
        }

        It 'Does not accept empty CQL' {
            { Search-Confluence -CQL '' } | Should Throw
        }

        It 'Does not accept null CQL' {
            { Search-Confluence -CQL $null } | Should Throw
        }
    }
}
