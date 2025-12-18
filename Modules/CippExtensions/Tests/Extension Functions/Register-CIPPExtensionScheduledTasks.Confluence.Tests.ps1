$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = 'Register-CIPPExtensionScheduledTasks.ps1'

# Get path to function file - Tests/Extension Functions -> parent is Tests -> parent is CippExtensions
$moduleRoot = Split-Path (Split-Path $here -Parent) -Parent
$functionPath = Join-Path $moduleRoot (Join-Path 'Public' (Join-Path 'Extension Functions' $sut))

Describe 'Register-CIPPExtensionScheduledTasks - Confluence Integration' {
    Context 'AC1: Default Extensions List' {
        It 'Includes Confluence in default extensions parameter' {
            # Get actual default from function definition
            $functionDef = Get-Content $functionPath -Raw
            $functionDef | Should Match "'Confluence'"
        }

        It 'Confluence appears alongside Hudu, NinjaOne, and CustomData' {
            $functionDef = Get-Content $functionPath -Raw
            $functionDef | Should Match "@\('Hudu',\s*'NinjaOne',\s*'CustomData',\s*'Confluence'\)"
        }

        It 'Extensions parameter is a string array with 4 elements' {
            $functionDef = Get-Content $functionPath -Raw
            $extensionMatch = [regex]::Match($functionDef, "\[string\[\]\]\`$Extensions\s*=\s*@\(([^)]+)\)")
            $extensionMatch.Success | Should Be $true
            $extensionList = $extensionMatch.Groups[1].Value
            # Count elements by counting the quoted strings
            $elementCount = ([regex]::Matches($extensionList, "'[^']+'")).Count
            $elementCount | Should Be 4
        }
    }

    Context 'AC2-AC3: Task Creation Code Structure' {
        It 'Creates Push-CippExtensionData tasks for extensions' {
            $functionDef = Get-Content $functionPath -Raw
            $functionDef | Should Match "Command\s*=\s*@\{\s*value\s*=\s*'Push-CippExtensionData'"
        }

        It 'Sets task Recurrence to 1d' {
            $functionDef = Get-Content $functionPath -Raw
            $functionDef | Should Match "Recurrence\s*=\s*'1d'"
        }

        It 'Uses NextSync parameter for ScheduledTime' {
            $functionDef = Get-Content $functionPath -Raw
            $functionDef | Should Match "ScheduledTime\s*=\s*\`$NextSync"
        }

        It 'Creates hidden tasks' {
            $functionDef = Get-Content $functionPath -Raw
            $functionDef | Should Match "Add-CIPPScheduledTask.*-hidden\s*\`$true"
        }

        It 'Sets SyncType to Extension name' {
            $functionDef = Get-Content $functionPath -Raw
            $functionDef | Should Match "Add-CIPPScheduledTask.*-SyncType\s*\`$Extension"
        }

        It 'Sets task Name to Extension Extension Sync format' {
            $functionDef = Get-Content $functionPath -Raw
            $functionDef | Should Match "Name\s*=\s*`"\`$Extension Extension Sync`""
        }

        It 'Uses Extension Mapping table with correct PartitionKey pattern' {
            $functionDef = Get-Content $functionPath -Raw
            # The pattern should query CippMapping with PartitionKey eq '$($Extension)Mapping'
            $functionDef | Should Match "PartitionKey eq '\`$\(\`$Extension\)Mapping'"
        }
    }

    Context 'AC4: Disabled Extension Cleanup Logic' {
        It 'Has cleanup logic for disabled extensions' {
            $functionDef = Get-Content $functionPath -Raw
            $functionDef | Should Match "Extension Disabled.*Cleaning up"
        }

        It 'Uses Remove-AzDataTableEntity for cleanup' {
            $functionDef = Get-Content $functionPath -Raw
            $functionDef | Should Match "Remove-AzDataTableEntity"
        }

        It 'Filters tasks by SyncType for cleanup' {
            $functionDef = Get-Content $functionPath -Raw
            $functionDef | Should Match "\`$PushTasks.*Where-Object.*SyncType\s*-eq\s*\`$Extension"
        }
    }

    Context 'AC5: Removed Tenant Cleanup Logic' {
        It 'Has cleanup logic for removed tenant mappings' {
            $functionDef = Get-Content $functionPath -Raw
            $functionDef | Should Match "Tenant Removed.*Cleaning up"
        }

        It 'Checks if tenant is in mapped tenants list' {
            $functionDef = Get-Content $functionPath -Raw
            $functionDef | Should Match "Tenant\s*-notin\s*\`$MappedTenants"
        }
    }

    Context 'AC6: Idempotent Registration Logic' {
        It 'Checks for existing push task before creating' {
            $functionDef = Get-Content $functionPath -Raw
            $functionDef | Should Match "\`$ExistingPushTask\s*="
        }

        It 'Only creates task if not existing' {
            $functionDef = Get-Content $functionPath -Raw
            $functionDef | Should Match "if\s*\(\(!\`$ExistingPushTask"
        }
    }

    Context 'AC7: Reschedule Support Logic' {
        It 'Has Reschedule switch parameter' {
            $functionDef = Get-Content $functionPath -Raw
            $functionDef | Should Match "\[switch\]\`$Reschedule"
        }

        It 'Checks Reschedule switch in task creation condition' {
            $functionDef = Get-Content $functionPath -Raw
            $functionDef | Should Match "\`$Reschedule\.IsPresent"
        }

        It 'Preserves existing RowKey when rescheduling' {
            $functionDef = Get-Content $functionPath -Raw
            $functionDef | Should Match "Add-Member.*RowKey.*\`$ExistingPushTask\.RowKey"
        }
    }

    Context 'Confluence Not Excluded Like NinjaOne' {
        It 'NinjaOne has special exclusion that Confluence does not have' {
            $functionDef = Get-Content $functionPath -Raw
            # NinjaOne is explicitly excluded from Push task creation
            $functionDef | Should Match "\`$Extension\s*-ne\s*'NinjaOne'"
        }

        It 'Confluence is NOT in the exclusion list' {
            $functionDef = Get-Content $functionPath -Raw
            # There should be no special exclusion for Confluence
            $functionDef | Should Not Match "\`$Extension\s*-ne\s*'Confluence'"
        }
    }
}
