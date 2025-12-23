$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent (Split-Path -Parent $here)
$privateDir = Join-Path $moduleRoot 'Private'

Describe 'Get-SyncErrorCategory' {
    BeforeAll {
        . "$privateDir\Get-SyncErrorCategory.ps1"
    }

    Context 'HTTP Status Code Classification' {
        It 'Returns ConnectionError for 401 Unauthorized' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Unauthorized' -HttpStatusCode 401
            $result.Category | Should Be 'ConnectionError'
            $result.TroubleshootingHint | Should Not BeNullOrEmpty
        }

        It 'Returns PermissionDenied for 403 Forbidden' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Forbidden' -HttpStatusCode 403
            $result.Category | Should Be 'PermissionDenied'
            $result.TroubleshootingHint | Should Match 'permissions'
        }

        It 'Returns NotFound for 404 Not Found' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Not found' -HttpStatusCode 404
            $result.Category | Should Be 'NotFound'
            $result.TroubleshootingHint | Should Match 'Verify space key'
        }

        It 'Returns RateLimit for 429 Too Many Requests' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Too many requests' -HttpStatusCode 429
            $result.Category | Should Be 'RateLimit'
            $result.TroubleshootingHint | Should Match 'rate limit'
        }

        It 'Returns ServerError for 500 Internal Server Error' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Internal server error' -HttpStatusCode 500
            $result.Category | Should Be 'ServerError'
            $result.TroubleshootingHint | Should Match 'Atlassian status page'
        }

        It 'Returns ServerError for 502 Bad Gateway' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Bad gateway' -HttpStatusCode 502
            $result.Category | Should Be 'ServerError'
        }

        It 'Returns ServerError for 503 Service Unavailable' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Service unavailable' -HttpStatusCode 503
            $result.Category | Should Be 'ServerError'
        }

        It 'Prioritizes HTTP status code over message pattern' {
            # Message says timeout (ConnectionError) but status is 404 (NotFound)
            $result = Get-SyncErrorCategory -ErrorMessage 'Connection timeout' -HttpStatusCode 404
            $result.Category | Should Be 'NotFound'
        }
    }

    Context 'Message Pattern Classification - ConnectionError' {
        It 'Detects timeout errors' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Connection timeout after 30 seconds'
            $result.Category | Should Be 'ConnectionError'
        }

        It 'Detects connection refused errors' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Connection refused by remote host'
            $result.Category | Should Be 'ConnectionError'
        }

        It 'Detects network errors' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Network error occurred during request'
            $result.Category | Should Be 'ConnectionError'
        }

        It 'Detects DNS errors' {
            $result = Get-SyncErrorCategory -ErrorMessage 'DNS resolution failed for host'
            $result.Category | Should Be 'ConnectionError'
        }

        It 'Detects SSL/TLS errors' {
            $result = Get-SyncErrorCategory -ErrorMessage 'SSL certificate validation failed'
            $result.Category | Should Be 'ConnectionError'
        }

        It 'Detects socket errors' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Socket exception during request'
            $result.Category | Should Be 'ConnectionError'
        }

        It 'ConnectionError hint mentions Test-ConfluenceConnection' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Connection timeout'
            $result.TroubleshootingHint | Should Match 'Test-ConfluenceConnection'
        }
    }

    Context 'Message Pattern Classification - RateLimit' {
        It 'Detects rate limit errors' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Rate limit exceeded'
            $result.Category | Should Be 'RateLimit'
        }

        It 'Detects too many requests errors' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Too many requests - please slow down'
            $result.Category | Should Be 'RateLimit'
        }

        It 'Detects throttle errors' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Request throttled by server'
            $result.Category | Should Be 'RateLimit'
        }

        It 'Detects 429 in message' {
            $result = Get-SyncErrorCategory -ErrorMessage 'HTTP 429: Slow down'
            $result.Category | Should Be 'RateLimit'
        }

        It 'RateLimit hint mentions sync configuration' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Rate limit exceeded'
            $result.TroubleshootingHint | Should Match 'Set-ConfluenceSyncConfiguration'
        }
    }

    Context 'Message Pattern Classification - NotFound' {
        It 'Detects not found errors' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Resource not found'
            $result.Category | Should Be 'NotFound'
        }

        It 'Detects 404 in message' {
            $result = Get-SyncErrorCategory -ErrorMessage '404 Not Found: Space XYZ does not exist'
            $result.Category | Should Be 'NotFound'
        }

        It 'Detects does not exist errors' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Space CONTOSO does not exist'
            $result.Category | Should Be 'NotFound'
        }

        It 'Detects no such errors' {
            $result = Get-SyncErrorCategory -ErrorMessage 'No such page in space'
            $result.Category | Should Be 'NotFound'
        }

        It 'Detects resource missing errors' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Resource missing from space'
            $result.Category | Should Be 'NotFound'
        }

        It 'NotFound hint mentions Get-ConfluenceSpace' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Not found'
            $result.TroubleshootingHint | Should Match 'Get-ConfluenceSpace'
        }
    }

    Context 'Message Pattern Classification - PermissionDenied' {
        It 'Detects permission errors' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Permission denied for operation'
            $result.Category | Should Be 'PermissionDenied'
        }

        It 'Detects forbidden errors' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Forbidden: Access not allowed'
            $result.Category | Should Be 'PermissionDenied'
        }

        It 'Detects unauthorized errors' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Unauthorized access attempt'
            $result.Category | Should Be 'PermissionDenied'
        }

        It 'Detects 403 in message' {
            $result = Get-SyncErrorCategory -ErrorMessage '403 Forbidden: Check permissions'
            $result.Category | Should Be 'PermissionDenied'
        }

        It 'Detects auth errors' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Authentication failed for user'
            $result.Category | Should Be 'PermissionDenied'
        }

        It 'Detects access denied errors' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Access denied to space'
            $result.Category | Should Be 'PermissionDenied'
        }

        It 'PermissionDenied hint mentions admin console' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Permission denied'
            $result.TroubleshootingHint | Should Match 'admin console'
        }
    }

    Context 'Message Pattern Classification - ValidationError' {
        It 'Detects invalid errors' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Invalid request format'
            $result.Category | Should Be 'ValidationError'
        }

        It 'Detects validation errors' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Validation failed for field'
            $result.Category | Should Be 'ValidationError'
        }

        It 'Detects required field errors' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Required field missing: title'
            $result.Category | Should Be 'ValidationError'
        }

        It 'Detects bad request errors' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Bad request: malformed JSON'
            $result.Category | Should Be 'ValidationError'
        }

        It 'Detects 400 in message' {
            $result = Get-SyncErrorCategory -ErrorMessage 'HTTP 400: Bad Request'
            $result.Category | Should Be 'ValidationError'
        }

        It 'Detects format errors' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Invalid format for date field'
            $result.Category | Should Be 'ValidationError'
        }

        It 'ValidationError hint mentions data source' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Validation failed'
            $result.TroubleshootingHint | Should Match 'CIPP data source'
        }
    }

    Context 'Message Pattern Classification - ServerError' {
        It 'Detects server error messages' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Server error occurred'
            $result.Category | Should Be 'ServerError'
        }

        It 'Detects internal error messages' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Internal error processing request'
            $result.Category | Should Be 'ServerError'
        }

        It 'Detects service unavailable messages' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Service unavailable, try again later'
            $result.Category | Should Be 'ServerError'
        }

        It 'Detects bad gateway messages' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Bad gateway error received'
            $result.Category | Should Be 'ServerError'
        }

        It 'Detects 5xx in message' {
            $result = Get-SyncErrorCategory -ErrorMessage 'HTTP 502: Bad Gateway'
            $result.Category | Should Be 'ServerError'
        }

        It 'ServerError hint mentions Atlassian status' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Server error'
            $result.TroubleshootingHint | Should Match 'status.atlassian.com'
        }
    }

    Context 'Unknown Classification' {
        It 'Returns Unknown for unrecognized errors' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Some completely random error xyz123'
            $result.Category | Should Be 'Unknown'
        }

        It 'Unknown has generic troubleshooting hint' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Unrecognized error'
            $result.TroubleshootingHint | Should Match 'sync logs'
        }
    }

    Context 'Return Object Structure' {
        It 'Returns PSCustomObject' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Test error'
            $result.GetType().Name | Should Be 'PSCustomObject'
        }

        It 'Contains Category property' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Test error'
            ($result.PSObject.Properties.Name -contains 'Category') | Should Be $true
        }

        It 'Contains TroubleshootingHint property' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Test error'
            ($result.PSObject.Properties.Name -contains 'TroubleshootingHint') | Should Be $true
        }

        It 'Category is never null' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Test error'
            $result.Category | Should Not BeNullOrEmpty
        }

        It 'TroubleshootingHint is never null' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Test error'
            $result.TroubleshootingHint | Should Not BeNullOrEmpty
        }
    }

    Context 'Case Insensitivity' {
        It 'Handles uppercase messages' {
            $result = Get-SyncErrorCategory -ErrorMessage 'TIMEOUT OCCURRED'
            $result.Category | Should Be 'ConnectionError'
        }

        It 'Handles mixed case messages' {
            $result = Get-SyncErrorCategory -ErrorMessage 'Connection TIMEOUT Error'
            $result.Category | Should Be 'ConnectionError'
        }
    }
}
