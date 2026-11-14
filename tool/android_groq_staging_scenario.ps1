# Full staging validation/build/launch scenario. The public run_* wrapper only
# forwards the bound command-line parameters into this implementation.
[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$')]
    [string]$DeviceId,

    [switch]$BuildOnly,

    [switch]$ValidateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($BuildOnly -and $ValidateOnly) {
    throw 'BuildOnly and ValidateOnly cannot be combined.'
}
if ($BuildOnly -and $PSBoundParameters.ContainsKey('DeviceId')) {
    throw 'DeviceId is only valid when launching the Android application.'
}

$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$stagingConfigPath = Join-Path $repositoryRoot 'config\groq_staging.json'

if (-not (Test-Path -LiteralPath $stagingConfigPath -PathType Leaf)) {
    throw 'The canonical Groq staging configuration file is missing.'
}

try {
    $stagingConfig = Get-Content -LiteralPath $stagingConfigPath -Raw |
        ConvertFrom-Json
} catch {
    throw 'The canonical Groq staging configuration is not valid JSON.'
}

$allowedKeys = @(
    'CASH_PILOT_ENVIRONMENT',
    'CASH_PILOT_AI_PROVIDER',
    'CASH_PILOT_AI_DIAGNOSTICS',
    'CASH_PILOT_AI_GROQ_GATEWAY_ENABLED',
    'CASH_PILOT_AI_GROQ_GENERAL_CHAT_ENABLED',
    'CASH_PILOT_AI_GROQ_FINANCIAL_EXPLANATION_ENABLED',
    'CASH_PILOT_AI_GROQ_TOOL_SELECTION_ENABLED',
    'CASH_PILOT_AI_GROQ_ARABIC_SPECIALIST_ENABLED',
    'CASH_PILOT_AI_CURRENT_WEB_ENABLED',
    'CASH_PILOT_AI_FIREBASE_TEXT_FALLBACK_ENABLED',
    'CASH_PILOT_AI_FIREBASE_RECEIPT_VISION_ENABLED',
    'CASH_PILOT_AI_UPDATE_DRAFTS_ENABLED',
    'CASH_PILOT_AI_ARCHIVE_DRAFTS_ENABLED',
    'CASH_PILOT_AI_GATEWAY_BASE_URL',
    'CASH_PILOT_ACCOUNT_DELETION_GATEWAY_BASE_URL',
    'CASH_PILOT_CLIENT_VERSION'
)
$actualProperties = @($stagingConfig.PSObject.Properties)
$actualKeys = @($actualProperties | ForEach-Object { $_.Name })
$missingKeys = @($allowedKeys | Where-Object { $_ -notin $actualKeys })
$unexpectedKeys = @($actualKeys | Where-Object { $_ -notin $allowedKeys })
if ($missingKeys.Count -ne 0 -or $unexpectedKeys.Count -ne 0) {
    throw 'The canonical Groq staging configuration key set is invalid.'
}
if ($actualProperties | Where-Object { $_.Value -isnot [string] }) {
    throw 'Every Groq staging configuration value must be a string.'
}

$expectedValues = @{
    CASH_PILOT_ENVIRONMENT = 'staging'
    CASH_PILOT_AI_PROVIDER = 'groq'
    CASH_PILOT_AI_DIAGNOSTICS = 'false'
    CASH_PILOT_AI_GROQ_GATEWAY_ENABLED = 'true'
    CASH_PILOT_AI_GROQ_GENERAL_CHAT_ENABLED = 'true'
    CASH_PILOT_AI_GROQ_FINANCIAL_EXPLANATION_ENABLED = 'true'
    CASH_PILOT_AI_GROQ_TOOL_SELECTION_ENABLED = 'false'
    CASH_PILOT_AI_GROQ_ARABIC_SPECIALIST_ENABLED = 'true'
    CASH_PILOT_AI_CURRENT_WEB_ENABLED = 'false'
    CASH_PILOT_AI_FIREBASE_TEXT_FALLBACK_ENABLED = 'false'
    CASH_PILOT_AI_FIREBASE_RECEIPT_VISION_ENABLED = 'true'
    CASH_PILOT_AI_UPDATE_DRAFTS_ENABLED = 'true'
    CASH_PILOT_AI_ARCHIVE_DRAFTS_ENABLED = 'true'
}
foreach ($entry in $expectedValues.GetEnumerator()) {
    if ([string]$stagingConfig.($entry.Key) -cne [string]$entry.Value) {
        throw 'The canonical Groq staging configuration has an invalid policy value.'
    }
}

$clientVersion = [string]$stagingConfig.CASH_PILOT_CLIENT_VERSION
if ($clientVersion -notmatch '^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$') {
    throw 'The Groq staging client version is invalid.'
}

$gatewayOrigin = $null
if (-not [Uri]::TryCreate(
        [string]$stagingConfig.CASH_PILOT_AI_GATEWAY_BASE_URL,
        [UriKind]::Absolute,
        [ref]$gatewayOrigin
    )) {
    throw 'The Groq staging gateway origin is invalid.'
}
if (
    $gatewayOrigin.Scheme -cne 'https' -or
    $gatewayOrigin.Port -ne 443 -or
    -not [string]::IsNullOrEmpty($gatewayOrigin.UserInfo) -or
    -not [string]::IsNullOrEmpty($gatewayOrigin.Query) -or
    -not [string]::IsNullOrEmpty($gatewayOrigin.Fragment) -or
    $gatewayOrigin.AbsolutePath -cne '/' -or
    $gatewayOrigin.Host -notmatch '^[a-z0-9-]+\.a\.run\.app$' -or
    $gatewayOrigin.Host.StartsWith('groq-candidate---')
) {
    throw 'The Groq staging gateway must be a stable HTTPS Cloud Run origin.'
}

$deletionGatewayOrigin = $null
if (-not [Uri]::TryCreate(
        [string]$stagingConfig.CASH_PILOT_ACCOUNT_DELETION_GATEWAY_BASE_URL,
        [UriKind]::Absolute,
        [ref]$deletionGatewayOrigin
    )) {
    throw 'The account-deletion staging gateway origin is invalid.'
}
if (
    $deletionGatewayOrigin.Scheme -cne 'https' -or
    $deletionGatewayOrigin.Port -ne 443 -or
    -not [string]::IsNullOrEmpty($deletionGatewayOrigin.UserInfo) -or
    -not [string]::IsNullOrEmpty($deletionGatewayOrigin.Query) -or
    -not [string]::IsNullOrEmpty($deletionGatewayOrigin.Fragment) -or
    $deletionGatewayOrigin.AbsolutePath -cne '/' -or
    $deletionGatewayOrigin.Host -notmatch '^cashpilot-account-deletion-staging-[a-z0-9-]+\.a\.run\.app$'
) {
    throw 'The account-deletion staging gateway must be its stable HTTPS Cloud Run origin.'
}
if ($deletionGatewayOrigin.Host -ceq $gatewayOrigin.Host) {
    throw 'The account-deletion and Groq staging gateways must remain separate services.'
}

Write-Output (
    'CASH_PILOT_GROQ_STAGING_CONFIG status=valid ' +
    'environment=staging provider=groq fallback=false secrets=false'
)
if ($ValidateOnly) {
    exit 0
}

$flutterCommand = Get-Command 'flutter.bat' -ErrorAction SilentlyContinue
if ($null -eq $flutterCommand) {
    $flutterCommand = Get-Command 'flutter' -ErrorAction SilentlyContinue
}
if ($null -eq $flutterCommand) {
    throw 'Flutter is unavailable on PATH.'
}

$defineArgument = "--dart-define-from-file=$stagingConfigPath"
Push-Location -LiteralPath $repositoryRoot
try {
    if ($BuildOnly) {
        Write-Output 'CASH_PILOT_GROQ_STAGING_BUILD status=starting mode=debug'
        & $flutterCommand.Source @(
            'build',
            'apk',
            '--debug',
            '--no-pub',
            $defineArgument
        )
        $flutterExitCode = $LASTEXITCODE
        if ($flutterExitCode -eq 0) {
            Write-Output (
                'CASH_PILOT_GROQ_STAGING_BUILD status=completed ' +
                'artifact=build/app/outputs/flutter-apk/app-debug.apk'
            )
        }
        exit $flutterExitCode
    }

    $resolvedDeviceId = $DeviceId
    if ([string]::IsNullOrWhiteSpace($resolvedDeviceId)) {
        try {
            $deviceJson = & $flutterCommand.Source 'devices' '--machine' 2>$null
            $devices = @($deviceJson | ConvertFrom-Json)
        } catch {
            throw 'Android device discovery failed.'
        }
        $androidDevices = @(
            $devices | Where-Object {
                $_.isSupported -eq $true -and
                [string]$_.targetPlatform -like 'android-*'
            }
        )
        if ($androidDevices.Count -ne 1) {
            throw 'Specify DeviceId when exactly one supported Android device is not available.'
        }
        $resolvedDeviceId = [string]$androidDevices[0].id
    }

    Write-Output 'CASH_PILOT_GROQ_STAGING_RUN status=starting mode=debug'
    & $flutterCommand.Source @(
        'run',
        '--debug',
        '--no-pub',
        '--no-resident',
        '-d',
        $resolvedDeviceId,
        $defineArgument
    ) *> $null
    $flutterExitCode = $LASTEXITCODE
    if ($flutterExitCode -eq 0) {
        Write-Output 'CASH_PILOT_GROQ_STAGING_RUN status=launched mode=debug'
    }
    exit $flutterExitCode
} finally {
    Pop-Location
}
