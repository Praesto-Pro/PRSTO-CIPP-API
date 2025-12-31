#Requires -Modules Pester

Describe 'New-ConfluencePage' {
    BeforeAll {
        $ModulePath = (Get-Item "$PSScriptRoot\..\..\ConfluenceAPI.psd1").FullName
        Import-Module $ModulePath -Force
    }

    BeforeEach {
        InModuleScope ConfluenceAPI {
            $script:ConfluenceAPIKey = 'test-token'
            $script:ConfluenceUserEmail = 'test@example.com'
            $script:ConfluenceBaseURL = 'https://test.atlassian.net'
        }
    }

    AfterEach {
        InModuleScope ConfluenceAPI {
            $script:ConfluenceAPIKey = $null
            $script:ConfluenceUserEmail = $null
            $script:ConfluenceBaseURL = $null
        }
    }

    Context 'Create Page with Required Parameters' {
        It 'Creates page with SpaceKey and Title' {
            InModuleScope ConfluenceAPI {
                Mock Get-ConfluenceSpace {
                    [PSCustomObject]@{ Id = '789012'; Key = 'TEST'; Name = 'Test Space' }
                }
                Mock Invoke-ConfluenceRequest {
                    @{
                        id         = '123456'
                        title      = 'New Page'
                        spaceId    = '789012'
                        status     = 'current'
                        parentId   = $null
                        parentType = $null
                        authorId   = 'user123'
                        createdAt  = '2025-12-11T10:00:00Z'
                        version    = @{ number = 1 }
                    }
                }

                $result = New-ConfluencePage -SpaceKey 'TEST' -Title 'New Page'
                $result.Id | Should Be '123456'
                $result.Title | Should Be 'New Page'
                $result.SpaceId | Should Be '789012'
                $result.Status | Should Be 'current'
                $result.Version | Should Be 1
            }
        }

        It 'Calls POST endpoint' {
            InModuleScope ConfluenceAPI {
                Mock Get-ConfluenceSpace {
                    [PSCustomObject]@{ Id = '456'; Key = 'TEST'; Name = 'Test Space' }
                }
                Mock Invoke-ConfluenceRequest {
                    @{
                        id      = '123'
                        title   = 'Test'
                        spaceId = '456'
                        status  = 'current'
                        version = @{ number = 1 }
                    }
                }

                $result = New-ConfluencePage -SpaceKey 'TEST' -Title 'Test'
                Assert-MockCalled Invoke-ConfluenceRequest -ParameterFilter {
                    $Endpoint -eq '/wiki/api/v2/pages' -and $Method -eq 'POST'
                }
            }
        }

        It 'Includes spaceId (looked up from SpaceKey) and title in request body' {
            InModuleScope ConfluenceAPI {
                Mock Get-ConfluenceSpace {
                    [PSCustomObject]@{ Id = '789'; Key = 'TEST'; Name = 'Test Space' }
                }
                Mock Invoke-ConfluenceRequest {
                    param($Endpoint, $Method, $Body)
                    $bodyObj = $Body | ConvertFrom-Json
                    if ($bodyObj.spaceId -ne '789' -or $bodyObj.title -ne 'Test Title') {
                        throw "Invalid body"
                    }
                    @{
                        id      = '123'
                        title   = 'Test Title'
                        spaceId = '789'
                        status  = 'current'
                        version = @{ number = 1 }
                    }
                }

                $result = New-ConfluencePage -SpaceKey 'TEST' -Title 'Test Title'
                Assert-MockCalled Invoke-ConfluenceRequest -Times 1
            }
        }
    }

    Context 'Create Page with Body Content' {
        It 'Includes Body content when provided' {
            InModuleScope ConfluenceAPI {
                Mock Get-ConfluenceSpace {
                    [PSCustomObject]@{ Id = '456'; Key = 'TEST'; Name = 'Test Space' }
                }
                Mock Invoke-ConfluenceRequest {
                    param($Endpoint, $Method, $Body)
                    $bodyObj = $Body | ConvertFrom-Json
                    if (-not $bodyObj.body -or $bodyObj.body.value -ne '<p>Content</p>') {
                        throw "Body not included correctly"
                    }
                    @{
                        id      = '123'
                        title   = 'Test'
                        spaceId = '456'
                        status  = 'current'
                        version = @{ number = 1 }
                    }
                }

                $result = New-ConfluencePage -SpaceKey 'TEST' -Title 'Test' -Body '<p>Content</p>'
                Assert-MockCalled Invoke-ConfluenceRequest -Times 1
            }
        }

        It 'Sets body representation to storage for HTML content' {
            InModuleScope ConfluenceAPI {
                Mock Get-ConfluenceSpace {
                    [PSCustomObject]@{ Id = '456'; Key = 'TEST'; Name = 'Test Space' }
                }
                Mock Invoke-ConfluenceRequest {
                    param($Endpoint, $Method, $Body)
                    $bodyObj = $Body | ConvertFrom-Json
                    if ($bodyObj.body.representation -ne 'storage') {
                        throw "Body representation not storage"
                    }
                    @{
                        id      = '123'
                        title   = 'Test'
                        spaceId = '456'
                        status  = 'current'
                        version = @{ number = 1 }
                    }
                }

                $result = New-ConfluencePage -SpaceKey 'TEST' -Title 'Test' -Body '<p>Test</p>'
                Assert-MockCalled Invoke-ConfluenceRequest -Times 1
            }
        }
    }

    Context 'Create Page with ADF Content' {
        It 'Sets body representation to atlas_doc_format for ADF JSON' {
            InModuleScope ConfluenceAPI {
                Mock Get-ConfluenceSpace {
                    [PSCustomObject]@{ Id = '456'; Key = 'TEST'; Name = 'Test Space' }
                }
                Mock Invoke-ConfluenceRequest {
                    param($Endpoint, $Method, $Body)
                    $bodyObj = $Body | ConvertFrom-Json
                    if ($bodyObj.body.representation -ne 'atlas_doc_format') {
                        throw "Body representation not atlas_doc_format, was: $($bodyObj.body.representation)"
                    }
                    @{
                        id      = '123'
                        title   = 'Test'
                        spaceId = '456'
                        status  = 'current'
                        version = @{ number = 1 }
                    }
                }

                $adfJson = '{"version":1,"type":"doc","content":[]}'
                $result = New-ConfluencePage -SpaceKey 'TEST' -Title 'Test' -Body $adfJson
                Assert-MockCalled Invoke-ConfluenceRequest -Times 1
            }
        }

        It 'Detects ADF JSON with content' {
            InModuleScope ConfluenceAPI {
                Mock Get-ConfluenceSpace {
                    [PSCustomObject]@{ Id = '456'; Key = 'TEST'; Name = 'Test Space' }
                }
                Mock Invoke-ConfluenceRequest {
                    param($Endpoint, $Method, $Body)
                    $bodyObj = $Body | ConvertFrom-Json
                    if ($bodyObj.body.representation -ne 'atlas_doc_format') {
                        throw "Body representation not atlas_doc_format"
                    }
                    @{
                        id      = '123'
                        title   = 'Test'
                        spaceId = '456'
                        status  = 'current'
                        version = @{ number = 1 }
                    }
                }

                $adfJson = '{"version":1,"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Hello"}]}]}'
                $result = New-ConfluencePage -SpaceKey 'TEST' -Title 'Test' -Body $adfJson
                Assert-MockCalled Invoke-ConfluenceRequest -Times 1
            }
        }

        It 'Detects ADF with whitespace formatting' {
            InModuleScope ConfluenceAPI {
                Mock Get-ConfluenceSpace {
                    [PSCustomObject]@{ Id = '456'; Key = 'TEST'; Name = 'Test Space' }
                }
                Mock Invoke-ConfluenceRequest {
                    param($Endpoint, $Method, $Body)
                    $bodyObj = $Body | ConvertFrom-Json
                    if ($bodyObj.body.representation -ne 'atlas_doc_format') {
                        throw "Body representation not atlas_doc_format"
                    }
                    @{
                        id      = '123'
                        title   = 'Test'
                        spaceId = '456'
                        status  = 'current'
                        version = @{ number = 1 }
                    }
                }

                $adfJson = @'
{
    "version": 1,
    "type": "doc",
    "content": []
}
'@
                $result = New-ConfluencePage -SpaceKey 'TEST' -Title 'Test' -Body $adfJson
                Assert-MockCalled Invoke-ConfluenceRequest -Times 1
            }
        }

        It 'Uses storage format for non-ADF JSON-like content' {
            InModuleScope ConfluenceAPI {
                Mock Get-ConfluenceSpace {
                    [PSCustomObject]@{ Id = '456'; Key = 'TEST'; Name = 'Test Space' }
                }
                Mock Invoke-ConfluenceRequest {
                    param($Endpoint, $Method, $Body)
                    $bodyObj = $Body | ConvertFrom-Json
                    if ($bodyObj.body.representation -ne 'storage') {
                        throw "Body representation not storage, was: $($bodyObj.body.representation)"
                    }
                    @{
                        id      = '123'
                        title   = 'Test'
                        spaceId = '456'
                        status  = 'current'
                        version = @{ number = 1 }
                    }
                }

                # This is JSON but not ADF (missing version:1 and type:doc)
                $nonAdfJson = '{"name":"test","value":123}'
                $result = New-ConfluencePage -SpaceKey 'TEST' -Title 'Test' -Body $nonAdfJson
                Assert-MockCalled Invoke-ConfluenceRequest -Times 1
            }
        }

        It 'Uses storage format for JSON with misleading ADF-like properties' {
            InModuleScope ConfluenceAPI {
                Mock Get-ConfluenceSpace {
                    [PSCustomObject]@{ Id = '456'; Key = 'TEST'; Name = 'Test Space' }
                }
                Mock Invoke-ConfluenceRequest {
                    param($Endpoint, $Method, $Body)
                    $bodyObj = $Body | ConvertFrom-Json
                    if ($bodyObj.body.representation -ne 'storage') {
                        throw "Body representation not storage, was: $($bodyObj.body.representation)"
                    }
                    @{
                        id      = '123'
                        title   = 'Test'
                        spaceId = '456'
                        status  = 'current'
                        version = @{ number = 1 }
                    }
                }

                # This JSON has version:1 and mentions "doc" but is NOT valid ADF
                # (type is not "doc", it's "note", and docType is a different property)
                $misleadingJson = '{"version":1,"docType":"doc","type":"note"}'
                $result = New-ConfluencePage -SpaceKey 'TEST' -Title 'Test' -Body $misleadingJson
                Assert-MockCalled Invoke-ConfluenceRequest -Times 1
            }
        }

        It 'Uses storage format for invalid JSON strings' {
            InModuleScope ConfluenceAPI {
                Mock Get-ConfluenceSpace {
                    [PSCustomObject]@{ Id = '456'; Key = 'TEST'; Name = 'Test Space' }
                }
                Mock Invoke-ConfluenceRequest {
                    param($Endpoint, $Method, $Body)
                    $bodyObj = $Body | ConvertFrom-Json
                    if ($bodyObj.body.representation -ne 'storage') {
                        throw "Body representation not storage, was: $($bodyObj.body.representation)"
                    }
                    @{
                        id      = '123'
                        title   = 'Test'
                        spaceId = '456'
                        status  = 'current'
                        version = @{ number = 1 }
                    }
                }

                # This looks like it starts with { but is not valid JSON
                $invalidJson = '{not valid json at all'
                $result = New-ConfluencePage -SpaceKey 'TEST' -Title 'Test' -Body $invalidJson
                Assert-MockCalled Invoke-ConfluenceRequest -Times 1
            }
        }
    }

    Context 'Create Child Page' {
        It 'Includes ParentId when creating child page' {
            InModuleScope ConfluenceAPI {
                Mock Get-ConfluenceSpace {
                    [PSCustomObject]@{ Id = '456'; Key = 'TEST'; Name = 'Test Space' }
                }
                Mock Invoke-ConfluenceRequest {
                    param($Endpoint, $Method, $Body)
                    $bodyObj = $Body | ConvertFrom-Json
                    if ($bodyObj.parentId -ne '111222') {
                        throw "ParentId not included"
                    }
                    @{
                        id         = '123'
                        title      = 'Child Page'
                        spaceId    = '456'
                        status     = 'current'
                        parentId   = '111222'
                        parentType = 'page'
                        version    = @{ number = 1 }
                    }
                }

                $result = New-ConfluencePage -SpaceKey 'TEST' -Title 'Child Page' -ParentId '111222'
                $result.ParentId | Should Be '111222'
            }
        }

        It 'Returns parent information in result' {
            InModuleScope ConfluenceAPI {
                Mock Get-ConfluenceSpace {
                    [PSCustomObject]@{ Id = '456'; Key = 'TEST'; Name = 'Test Space' }
                }
                Mock Invoke-ConfluenceRequest {
                    @{
                        id         = '123'
                        title      = 'Child Page'
                        spaceId    = '456'
                        status     = 'current'
                        parentId   = '999'
                        parentType = 'page'
                        version    = @{ number = 1 }
                    }
                }

                $result = New-ConfluencePage -SpaceKey 'TEST' -Title 'Child Page' -ParentId '999'
                $result.ParentId | Should Be '999'
                $result.ParentType | Should Be 'page'
            }
        }
    }

    Context 'WhatIf Support' {
        It 'Does not call API when WhatIf is specified' {
            InModuleScope ConfluenceAPI {
                Mock Get-ConfluenceSpace {
                    [PSCustomObject]@{ Id = '456'; Key = 'TEST'; Name = 'Test Space' }
                }
                Mock Invoke-ConfluenceRequest {
                    throw "Should not be called"
                }

                $result = New-ConfluencePage -SpaceKey 'TEST' -Title 'Test' -WhatIf
                Assert-MockCalled Invoke-ConfluenceRequest -Times 0
            }
        }

        It 'Returns null when WhatIf is specified' {
            InModuleScope ConfluenceAPI {
                Mock Get-ConfluenceSpace {
                    [PSCustomObject]@{ Id = '456'; Key = 'TEST'; Name = 'Test Space' }
                }
                Mock Invoke-ConfluenceRequest {
                    @{ id = '123' }
                }

                $result = New-ConfluencePage -SpaceKey 'TEST' -Title 'Test' -WhatIf
                $result | Should Be $null
            }
        }
    }

    Context 'Return Value' {
        It 'Returns PSCustomObject with correct properties' {
            InModuleScope ConfluenceAPI {
                Mock Get-ConfluenceSpace {
                    [PSCustomObject]@{ Id = '888'; Key = 'TEST'; Name = 'Test Space' }
                }
                Mock Invoke-ConfluenceRequest {
                    @{
                        id         = '999'
                        title      = 'Created Page'
                        spaceId    = '888'
                        status     = 'current'
                        parentId   = $null
                        parentType = $null
                        authorId   = 'author123'
                        createdAt  = '2025-12-11T12:00:00Z'
                        version    = @{ number = 1 }
                    }
                }

                $result = New-ConfluencePage -SpaceKey 'TEST' -Title 'Created Page'
                $propNames = $result.PSObject.Properties.Name

                ($propNames -contains 'Id') | Should Be $true
                ($propNames -contains 'Title') | Should Be $true
                ($propNames -contains 'SpaceId') | Should Be $true
                ($propNames -contains 'Status') | Should Be $true
                ($propNames -contains 'ParentId') | Should Be $true
                ($propNames -contains 'ParentType') | Should Be $true
                ($propNames -contains 'AuthorId') | Should Be $true
                ($propNames -contains 'CreatedAt') | Should Be $true
                ($propNames -contains 'Version') | Should Be $true
            }
        }
    }

    Context 'Error Handling' {
        It 'Throws when space not found via Get-ConfluenceSpace' {
            InModuleScope ConfluenceAPI {
                Mock Get-ConfluenceSpace {
                    return $null
                }

                { New-ConfluencePage -SpaceKey 'NOTFOUND' -Title 'Test' } | Should Throw 'not found'
            }
        }

        It 'Throws when API returns 404' {
            InModuleScope ConfluenceAPI {
                Mock Get-ConfluenceSpace {
                    [PSCustomObject]@{ Id = '999'; Key = 'TEST'; Name = 'Test Space' }
                }
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Resource not found (404)')
                }

                { New-ConfluencePage -SpaceKey 'TEST' -Title 'Test' } | Should Throw 'was not found'
            }
        }

        It 'Throws when access denied' {
            InModuleScope ConfluenceAPI {
                Mock Get-ConfluenceSpace {
                    [PSCustomObject]@{ Id = '456'; Key = 'TEST'; Name = 'Test Space' }
                }
                Mock Invoke-ConfluenceRequest {
                    throw [System.Exception]::new('Access forbidden (403)')
                }

                { New-ConfluencePage -SpaceKey 'TEST' -Title 'Test' } | Should Throw 'Access denied'
            }
        }

        It 'Throws when null response received' {
            InModuleScope ConfluenceAPI {
                Mock Get-ConfluenceSpace {
                    [PSCustomObject]@{ Id = '456'; Key = 'TEST'; Name = 'Test Space' }
                }
                Mock Invoke-ConfluenceRequest {
                    return $null
                }

                { New-ConfluencePage -SpaceKey 'TEST' -Title 'Test' } | Should Throw 'Failed to create'
            }
        }
    }

    Context 'Verbose Output' {
        It 'Logs verbose message when creating page' {
            InModuleScope ConfluenceAPI {
                Mock Get-ConfluenceSpace {
                    [PSCustomObject]@{ Id = '456'; Key = 'TEST'; Name = 'Test Space' }
                }
                Mock Invoke-ConfluenceRequest {
                    @{
                        id      = '123'
                        title   = 'Test'
                        spaceId = '456'
                        status  = 'current'
                        version = @{ number = 1 }
                    }
                }
                Mock Write-Verbose { } -Verifiable

                $result = New-ConfluencePage -SpaceKey 'TEST' -Title 'Test' -Verbose
                Assert-MockCalled Write-Verbose
            }
        }
    }
}
