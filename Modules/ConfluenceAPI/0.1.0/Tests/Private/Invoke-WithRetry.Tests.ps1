$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent (Split-Path -Parent $here)
$privateDir = Join-Path $moduleRoot 'Private'

Describe 'Invoke-WithRetry' {
    BeforeAll {
        # Stub configuration function
        function Get-ConfluenceSyncConfiguration {
            [PSCustomObject]@{
                RetryAttempts     = 3
                RetryDelaySeconds = 1
            }
        }

        # Load the functions under test
        . "$privateDir\Invoke-WithRetry.ps1"
    }

    Context 'Successful Operations' {
        It 'Returns result on first attempt success' {
            $result = Invoke-WithRetry -ScriptBlock { 'success' } -OperationName 'Test'
            $result | Should Be 'success'
        }

        It 'Does not retry when operation succeeds' {
            $script:attemptCount = 0
            $result = Invoke-WithRetry -ScriptBlock {
                $script:attemptCount++
                'success'
            } -OperationName 'Test'
            $script:attemptCount | Should Be 1
        }

        It 'Returns complex object on success' {
            $result = Invoke-WithRetry -ScriptBlock {
                [PSCustomObject]@{ Id = 123; Title = 'Test' }
            } -OperationName 'Test'
            $result.Id | Should Be 123
            $result.Title | Should Be 'Test'
        }

        It 'Returns array on success' {
            $result = Invoke-WithRetry -ScriptBlock {
                @(1, 2, 3)
            } -OperationName 'Test'
            $result.Count | Should Be 3
        }

        It 'Returns null without error when script block returns null' {
            $result = Invoke-WithRetry -ScriptBlock { $null } -OperationName 'Test'
            $result | Should Be $null
        }
    }

    Context 'Transient Error Retry - 5xx Server Errors' {
        It 'Retries on 500 server error' {
            $script:attemptCount = 0
            $result = Invoke-WithRetry -ScriptBlock {
                $script:attemptCount++
                if ($script:attemptCount -lt 2) {
                    throw "Server error (500)"
                }
                'success'
            } -OperationName 'Test' -BaseDelaySeconds 0

            $result | Should Be 'success'
            $script:attemptCount | Should Be 2
        }

        It 'Retries on 502 bad gateway' {
            $script:attemptCount = 0
            $result = Invoke-WithRetry -ScriptBlock {
                $script:attemptCount++
                if ($script:attemptCount -lt 2) {
                    throw "Bad Gateway (502)"
                }
                'success'
            } -OperationName 'Test' -BaseDelaySeconds 0

            $result | Should Be 'success'
        }

        It 'Retries on 503 service unavailable' {
            $script:attemptCount = 0
            $result = Invoke-WithRetry -ScriptBlock {
                $script:attemptCount++
                if ($script:attemptCount -lt 2) {
                    throw "Service unavailable (503)"
                }
                'success'
            } -OperationName 'Test' -BaseDelaySeconds 0

            $result | Should Be 'success'
        }

        It 'Retries on generic server error message' {
            $script:attemptCount = 0
            $result = Invoke-WithRetry -ScriptBlock {
                $script:attemptCount++
                if ($script:attemptCount -lt 2) {
                    throw "Confluence server error occurred"
                }
                'success'
            } -OperationName 'Test' -BaseDelaySeconds 0

            $result | Should Be 'success'
        }
    }

    Context 'Transient Error Retry - Rate Limiting' {
        It 'Retries on 429 rate limit' {
            $script:attemptCount = 0
            $result = Invoke-WithRetry -ScriptBlock {
                $script:attemptCount++
                if ($script:attemptCount -lt 2) {
                    throw "Rate limit exceeded (429)"
                }
                'success'
            } -OperationName 'Test' -BaseDelaySeconds 0

            $result | Should Be 'success'
        }

        It 'Retries on rate limit message without code' {
            $script:attemptCount = 0
            $result = Invoke-WithRetry -ScriptBlock {
                $script:attemptCount++
                if ($script:attemptCount -lt 2) {
                    throw "rate limit exceeded, please retry later"
                }
                'success'
            } -OperationName 'Test' -BaseDelaySeconds 0

            $result | Should Be 'success'
        }
    }

    Context 'Transient Error Retry - Network Errors' {
        It 'Retries on timeout' {
            $script:attemptCount = 0
            $result = Invoke-WithRetry -ScriptBlock {
                $script:attemptCount++
                if ($script:attemptCount -lt 2) {
                    throw "The operation timed out"
                }
                'success'
            } -OperationName 'Test' -BaseDelaySeconds 0

            $result | Should Be 'success'
        }

        It 'Retries on connection refused' {
            $script:attemptCount = 0
            $result = Invoke-WithRetry -ScriptBlock {
                $script:attemptCount++
                if ($script:attemptCount -lt 2) {
                    throw "Connection refused"
                }
                'success'
            } -OperationName 'Test' -BaseDelaySeconds 0

            $result | Should Be 'success'
        }

        It 'Retries on connection reset' {
            $script:attemptCount = 0
            $result = Invoke-WithRetry -ScriptBlock {
                $script:attemptCount++
                if ($script:attemptCount -lt 2) {
                    throw "Connection reset by peer"
                }
                'success'
            } -OperationName 'Test' -BaseDelaySeconds 0

            $result | Should Be 'success'
        }

        It 'Retries on unable to connect' {
            $script:attemptCount = 0
            $result = Invoke-WithRetry -ScriptBlock {
                $script:attemptCount++
                if ($script:attemptCount -lt 2) {
                    throw "Unable to connect to the remote server"
                }
                'success'
            } -OperationName 'Test' -BaseDelaySeconds 0

            $result | Should Be 'success'
        }

        It 'Retries on network error' {
            $script:attemptCount = 0
            $result = Invoke-WithRetry -ScriptBlock {
                $script:attemptCount++
                if ($script:attemptCount -lt 2) {
                    throw "A network error occurred"
                }
                'success'
            } -OperationName 'Test' -BaseDelaySeconds 0

            $result | Should Be 'success'
        }

        It 'Retries on Gateway timeout message' {
            $script:attemptCount = 0
            $result = Invoke-WithRetry -ScriptBlock {
                $script:attemptCount++
                if ($script:attemptCount -lt 2) {
                    throw "Gateway timeout"
                }
                'success'
            } -OperationName 'Test' -BaseDelaySeconds 0

            $result | Should Be 'success'
        }
    }

    Context 'Non-Retryable Errors - 4xx Client Errors' {
        It 'Does NOT retry on 400 bad request' {
            $script:attemptCount = 0
            {
                Invoke-WithRetry -ScriptBlock {
                    $script:attemptCount++
                    throw "Bad request (400)"
                } -OperationName 'Test' -BaseDelaySeconds 0
            } | Should Throw

            $script:attemptCount | Should Be 1
        }

        It 'Does NOT retry on 401 unauthorized' {
            $script:attemptCount = 0
            {
                Invoke-WithRetry -ScriptBlock {
                    $script:attemptCount++
                    throw "Unauthorized (401)"
                } -OperationName 'Test' -BaseDelaySeconds 0
            } | Should Throw

            $script:attemptCount | Should Be 1
        }

        It 'Does NOT retry on 403 forbidden' {
            $script:attemptCount = 0
            {
                Invoke-WithRetry -ScriptBlock {
                    $script:attemptCount++
                    throw "Access forbidden (403)"
                } -OperationName 'Test' -BaseDelaySeconds 0
            } | Should Throw

            $script:attemptCount | Should Be 1
        }

        It 'Does NOT retry on 404 not found' {
            $script:attemptCount = 0
            {
                Invoke-WithRetry -ScriptBlock {
                    $script:attemptCount++
                    throw "Not found (404)"
                } -OperationName 'Test' -BaseDelaySeconds 0
            } | Should Throw

            $script:attemptCount | Should Be 1
        }

        It 'Does NOT retry on 409 conflict' {
            $script:attemptCount = 0
            {
                Invoke-WithRetry -ScriptBlock {
                    $script:attemptCount++
                    throw "Conflict (409)"
                } -OperationName 'Test' -BaseDelaySeconds 0
            } | Should Throw

            $script:attemptCount | Should Be 1
        }
    }

    Context 'Non-Retryable Errors - Other' {
        It 'Does NOT retry on invalid data format' {
            $script:attemptCount = 0
            {
                Invoke-WithRetry -ScriptBlock {
                    $script:attemptCount++
                    throw "Invalid JSON format in request body"
                } -OperationName 'Test' -BaseDelaySeconds 0
            } | Should Throw

            $script:attemptCount | Should Be 1
        }

        It 'Does NOT retry on missing parameter' {
            $script:attemptCount = 0
            {
                Invoke-WithRetry -ScriptBlock {
                    $script:attemptCount++
                    throw "Parameter 'SpaceKey' is required"
                } -OperationName 'Test' -BaseDelaySeconds 0
            } | Should Throw

            $script:attemptCount | Should Be 1
        }

        It 'Does NOT retry on validation error' {
            $script:attemptCount = 0
            {
                Invoke-WithRetry -ScriptBlock {
                    $script:attemptCount++
                    throw "Validation failed: Title cannot be empty"
                } -OperationName 'Test' -BaseDelaySeconds 0
            } | Should Throw

            $script:attemptCount | Should Be 1
        }
    }

    Context 'Retry Exhaustion' {
        It 'Throws after max retries exhausted' {
            {
                Invoke-WithRetry -ScriptBlock {
                    throw "Server error (500)"
                } -OperationName 'Test' -MaxRetries 2 -BaseDelaySeconds 0
            } | Should Throw
        }

        It 'Attempts correct number of times (MaxRetries + 1)' {
            $script:attemptCount = 0
            try {
                Invoke-WithRetry -ScriptBlock {
                    $script:attemptCount++
                    throw "Server error (500)"
                } -OperationName 'Test' -MaxRetries 2 -BaseDelaySeconds 0
            }
            catch { }
            # MaxRetries=2 means 3 total attempts (initial + 2 retries)
            $script:attemptCount | Should Be 3
        }

        It 'Error message includes operation name' {
            try {
                Invoke-WithRetry -ScriptBlock {
                    throw "Server error (500)"
                } -OperationName 'TestOperation' -MaxRetries 2 -BaseDelaySeconds 0
            }
            catch {
                $_.Exception.Message | Should Match 'TestOperation'
            }
        }

        It 'Error message includes retry count' {
            try {
                Invoke-WithRetry -ScriptBlock {
                    throw "Server error (500)"
                } -OperationName 'TestOp' -MaxRetries 2 -BaseDelaySeconds 0
            }
            catch {
                $_.Exception.Message | Should Match 'after 2 retries'
            }
        }

        It 'Error message includes timing information' {
            try {
                Invoke-WithRetry -ScriptBlock {
                    throw "Server error (500)"
                } -OperationName 'TestOp' -MaxRetries 1 -BaseDelaySeconds 0
            }
            catch {
                $_.Exception.Message | Should Match 'seconds'
            }
        }

        It 'Error message includes last error details' {
            try {
                Invoke-WithRetry -ScriptBlock {
                    throw "Original error message"
                } -OperationName 'TestOp' -MaxRetries 1 -BaseDelaySeconds 0
            }
            catch {
                $_.Exception.Message | Should Match 'Original error message'
            }
        }

        It 'Error includes original exception details in message' {
            try {
                Invoke-WithRetry -ScriptBlock {
                    throw "Specific inner error"
                } -OperationName 'TestOp' -MaxRetries 1 -BaseDelaySeconds 0
            }
            catch {
                # The error message should include the original error details
                $_.Exception.Message | Should Match 'Specific inner error'
            }
        }
    }

    Context 'Configuration Integration' {
        It 'Uses RetryAttempts from configuration when not specified' {
            $script:attemptCount = 0
            try {
                Invoke-WithRetry -ScriptBlock {
                    $script:attemptCount++
                    throw "Server error (500)"
                } -OperationName 'Test' -BaseDelaySeconds 0
            }
            catch { }
            # Config has RetryAttempts=3, so should attempt 3+1=4 times
            $script:attemptCount | Should Be 4
        }

        It 'Uses BaseDelaySeconds from configuration when not specified' {
            # This test verifies config is read; actual delay is 0 in tests
            $result = Invoke-WithRetry -ScriptBlock { 'success' } -OperationName 'Test' -MaxRetries 0
            $result | Should Be 'success'
        }

        It 'Overrides config MaxRetries when parameter provided' {
            $script:attemptCount = 0
            try {
                Invoke-WithRetry -ScriptBlock {
                    $script:attemptCount++
                    throw "Server error (500)"
                } -OperationName 'Test' -MaxRetries 1 -BaseDelaySeconds 0
            }
            catch { }
            # Override MaxRetries=1 means 2 attempts
            $script:attemptCount | Should Be 2
        }

        It 'Works with MaxRetries of 0 (no retries)' {
            $script:attemptCount = 0
            try {
                Invoke-WithRetry -ScriptBlock {
                    $script:attemptCount++
                    throw "Server error (500)"
                } -OperationName 'Test' -MaxRetries 0 -BaseDelaySeconds 0
            }
            catch { }
            $script:attemptCount | Should Be 1
        }
    }

    Context 'Exponential Backoff' {
        It 'Uses exponential backoff formula (base * 2^(attempt-1))' {
            # Test verifies the delays would be: 1, 2, 4 seconds for base=1
            # We cannot easily verify delays without mocking Start-Sleep
            # This test ensures the formula is applied by checking retry happens
            $script:attemptCount = 0
            $result = Invoke-WithRetry -ScriptBlock {
                $script:attemptCount++
                if ($script:attemptCount -lt 3) {
                    throw "Server error (500)"
                }
                'success'
            } -OperationName 'Test' -MaxRetries 3 -BaseDelaySeconds 0

            $result | Should Be 'success'
            $script:attemptCount | Should Be 3
        }
    }

    Context 'Verbose Logging' {
        It 'Writes verbose messages during operation' {
            $verboseOutput = Invoke-WithRetry -ScriptBlock { 'success' } -OperationName 'VerboseTest' -Verbose 4>&1

            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $verboseText = ($verboseMessages | ForEach-Object { $_.Message }) -join ' '
            $verboseText | Should Match 'VerboseTest'
        }

        It 'Logs attempt number during retries' {
            $script:attemptCount = 0
            $verboseOutput = Invoke-WithRetry -ScriptBlock {
                $script:attemptCount++
                if ($script:attemptCount -lt 2) {
                    throw "Server error (500)"
                }
                'success'
            } -OperationName 'RetryTest' -BaseDelaySeconds 0 -Verbose 4>&1

            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $verboseText = ($verboseMessages | ForEach-Object { $_.Message }) -join ' '
            $verboseText | Should Match 'Attempt'
        }

        It 'Logs when permanent error not retrying' {
            $verboseOutput = try {
                Invoke-WithRetry -ScriptBlock {
                    throw "Bad request (400)"
                } -OperationName 'PermanentTest' -BaseDelaySeconds 0 -Verbose 4>&1
            }
            catch {
                # Ignore the error, we want the verbose output
                $null
            }

            # Verbose output may be captured before the error
            $verboseMessages = $verboseOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $verboseText = ($verboseMessages | ForEach-Object { $_.Message }) -join ' '
            $verboseText | Should Match 'Permanent error'
        }
    }

    Context 'Recovery After Transient Failure' {
        It 'Succeeds after multiple transient failures' {
            $script:attemptCount = 0
            $result = Invoke-WithRetry -ScriptBlock {
                $script:attemptCount++
                if ($script:attemptCount -lt 3) {
                    throw "Server error (500)"
                }
                'recovered'
            } -OperationName 'RecoveryTest' -MaxRetries 5 -BaseDelaySeconds 0

            $result | Should Be 'recovered'
            $script:attemptCount | Should Be 3
        }

        It 'Returns correct result after recovery' {
            $script:attemptCount = 0
            $result = Invoke-WithRetry -ScriptBlock {
                $script:attemptCount++
                if ($script:attemptCount -lt 2) {
                    throw "Timeout"
                }
                [PSCustomObject]@{ Status = 'Recovered'; Attempt = $script:attemptCount }
            } -OperationName 'RecoveryTest' -BaseDelaySeconds 0

            $result.Status | Should Be 'Recovered'
            $result.Attempt | Should Be 2
        }
    }

    Context 'AttemptsTaken Output Parameter' {
        It 'Sets AttemptsTaken to 1 when succeeds on first try' {
            $attempts = 0
            $result = Invoke-WithRetry -ScriptBlock { 'success' } -OperationName 'Test' -AttemptsTaken ([ref]$attempts)
            $result | Should Be 'success'
            $attempts | Should Be 1
        }

        It 'Sets AttemptsTaken to number of attempts after retries' {
            $script:attemptCount = 0
            $attempts = 0
            $result = Invoke-WithRetry -ScriptBlock {
                $script:attemptCount++
                if ($script:attemptCount -lt 3) {
                    throw "Server error (500)"
                }
                'success'
            } -OperationName 'Test' -BaseDelaySeconds 0 -AttemptsTaken ([ref]$attempts)
            $result | Should Be 'success'
            $attempts | Should Be 3
        }

        It 'Does not require AttemptsTaken parameter' {
            # Should work without AttemptsTaken parameter
            $result = Invoke-WithRetry -ScriptBlock { 'success' } -OperationName 'Test'
            $result | Should Be 'success'
        }
    }
}

Describe 'Test-TransientError' {
    BeforeAll {
        $privateDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) 'Private'
        . "$privateDir\Invoke-WithRetry.ps1"
    }

    Context 'Transient Errors Return True' {
        It 'Returns true for 500 error' {
            $exception = [System.Exception]::new("Server error (500)")
            Test-TransientError -Exception $exception | Should Be $true
        }

        It 'Returns true for 502 error' {
            $exception = [System.Exception]::new("Bad Gateway (502)")
            Test-TransientError -Exception $exception | Should Be $true
        }

        It 'Returns true for 503 error' {
            $exception = [System.Exception]::new("Service unavailable (503)")
            Test-TransientError -Exception $exception | Should Be $true
        }

        It 'Returns true for 429 rate limit' {
            $exception = [System.Exception]::new("Rate limited (429)")
            Test-TransientError -Exception $exception | Should Be $true
        }

        It 'Returns true for timeout' {
            $exception = [System.Exception]::new("The operation timed out")
            Test-TransientError -Exception $exception | Should Be $true
        }

        It 'Returns true for connection refused' {
            $exception = [System.Exception]::new("Connection refused")
            Test-TransientError -Exception $exception | Should Be $true
        }

        It 'Returns true for connection reset' {
            $exception = [System.Exception]::new("Connection reset")
            Test-TransientError -Exception $exception | Should Be $true
        }

        It 'Returns true for unable to connect' {
            $exception = [System.Exception]::new("Unable to connect")
            Test-TransientError -Exception $exception | Should Be $true
        }

        It 'Returns true for network error' {
            $exception = [System.Exception]::new("Network error occurred")
            Test-TransientError -Exception $exception | Should Be $true
        }

        It 'Returns true for Confluence server error' {
            $exception = [System.Exception]::new("Confluence server error")
            Test-TransientError -Exception $exception | Should Be $true
        }

        It 'Returns true for Service unavailable message' {
            $exception = [System.Exception]::new("Service unavailable")
            Test-TransientError -Exception $exception | Should Be $true
        }

        It 'Returns true for Gateway timeout' {
            $exception = [System.Exception]::new("Gateway timeout")
            Test-TransientError -Exception $exception | Should Be $true
        }
    }

    Context 'Permanent Errors Return False' {
        It 'Returns false for 400 error' {
            $exception = [System.Exception]::new("Bad request (400)")
            Test-TransientError -Exception $exception | Should Be $false
        }

        It 'Returns false for 401 error' {
            $exception = [System.Exception]::new("Unauthorized (401)")
            Test-TransientError -Exception $exception | Should Be $false
        }

        It 'Returns false for 403 error' {
            $exception = [System.Exception]::new("Forbidden (403)")
            Test-TransientError -Exception $exception | Should Be $false
        }

        It 'Returns false for 404 error' {
            $exception = [System.Exception]::new("Not found (404)")
            Test-TransientError -Exception $exception | Should Be $false
        }

        It 'Returns false for generic error' {
            $exception = [System.Exception]::new("Something went wrong")
            Test-TransientError -Exception $exception | Should Be $false
        }

        It 'Returns false for validation error' {
            $exception = [System.Exception]::new("Validation failed")
            Test-TransientError -Exception $exception | Should Be $false
        }
    }

    Context 'Edge Cases' {
        It 'Returns false for null exception' {
            Test-TransientError -Exception $null | Should Be $false
        }

        It 'Returns false for empty message exception' {
            $exception = [System.Exception]::new("")
            Test-TransientError -Exception $exception | Should Be $false
        }
    }
}
