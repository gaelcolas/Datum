function Global:Resolve-NodeProperty {
    [CmdletBinding()]
    Param(
        $Node,
        $PropertyPath,
        $DefaultValue,
        $SearchPaths = $ExecutionContext.InvokeCommand.InvokeScript('$yml.ResolutionPrecedence'),
        $DatumStructure = $ExecutionContext.InvokeCommand.InvokeScript('$ConfigurationData.Datum')
    )
    $NullAllowed = $false
    if(-not ($here = $MyInvocation.PSScriptRoot)) {
        $here = $Pwd.Path
    }
    if($result = Resolve-Datum -PropertyPath $PropertyPath -Node $Node -SearchPaths $SearchPaths -DatumStructure $DatumStructure) {
        Write-Verbose "Result found for $PropertyPath"
    }
    elseif($DefaultValue) {
        $result = $DefaultValue
        Write-Debug "Default Found"
    }
    elseif($PSBoundParameters.ContainsKey('DefaultValue') -and $null -eq $DefaultValue) {
        $result = $null
        $NullAllowed = $true
        Write-Debug "Default NULL found"
    }
    else { #This is when the Lookup is initiated from a Composite Resource, for itself
        Write-Debug "Attempting to load datum from $($here)."
        
        Push-Location $here
        $ResourceConfigDataPath = (Join-Path $here 'ConfigData')
        if(Test-Path $ResourceConfigDataPath) {
            $DatumDefinitionFile = Join-Path $ResourceConfigDataPath 'Datum.yml'
            if(Test-Path $DatumDefinitionFile) {
                Write-Debug "Datum File Path: $DatumDefinitionFile"
                $DatumDefinition = Get-FileProviderData -Path $DatumDefinitionFile
                Write-Debug "Datum Definition: $($DatumDefinition | Convertto-Json)"
                $ResourceDatum = New-DatumStructure $DatumDefinition 
            }
            elseif((Test-Path ([io.path]::combine($here,'ConfigData','common')))) { #Loading Default Datum structure
                Write-Debug "Loading common data store from $($here)\ConfigData."
                $DatumDefinition = @{
                    DatumStructure = @{
                        StoreName = "common"
                        StoreProvider = "Datum::File"
                        StoreOptions = @{
                            DataDir = "./ConfigData/Common"
                        }
                    }
                    ResolutionPrecedence = @(
                        'common'
                    )
                }
            }
            else {
                Write-Debug "No common Datum Store found in $here\ConfigData. Skipping"
            }

            if($DatumDefinition) {
                Write-Verbose "Loading Datum Definition"
                $ResourceDatum = New-DatumStructure $DatumDefinition
                $result = Resolve-Datum -PropertyPath $PropertyPath -Node $Node -searchPaths $DatumDefinition.ResolutionPrecedence -DatumStructure $ResourceDatum
            }
        }
        else {
            Write-Warning "No Datum store found"
            break
        }
        Pop-Location
    }

    if($result -or $NullAllowed) {
        $result
    }
    else {
        throw "The lookup returned a Null value, but Null is not specified as Default. This is not allowed."
    }
}
Set-Alias -Name Lookup -Value Resolve-NodeProperty -scope Global