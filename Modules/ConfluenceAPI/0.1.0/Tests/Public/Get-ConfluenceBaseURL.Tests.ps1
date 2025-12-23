#Requires -Modules Pester

# Note: Tests written for Pester 3.4.0+ compatibility (Windows PowerShell default)

Describe 'Get-ConfluenceBaseURL' {
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

    Context 'Retrieving Stored URL' {
        It 'Returns stored URL as string' {
            New-ConfluenceBaseURL -BaseURL 'https://mycompany.atlassian.net/wiki'
            $result = Get-ConfluenceBaseURL
            $result | Should Be 'https://mycompany.atlassian.net/wiki'
        }

        It 'Returns service account URL correctly' {
            New-ConfluenceBaseURL -BaseURL 'https://api.atlassian.com/ex/confluence/abc123'
            $result = Get-ConfluenceBaseURL
            $result | Should Be 'https://api.atlassian.com/ex/confluence/abc123'
        }
    }

    Context 'No URL Stored' {
        It 'Returns null when no URL is stored' {
            $result = Get-ConfluenceBaseURL
            $result | Should BeNullOrEmpty
        }

        It 'Does not throw error when no URL exists' {
            { Get-ConfluenceBaseURL } | Should Not Throw
        }
    }

    Context 'Verbose Logging' {
        It 'Outputs verbose message when -Verbose is used' {
            New-ConfluenceBaseURL -BaseURL 'https://test.atlassian.net/wiki'
            $verboseMessages = Get-ConfluenceBaseURL -Verbose 4>&1
            $verboseMessages | Should Not BeNullOrEmpty
        }

        It 'Verbose output contains expected retrieval message' {
            New-ConfluenceBaseURL -BaseURL 'https://test.atlassian.net/wiki'
            $verboseOutput = Get-ConfluenceBaseURL -Verbose 4>&1 | Out-String
            $verboseOutput | Should Match 'Retrieving stored Confluence base URL'
        }

        It 'Verbose output shows no URL configured message when empty' {
            $verboseOutput = Get-ConfluenceBaseURL -Verbose 4>&1 | Out-String
            $verboseOutput | Should Match 'No base URL configured'
        }
    }
}
