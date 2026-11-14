[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$')]
    [string]$DeviceId,

    [switch]$BuildOnly,

    [switch]$ValidateOnly
)

# The scenario keeps the canonical --dart-define-from-file= launch contract.
$scenarioPath = Join-Path $PSScriptRoot 'android_groq_staging_scenario.ps1'
& $scenarioPath @PSBoundParameters
