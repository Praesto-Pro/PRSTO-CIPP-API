#Requires -Version 5.1

# Initialize module-level state cache for incremental sync (Story 8.4)
# Note: This cache is volatile - cleared on module reload or PowerShell restart
if (-not $script:SyncStateCache) {
    $script:SyncStateCache = @{}
}

# Use Join-Path for cross-platform compatibility (Azure Linux vs Windows dev)
$PublicPath = Join-Path -Path $PSScriptRoot -ChildPath 'Public'
$PrivatePath = Join-Path -Path $PSScriptRoot -ChildPath 'Private'

Write-Verbose "ConfluenceAPI: PSScriptRoot = $PSScriptRoot"
Write-Verbose "ConfluenceAPI: PublicPath = $PublicPath (exists: $(Test-Path $PublicPath))"
Write-Verbose "ConfluenceAPI: PrivatePath = $PrivatePath (exists: $(Test-Path $PrivatePath))"

# Get public and private function files using cross-platform paths
$Public = @(Get-ChildItem -Path (Join-Path $PublicPath '*.ps1') -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path (Join-Path $PrivatePath '*.ps1') -ErrorAction SilentlyContinue)

Write-Verbose "ConfluenceAPI: Found $($Public.Count) public functions, $($Private.Count) private functions"

# Dot source the files
$LoadedFunctions = [System.Collections.Generic.List[string]]::new()
foreach ($import in @($Public + $Private)) {
    try {
        Write-Verbose "Importing $($import.FullName)"
        . $import.FullName
        $LoadedFunctions.Add($import.BaseName)
    }
    catch {
        Write-Error "Failed to import function $($import.FullName): $_"
    }
}

Write-Verbose "ConfluenceAPI: Loaded functions: $($LoadedFunctions -join ', ')"

# Export public functions
Export-ModuleMember -Function $Public.BaseName
