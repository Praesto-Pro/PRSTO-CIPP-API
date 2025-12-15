$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'Public'
$privateDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'Private'

Describe 'New-ConfluenceClientSpace' {
    BeforeAll {
        # Define stub functions for CIPP Azure Table Storage
        function Get-CIPPTable { param($TableName) }
        function Get-CIPPAzDataTableEntity { param($Filter) }
        function Add-CIPPAzDataTableEntity { param($Entity, [switch]$Force) }

        # Define stub functions for Confluence API
        function Get-ConfluenceSpace { param($SpaceKey, $ErrorAction) }
        function New-ConfluenceSpace { param($SpaceKey, $Name, $Description) }
        function Set-ConfluencePage { param($PageId, $Body) }

        # Dot-source ADF dependencies
        . "$privateDir\New-ADFDocument.ps1"
        . "$privateDir\Add-ADFContent.ps1"
        . "$privateDir\ConvertTo-ADF.ps1"
        . "$privateDir\New-ADFHeading.ps1"
        . "$privateDir\New-ADFParagraph.ps1"

        # Dot-source mapping functions
        . "$privateDir\Get-ConfluenceTenantMapping.ps1"
        . "$privateDir\Set-ConfluenceTenantMapping.ps1"
        . "$privateDir\ConvertTo-ConfluenceClientHomepage.ps1"

        # Dot-source the function under test
        . "$publicDir\New-ConfluenceClientSpace.ps1"
    }

    Context 'Space Creation (AC1)' {
        BeforeEach {
            Mock Get-ConfluenceSpace { return $null }
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
            Mock Get-CIPPAzDataTableEntity { return $null }
            Mock New-ConfluenceSpace {
                [PSCustomObject]@{
                    Id         = 'space-123'
                    Key        = $SpaceKey
                    Name       = $Name
                    HomepageId = 'page-456'
                }
            }
            Mock Set-ConfluencePage { }
            Mock Add-CIPPAzDataTableEntity { }
        }

        It 'Creates space with correct SpaceKey' {
            $result = New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Contoso Corp' -TenantId 'abc-123'

            Assert-MockCalled New-ConfluenceSpace -Scope It -ParameterFilter {
                $SpaceKey -eq 'CONTOSO'
            }
        }

        It 'Creates space with correct Name' {
            $result = New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Contoso Corp' -TenantId 'abc-123'

            Assert-MockCalled New-ConfluenceSpace -Scope It -ParameterFilter {
                $Name -eq 'Contoso Corp'
            }
        }

        It 'Returns PSCustomObject with Id property' {
            $result = New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Contoso Corp' -TenantId 'abc-123'

            $result.Id | Should Be 'space-123'
        }

        It 'Returns PSCustomObject with SpaceKey property' {
            $result = New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Contoso Corp' -TenantId 'abc-123'

            $result.SpaceKey | Should Be 'CONTOSO'
        }

        It 'Returns PSCustomObject with Name property' {
            $result = New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Contoso Corp' -TenantId 'abc-123'

            $result.Name | Should Be 'Contoso Corp'
        }

        It 'Returns PSCustomObject with HomepageId property' {
            $result = New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Contoso Corp' -TenantId 'abc-123'

            $result.HomepageId | Should Be 'page-456'
        }

        It 'Returns PSCustomObject with TenantId property' {
            $result = New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Contoso Corp' -TenantId 'abc-123'

            $result.TenantId | Should Be 'abc-123'
        }
    }

    Context 'Homepage Structure (AC2)' {
        BeforeEach {
            Mock Get-ConfluenceSpace { return $null }
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
            Mock Get-CIPPAzDataTableEntity { return $null }
            Mock New-ConfluenceSpace {
                [PSCustomObject]@{
                    Id         = 'space-123'
                    Key        = $SpaceKey
                    Name       = $Name
                    HomepageId = 'page-456'
                }
            }
            $script:capturedBody = $null
            Mock Set-ConfluencePage {
                $script:capturedBody = $Body
            }
            Mock Add-CIPPAzDataTableEntity { }
        }

        It 'Calls Set-ConfluencePage with homepage content' {
            New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Contoso Corp' -TenantId 'abc-123'

            Assert-MockCalled Set-ConfluencePage -Scope It
        }

        It 'Updates homepage with correct PageId' {
            New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Contoso Corp' -TenantId 'abc-123'

            Assert-MockCalled Set-ConfluencePage -Scope It -ParameterFilter {
                $PageId -eq 'page-456'
            }
        }

        It 'Homepage content contains ADF format' {
            New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Contoso Corp' -TenantId 'abc-123'

            $script:capturedBody | Should Match '"type":"doc"'
        }

        It 'Homepage content includes client name' {
            New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Contoso Corp' -TenantId 'abc-123'

            $script:capturedBody | Should Match 'Contoso Corp'
        }
    }

    Context 'Tenant Mapping Storage (AC3)' {
        BeforeEach {
            Mock Get-ConfluenceSpace { return $null }
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
            Mock Get-CIPPAzDataTableEntity { return $null }
            Mock New-ConfluenceSpace {
                [PSCustomObject]@{
                    Id         = 'space-123'
                    Key        = $SpaceKey
                    Name       = $Name
                    HomepageId = 'page-456'
                }
            }
            Mock Set-ConfluencePage { }
            $script:capturedEntity = $null
            Mock Add-CIPPAzDataTableEntity {
                $script:capturedEntity = $Entity
            }
        }

        It 'Stores mapping in Azure Table' {
            New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Contoso Corp' -TenantId 'abc-123'

            Assert-MockCalled Add-CIPPAzDataTableEntity -Scope It
        }

        It 'Mapping has PartitionKey ConfluenceMapping' {
            New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Contoso Corp' -TenantId 'abc-123'

            $script:capturedEntity.PartitionKey | Should Be 'ConfluenceMapping'
        }

        It 'Mapping has RowKey equal to TenantId' {
            New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Contoso Corp' -TenantId 'abc-123'

            $script:capturedEntity.RowKey | Should Be 'abc-123'
        }

        It 'Mapping has SpaceKey property' {
            New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Contoso Corp' -TenantId 'abc-123'

            $script:capturedEntity.SpaceKey | Should Be 'CONTOSO'
        }

        It 'Mapping has SpaceName property' {
            New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Contoso Corp' -TenantId 'abc-123'

            $script:capturedEntity.SpaceName | Should Be 'Contoso Corp'
        }
    }

    Context 'WhatIf Support (AC4)' {
        BeforeEach {
            Mock Get-ConfluenceSpace { return $null }
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
            Mock Get-CIPPAzDataTableEntity { return $null }
            Mock New-ConfluenceSpace { }
            Mock Set-ConfluencePage { }
            Mock Add-CIPPAzDataTableEntity { }
        }

        It 'Does not create space with WhatIf' {
            New-ConfluenceClientSpace -SpaceKey 'TEST' -ClientName 'Test' -TenantId 'test-id' -WhatIf

            Assert-MockCalled New-ConfluenceSpace -Times 0 -Scope It
        }

        It 'Does not update homepage with WhatIf' {
            New-ConfluenceClientSpace -SpaceKey 'TEST' -ClientName 'Test' -TenantId 'test-id' -WhatIf

            Assert-MockCalled Set-ConfluencePage -Times 0 -Scope It
        }

        It 'Does not store mapping with WhatIf' {
            New-ConfluenceClientSpace -SpaceKey 'TEST' -ClientName 'Test' -TenantId 'test-id' -WhatIf

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 0 -Scope It
        }

        It 'Returns null with WhatIf' {
            $result = New-ConfluenceClientSpace -SpaceKey 'TEST' -ClientName 'Test' -TenantId 'test-id' -WhatIf

            $result | Should Be $null
        }
    }

    Context 'Verbose Logging (AC5)' {
        BeforeEach {
            Mock Get-ConfluenceSpace { return $null }
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
            Mock Get-CIPPAzDataTableEntity { return $null }
            Mock New-ConfluenceSpace {
                [PSCustomObject]@{
                    Id         = 'space-123'
                    Key        = $SpaceKey
                    Name       = $Name
                    HomepageId = 'page-456'
                }
            }
            Mock Set-ConfluencePage { }
            Mock Add-CIPPAzDataTableEntity { }
        }

        It 'Writes verbose messages when -Verbose is used' {
            $verboseOutput = New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Contoso Corp' -TenantId 'abc-123' -Verbose 4>&1

            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $verboseMessages.Count | Should BeGreaterThan 0
        }

        It 'Verbose message includes SpaceKey' {
            $verboseOutput = New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Contoso Corp' -TenantId 'abc-123' -Verbose 4>&1

            $verboseText = ($verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }) -join ' '
            $verboseText | Should Match 'CONTOSO'
        }

        It 'Verbose message includes TenantId' {
            $verboseOutput = New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Contoso Corp' -TenantId 'abc-123' -Verbose 4>&1

            $verboseText = ($verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }) -join ' '
            $verboseText | Should Match 'abc-123'
        }
    }

    Context 'SpaceKey Validation (AC6)' {
        It 'Throws error for lowercase SpaceKey' {
            { New-ConfluenceClientSpace -SpaceKey 'contoso' -ClientName 'Test' -TenantId 'test' } |
                Should Throw
        }

        It 'Throws error for SpaceKey with spaces' {
            { New-ConfluenceClientSpace -SpaceKey 'INVALID KEY' -ClientName 'Test' -TenantId 'test' } |
                Should Throw
        }

        It 'Throws error for SpaceKey starting with number' {
            { New-ConfluenceClientSpace -SpaceKey '123ABC' -ClientName 'Test' -TenantId 'test' } |
                Should Throw
        }

        It 'Throws error for SpaceKey with special characters' {
            { New-ConfluenceClientSpace -SpaceKey 'CONTOSO-TEST' -ClientName 'Test' -TenantId 'test' } |
                Should Throw
        }

        It 'Error message mentions SpaceKey requirements' {
            $errorThrown = $false
            try {
                New-ConfluenceClientSpace -SpaceKey 'invalid' -ClientName 'Test' -TenantId 'test'
            }
            catch {
                $errorThrown = $true
                $_.Exception.Message | Should Match 'SpaceKey'
                $_.Exception.Message | Should Match 'uppercase'
            }
            $errorThrown | Should Be $true
        }

        It 'Accepts valid uppercase SpaceKey' {
            Mock Get-ConfluenceSpace { return $null }
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
            Mock Get-CIPPAzDataTableEntity { return $null }
            Mock New-ConfluenceSpace {
                [PSCustomObject]@{ Id = 'space-123'; Key = $SpaceKey; Name = $Name; HomepageId = 'page-456' }
            }
            Mock Set-ConfluencePage { }
            Mock Add-CIPPAzDataTableEntity { }

            { New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Test' -TenantId 'test' } |
                Should Not Throw
        }

        It 'Accepts SpaceKey with numbers after first letter' {
            Mock Get-ConfluenceSpace { return $null }
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
            Mock Get-CIPPAzDataTableEntity { return $null }
            Mock New-ConfluenceSpace {
                [PSCustomObject]@{ Id = 'space-123'; Key = $SpaceKey; Name = $Name; HomepageId = 'page-456' }
            }
            Mock Set-ConfluencePage { }
            Mock Add-CIPPAzDataTableEntity { }

            { New-ConfluenceClientSpace -SpaceKey 'CLIENT01' -ClientName 'Test' -TenantId 'test' } |
                Should Not Throw
        }
    }

    Context 'Duplicate SpaceKey Handling (AC7)' {
        BeforeEach {
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
            Mock Get-CIPPAzDataTableEntity { return $null }
        }

        It 'Throws error when space already exists' {
            Mock Get-ConfluenceSpace {
                [PSCustomObject]@{ Id = 'existing-space'; Key = 'EXISTING'; Name = 'Existing Space' }
            }

            { New-ConfluenceClientSpace -SpaceKey 'EXISTING' -ClientName 'Test' -TenantId 'test' } |
                Should Throw
        }

        It 'Error message indicates space already exists' {
            Mock Get-ConfluenceSpace {
                [PSCustomObject]@{ Id = 'existing-space'; Key = 'EXISTING'; Name = 'Existing Space' }
            }

            $errorThrown = $false
            try {
                New-ConfluenceClientSpace -SpaceKey 'EXISTING' -ClientName 'Test' -TenantId 'test'
            }
            catch {
                $errorThrown = $true
                $_.Exception.Message | Should Match 'already exists'
            }
            $errorThrown | Should Be $true
        }

        It 'Error message suggests Get-ConfluenceSpace' {
            Mock Get-ConfluenceSpace {
                [PSCustomObject]@{ Id = 'existing-space'; Key = 'EXISTING'; Name = 'Existing Space' }
            }

            $errorThrown = $false
            try {
                New-ConfluenceClientSpace -SpaceKey 'EXISTING' -ClientName 'Test' -TenantId 'test'
            }
            catch {
                $errorThrown = $true
                $_.Exception.Message | Should Match 'Get-ConfluenceSpace'
            }
            $errorThrown | Should Be $true
        }
    }

    Context 'Duplicate TenantId Handling (AC8)' {
        BeforeEach {
            Mock Get-ConfluenceSpace { return $null }
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
        }

        It 'Throws error when tenant already has mapping' {
            Mock Get-CIPPAzDataTableEntity {
                [PSCustomObject]@{
                    RowKey    = 'existing-tenant'
                    SpaceKey  = 'EXISTINGSPACE'
                    SpaceName = 'Existing Space'
                }
            }

            { New-ConfluenceClientSpace -SpaceKey 'NEWSPACE' -ClientName 'Test' -TenantId 'existing-tenant' } |
                Should Throw
        }

        It 'Error message indicates tenant already mapped' {
            Mock Get-CIPPAzDataTableEntity {
                [PSCustomObject]@{
                    RowKey    = 'existing-tenant'
                    SpaceKey  = 'EXISTINGSPACE'
                    SpaceName = 'Existing Space'
                }
            }

            $errorThrown = $false
            try {
                New-ConfluenceClientSpace -SpaceKey 'NEWSPACE' -ClientName 'Test' -TenantId 'existing-tenant'
            }
            catch {
                $errorThrown = $true
                $_.Exception.Message | Should Match 'already mapped'
            }
            $errorThrown | Should Be $true
        }

        It 'Error message shows existing SpaceKey' {
            Mock Get-CIPPAzDataTableEntity {
                [PSCustomObject]@{
                    RowKey    = 'existing-tenant'
                    SpaceKey  = 'EXISTINGSPACE'
                    SpaceName = 'Existing Space'
                }
            }

            $errorThrown = $false
            try {
                New-ConfluenceClientSpace -SpaceKey 'NEWSPACE' -ClientName 'Test' -TenantId 'existing-tenant'
            }
            catch {
                $errorThrown = $true
                $_.Exception.Message | Should Match 'EXISTINGSPACE'
            }
            $errorThrown | Should Be $true
        }

        It 'Error message suggests Get-ConfluenceTenantMapping' {
            Mock Get-CIPPAzDataTableEntity {
                [PSCustomObject]@{
                    RowKey    = 'existing-tenant'
                    SpaceKey  = 'EXISTINGSPACE'
                    SpaceName = 'Existing Space'
                }
            }

            $errorThrown = $false
            try {
                New-ConfluenceClientSpace -SpaceKey 'NEWSPACE' -ClientName 'Test' -TenantId 'existing-tenant'
            }
            catch {
                $errorThrown = $true
                $_.Exception.Message | Should Match 'Get-ConfluenceTenantMapping'
            }
            $errorThrown | Should Be $true
        }
    }

    Context 'Optional Description Parameter (AC9)' {
        BeforeEach {
            Mock Get-ConfluenceSpace { return $null }
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
            Mock Get-CIPPAzDataTableEntity { return $null }
            $script:capturedDescription = $null
            Mock New-ConfluenceSpace {
                $script:capturedDescription = $Description
                [PSCustomObject]@{
                    Id         = 'space-123'
                    Key        = $SpaceKey
                    Name       = $Name
                    HomepageId = 'page-456'
                }
            }
            Mock Set-ConfluencePage { }
            Mock Add-CIPPAzDataTableEntity { }
        }

        It 'Passes Description to New-ConfluenceSpace when provided' {
            New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Contoso Corp' -TenantId 'abc-123' -Description 'Documentation for Contoso'

            $script:capturedDescription | Should Be 'Documentation for Contoso'
        }

        It 'Works without Description parameter' {
            { New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Contoso Corp' -TenantId 'abc-123' } |
                Should Not Throw
        }

        It 'Description is null when not provided' {
            New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Contoso Corp' -TenantId 'abc-123'

            $script:capturedDescription | Should Be $null
        }
    }

    Context 'Transactional Flow' {
        BeforeEach {
            Mock Get-ConfluenceSpace { return $null }
            Mock Get-CIPPTable { return @{ TableName = 'CippMapping' } }
            Mock Get-CIPPAzDataTableEntity { return $null }
        }

        It 'Does not store mapping if space creation fails' {
            Mock New-ConfluenceSpace { throw "Space creation failed" }
            Mock Add-CIPPAzDataTableEntity { }

            try {
                New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Contoso Corp' -TenantId 'abc-123'
            }
            catch { }

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 0 -Scope It
        }

        It 'Does not store mapping if homepage update fails' {
            Mock New-ConfluenceSpace {
                [PSCustomObject]@{ Id = 'space-123'; Key = $SpaceKey; Name = $Name; HomepageId = 'page-456' }
            }
            Mock Set-ConfluencePage { throw "Homepage update failed" }
            Mock Add-CIPPAzDataTableEntity { }

            try {
                New-ConfluenceClientSpace -SpaceKey 'CONTOSO' -ClientName 'Contoso Corp' -TenantId 'abc-123'
            }
            catch { }

            Assert-MockCalled Add-CIPPAzDataTableEntity -Times 0 -Scope It
        }
    }
}
