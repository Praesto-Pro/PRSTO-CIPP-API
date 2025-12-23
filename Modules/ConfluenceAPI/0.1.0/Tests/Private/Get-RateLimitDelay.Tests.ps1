#Requires -Modules Pester

Describe 'Get-RateLimitDelay' {
    BeforeAll {
        $ModulePath = (Get-Item "$PSScriptRoot\..\..\ConfluenceAPI.psd1").FullName
        Import-Module $ModulePath -Force
    }

    Context 'Default Behavior' {
        It 'Returns default delay when no response provided' {
            InModuleScope ConfluenceAPI {
                $result = Get-RateLimitDelay -Response $null -DefaultDelay 5
                $result | Should Be 5
            }
        }

        It 'Returns specified default delay when no headers' {
            InModuleScope ConfluenceAPI {
                $result = Get-RateLimitDelay -Response $null -DefaultDelay 10
                $result | Should Be 10
            }
        }
    }

    Context 'Retry-After Header Parsing' {
        It 'Parses numeric Retry-After header' {
            InModuleScope ConfluenceAPI {
                $mockResponse = [PSCustomObject]@{
                    Headers = @{ 'Retry-After' = '15' }
                }
                $result = Get-RateLimitDelay -Response $mockResponse -DefaultDelay 5
                $result | Should Be 15
            }
        }

        It 'Falls back to default when Retry-After is not numeric' {
            InModuleScope ConfluenceAPI {
                $mockResponse = [PSCustomObject]@{
                    Headers = @{ 'Retry-After' = 'invalid' }
                }
                $result = Get-RateLimitDelay -Response $mockResponse -DefaultDelay 5
                $result | Should Be 5
            }
        }

        It 'Falls back to default when headers missing' {
            InModuleScope ConfluenceAPI {
                $mockResponse = [PSCustomObject]@{
                    Headers = @{}
                }
                $result = Get-RateLimitDelay -Response $mockResponse -DefaultDelay 5
                $result | Should Be 5
            }
        }
    }

    Context 'Output Type' {
        It 'Returns an integer' {
            InModuleScope ConfluenceAPI {
                $result = Get-RateLimitDelay -Response $null -DefaultDelay 5
                $result | Should BeOfType 'System.Int32'
            }
        }
    }
}
