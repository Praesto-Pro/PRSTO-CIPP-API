Describe 'OData Filter Escaping Logic' {
    Context 'Single Quote Escaping' {
        It 'Doubles single quotes for OData filter safety' {
            $input = "CO'NTOSO"
            $result = $input -replace "'", "''"
            $result | Should Be "CO''NTOSO"
        }

        It 'Handles multiple single quotes' {
            $input = "CON'TO'SO"
            $result = $input -replace "'", "''"
            $result | Should Be "CON''TO''SO"
        }

        It 'Handles consecutive single quotes' {
            $input = "CONTOSO''"
            $result = $input -replace "'", "''"
            $result | Should Be "CONTOSO''''"
        }

        It 'Leaves strings without quotes unchanged' {
            $input = "CONTOSO"
            $result = $input -replace "'", "''"
            $result | Should Be "CONTOSO"
        }

        It 'Escapes injection attempt with quotes' {
            $input = "CON' or PartitionKey eq 'Evil"
            $result = $input -replace "'", "''"
            $result | Should Be "CON'' or PartitionKey eq ''Evil"
        }
    }

    Context 'OData Filter Construction' {
        It 'Produces safe filter string after escaping' {
            $spaceKey = "CON'TOSO"
            $escaped = $spaceKey -replace "'", "''"
            $filter = "PartitionKey eq 'ConfluenceMapping' and SpaceKey eq '$escaped'"

            $filter | Should Be "PartitionKey eq 'ConfluenceMapping' and SpaceKey eq 'CON''TOSO'"
        }

        It 'Neutralizes injection payload after escaping' {
            $malicious = "CON' or 1 eq '1"
            $escaped = $malicious -replace "'", "''"
            $filter = "PartitionKey eq 'ConfluenceMapping' and RowKey eq '$escaped'"

            # After escaping, the payload becomes a literal string search
            $filter | Should Be "PartitionKey eq 'ConfluenceMapping' and RowKey eq 'CON'' or 1 eq ''1'"

            # Verify it's searching for the literal string "CON' or 1 eq '1" (harmless)
            # NOT executing "CON' or 1 eq '1" as OData logic (dangerous)
        }
    }
}
