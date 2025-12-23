#Requires -Modules Pester

# Note: Tests written for Pester 3.4.0+ compatibility (Windows PowerShell default)

Describe 'New-ConfluenceBaseURL' {
    BeforeAll {
        # Import module once before all tests
        $ModulePath = (Get-Item "$PSScriptRoot\..\..\ConfluenceAPI.psd1").FullName
        Import-Module $ModulePath -Force
    }

    BeforeEach {
        # Clean state before each test
        Remove-ConfluenceBaseURL -ErrorAction SilentlyContinue
    }

    AfterEach {
        # Clean up after each test
        Remove-ConfluenceBaseURL -ErrorAction SilentlyContinue
    }

    Context 'Standard URL Configuration' {
        It 'Stores standard Confluence URL successfully' {
            New-ConfluenceBaseURL -BaseURL 'https://mycompany.atlassian.net/wiki'
            $result = Get-ConfluenceBaseURL
            $result | Should Be 'https://mycompany.atlassian.net/wiki'
        }

        It 'Returns confirmation message' {
            $result = New-ConfluenceBaseURL -BaseURL 'https://test.atlassian.net/wiki'
            $result | Should Be 'Confluence base URL has been stored successfully.'
        }
    }

    Context 'Service Account URL Configuration' {
        It 'Stores service account URL with cloud ID' {
            New-ConfluenceBaseURL -BaseURL 'https://api.atlassian.com/ex/confluence/abc123-def456'
            $result = Get-ConfluenceBaseURL
            $result | Should Be 'https://api.atlassian.com/ex/confluence/abc123-def456'
        }
    }

    Context 'Trailing Slash Normalization' {
        It 'Removes trailing slash from URL' {
            New-ConfluenceBaseURL -BaseURL 'https://mycompany.atlassian.net/wiki/'
            $result = Get-ConfluenceBaseURL
            $result | Should Be 'https://mycompany.atlassian.net/wiki'
        }

        It 'Removes multiple trailing slashes' {
            New-ConfluenceBaseURL -BaseURL 'https://mycompany.atlassian.net/wiki///'
            $result = Get-ConfluenceBaseURL
            $result | Should Be 'https://mycompany.atlassian.net/wiki'
        }
    }

    Context 'URL Validation' {
        It 'Rejects non-HTTPS URLs' {
            { New-ConfluenceBaseURL -BaseURL 'http://mycompany.atlassian.net/wiki' } | Should Throw
        }

        It 'Rejects invalid URL format' {
            { New-ConfluenceBaseURL -BaseURL 'not-a-valid-url' } | Should Throw
        }

        It 'Rejects empty string' {
            { New-ConfluenceBaseURL -BaseURL '' } | Should Throw
        }

        It 'Error message contains expected URL formats' {
            $errorThrown = $null
            try {
                New-ConfluenceBaseURL -BaseURL 'http://insecure.example.com'
            }
            catch {
                $errorThrown = $_.Exception.Message
            }
            $errorThrown | Should Not BeNullOrEmpty
            $errorThrown | Should Match 'atlassian.net/wiki'
            $errorThrown | Should Match 'api.atlassian.com'
        }
    }

    Context 'WhatIf Support' {
        It 'Does not store URL when WhatIf is used' {
            New-ConfluenceBaseURL -BaseURL 'https://test.atlassian.net/wiki' -WhatIf
            $result = Get-ConfluenceBaseURL
            $result | Should BeNullOrEmpty
        }

        It 'Supports ShouldProcess parameters' {
            $cmd = Get-Command New-ConfluenceBaseURL
            $cmd.Parameters.ContainsKey('WhatIf') | Should Be $true
            $cmd.Parameters.ContainsKey('Confirm') | Should Be $true
        }
    }

    Context 'Verbose Logging' {
        It 'Outputs verbose message when -Verbose is used' {
            $verboseMessages = New-ConfluenceBaseURL -BaseURL 'https://test.atlassian.net/wiki' -Verbose 4>&1
            $verboseMessages | Should Not BeNullOrEmpty
        }
    }
}
