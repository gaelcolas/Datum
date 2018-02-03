function Merge-Datum {
    [CmdletBinding()]
    param (
        [string]
        $StartingPath,

        $ReferenceDatum,

        $DifferenceDatum,

        $Strategies = @{
            '^.*' = 'MostSpecific'
        }
    )

    Write-verbose "Merge-Datum -StartingPath <$StartingPath>"
    $Strategy = Get-MergeStrategyFromPath -Strategies $strategies -PropertyPath $startingPath -Verbose

    Write-Debug "---------------------------- $($Strategy | COnvertto-Json)"

    $ReferenceDatumType  = Get-DatumType -DatumObject $ReferenceDatum
    $DifferenceDatumType = Get-DatumType -DatumObject $DifferenceDatum


    if($Strategy -is [string]) {
        $Strategy = Get-MergeStrategyFromString -MergeStrategy $Strategy
    }
    
    switch ($ReferenceDatumType) {
        'BaseType' {
            return $ReferenceDatum
        }

        'hashtable' {
            $mergeParams = @{
                ReferenceHashtable  = $ReferenceDatum
                DifferenceHashtable = $DifferenceDatum
                Strategy = $Strategy
                ParentPath = $StartingPath
                ChildStrategies = $Strategies
            }
            
            if($ReferenceDatumType -ne $DifferenceDatumType) {
                Write-Warning "Cannot merge different types REF:[$ReferenceDatumType] | DIFF:[$DifferenceDatumType]$($DifferenceDatum.GetType()) , returning most specific Datum."
                return $ReferenceDatum
            }
            elseif($Strategy.merge_hash -match '^MostSpecific$|^First') {
                return $ReferenceDatum
            }
            else {
                Merge-Hashtable @mergeParams
            }
        }

        'baseType_array' {
            # Fixing issue when single item yaml array becomes String.
            if($DifferenceDatumType -ne 'baseType_array') {$DifferenceDatum = @($DifferenceDatum)}
            
            switch -Regex ($Strategy.merge_baseType_array) {
                '^MostSpecific$|^First' { return $ReferenceDatum }

                '^Unique'   {
                    if($regexPattern = $Strategy.merge_options.knockout_prefix) {
                        $regexPattern = $regexPattern.insert(0,'^')
                        ($ReferenceDatum + $DifferenceDatum).Where{$_ -notmatch $regexPattern} | Select-object -Unique
                    }
                    else {
                        ($ReferenceDatum + $DifferenceDatum)| Select-object -Unique
                    }
                    
                }

                '^Sum|^Add' {
                    #--> $ref + $diff -$kop
                    if($regexPattern = $Strategy.merge_options.knockout_prefix) {
                        $regexPattern = $regexPattern.insert(0,'^')
                        ($ReferenceDatum + $DifferenceDatum).Where{$_ -notmatch $regexPattern}
                    }
                    else {
                        ($ReferenceDatum + $DifferenceDatum)
                    }
                }

                Default { return $ReferenceDatum }
            }
        }

        'hash_array' {
            if($DifferenceDatumType -ne 'hash_array') {$DifferenceDatum = @($DifferenceDatum)}
            
            $MergeDatumArrayParams = @{
                ReferenceArray = $ReferenceDatum
                DifferenceArray = $DifferenceDatum
                Strategy = $Strategy
                ChildStrategies = $Strategies
                StartingPath = $StartingPath
            }
            
            switch -Regex ($Strategy.merge_hash_array) {
                '^MostSpecific|^First' { return $ReferenceDatum }

                '^UniqueKeyValTuples'  {
                    #--> $ref + $diff | ? % key in TupleKeys -> $ref[Key] -eq $diff[key] is not already int output
                    Merge-DatumArray @MergeDatumArrayParams
                }

                '^DeepTuple|^DeepItemMergeByTuples' {
                    #--> $ref + $diff | ? % key in TupleKeys -> $ref[Key] -eq $diff[key] is merged up
                    Merge-DatumArray @MergeDatumArrayParams
                }

                '^Sum' {
                    #--> $ref + $diff
                    (@($DifferenceArray) + @($ReferenceArray)).Foreach{
                        $null = $MergedArray.add(([ordered]@{}+$_))
                    }
                }

                Default { return $ReferenceDatum }
            }
        }
    }
}