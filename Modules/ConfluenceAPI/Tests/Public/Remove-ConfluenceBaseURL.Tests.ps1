#Requires -Modules Pester

# Note: Tests written for Pester 3.4.0+ compatibility (Windows PowerShell default)

Describe 'Remove-ConfluenceBaseURL' {
    BeforeAll {
        $ModulePath = (Get-Item "$PSScriptRoot\..\..\ConfluenceAPI.psd1").FullName
        Import-Module $ModulePath -Force
    }

    BeforeEach {
        Remove-ConfluenceBaseURL -ErrorAction SilentlyContinue
    }

    AfterEach {
        Remove-ConfluenceBaseURL -ErrorAction SilentlyContinue
    }

    Context 'Removing Stored URL' {
        It 'Removes stored URL successfully' {
            New-ConfluenceBaseURL -BaseURL 'https://test.atlassian.net/wiki'
            Remove-ConfluenceBaseURL
            $result = Get-ConfluenceBaseURL
            $result | Should BeNullOrEmpty
        }

        It 'Returns confirmation message when URL is removed' {
            New-ConfluenceBaseURL -BaseURL 'https://test.atlassian.net/wiki'
            $result = Remove-ConfluenceBaseURL
            $result | Should Be 'Confluence base URL has been removed.'
        }
    }

    Context 'Idempotent Behavior' {
        It 'Does not error when called with no URL stored' {
            { Remove-ConfluenceBaseURL } | Should Not Throw
        }

        It 'Can be called multiple times without error' {
            New-ConfluenceBaseURL -BaseURL 'https://test.atlassian.net/wiki'
            Remove-ConfluenceBaseURL
            { Remove-ConfluenceBaseURL } | Should Not Throw
        }

        It 'Does not output message when no URL was stored' {
            $result = Remove-ConfluenceBaseURL
            $result | Should BeNullOrEmpty
        }
    }

    Context 'WhatIf Support' {
        It 'Does not remove URL when WhatIf is used' {
            New-ConfluenceBaseURL -BaseURL 'https://test.atlassian.net/wiki'
            Remove-ConfluenceBaseURL -WhatIf
            $result = Get-ConfluenceBaseURL
            $result | Should Be 'https://test.atlassian.net/wiki'
        }

        It 'Supports ShouldProcess parameters' {
            $cmd = Get-Command Remove-ConfluenceBaseURL
            $cmd.Parameters.ContainsKey('WhatIf') | Should Be $true
            $cmd.Parameters.ContainsKey('Confirm') | Should Be $true
        }
    }

    Context 'Verbose Logging' {
        It 'Outputs verbose message when -Verbose is used' {
            New-ConfluenceBaseURL -BaseURL 'https://test.atlassian.net/wiki'
            $verboseMessages = Remove-ConfluenceBaseURL -Verbose 4>&1
            $verboseMessages | Should Not BeNullOrEmpty
        }
    }
}
