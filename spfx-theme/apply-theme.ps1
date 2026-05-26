<#
.SYNOPSIS
    Applies the Service Desk theme to a SharePoint Online site.

.DESCRIPTION
    This script applies the Service Desk branded theme to a SharePoint Online
    site using either PnP PowerShell or the SharePoint Online Management Shell.

.PARAMETER SiteUrl
    The URL of the SharePoint site to apply the theme to.

.PARAMETER ThemeName
    The name to register the theme as. Defaults to "Service Desk Theme".

.PARAMETER UsePnP
    Use PnP PowerShell module instead of SPO Management Shell.

.PARAMETER ClientId
    Entra ID App Registration Client ID. If provided, uses interactive login.

.PARAMETER TenantAdminUrl
    The SharePoint Online tenant admin URL. Required when not using PnP.

.EXAMPLE
    .\apply-theme.ps1 -SiteUrl "https://contoso.sharepoint.com/sites/ServiceDesk" -UsePnP

.EXAMPLE
    .\apply-theme.ps1 -SiteUrl "https://contoso.sharepoint.com/sites/ServiceDesk" -UsePnP -ClientId "your-client-id"

.NOTES
    Prerequisites:
    - PnP approach:  Install-Module PnP.PowerShell -Scope CurrentUser
    - SPO approach:  Install-Module Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser
    - SharePoint Admin or Global Admin permissions required.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SiteUrl,

    [Parameter(Mandatory = $false)]
    [string]$ThemeName = "Service Desk Theme",

    [Parameter(Mandatory = $false)]
    [switch]$UsePnP,

    [Parameter(Mandatory = $false)]
    [string]$ClientId,

    [Parameter(Mandatory = $false)]
    [string]$TenantAdminUrl
)

$themePalette = @{
    "themePrimary"           = "#0078D4"
    "themeLighterAlt"        = "#EFF6FC"
    "themeLighter"           = "#DEECF9"
    "themeLight"             = "#C7E0F4"
    "themeTertiary"          = "#71AFE5"
    "themeSecondary"         = "#2B88D8"
    "themeDarkAlt"           = "#106EBE"
    "themeDark"              = "#005A9E"
    "themeDarker"            = "#004578"
    "neutralLighterAlt"      = "#FAF9F8"
    "neutralLighter"         = "#F3F2F1"
    "neutralLight"           = "#EDEBE9"
    "neutralQuaternaryAlt"   = "#E1DFDD"
    "neutralQuaternary"      = "#D2D0CE"
    "neutralTertiaryAlt"     = "#C8C6C4"
    "neutralTertiary"        = "#A19F9D"
    "neutralSecondary"       = "#605E5C"
    "neutralSecondaryAlt"    = "#8A8886"
    "neutralPrimaryAlt"      = "#3B3A39"
    "neutralPrimary"         = "#323130"
    "neutralDark"            = "#201F1E"
    "black"                  = "#000000"
    "white"                  = "#FFFFFF"
    "primaryBackground"      = "#FFFFFF"
    "primaryText"            = "#323130"
    "bodyBackground"         = "#FFFFFF"
    "bodyText"               = "#323130"
    "disabledBackground"     = "#F3F2F1"
    "disabledText"           = "#A19F9D"
    "error"                  = "#A4262C"
    "accent"                 = "#038387"
    "headerBackground"       = "#0078D4"
    "headerBackgroundSearch" = "#FFFFFF"
    "headerBrandText"        = "#FFFFFF"
    "headerTextIcons"        = "#FFFFFF"
    "headerSearchScope"      = "#FFFFFF"
    "suiteBarBackground"     = "#004578"
    "suiteBarText"           = "#FFFFFF"
    "suiteBarDisabledText"   = "#71AFE5"
    "searchBoxBackground"    = "#DEECF9"
    "topBarBackground"       = "#0078D4"
    "topBarText"             = "#FFFFFF"
}

function Write-Step {
    param([string]$Message)
    Write-Host "[*] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[+] $Message" -ForegroundColor Green
}

function Write-Failure {
    param([string]$Message)
    Write-Host "[-] $Message" -ForegroundColor Red
}

function Apply-ThemeWithPnP {
    param(
        [string]$url,
        [string]$name,
        [hashtable]$palette
    )

    Write-Step "Checking for PnP.PowerShell module..."
    if (-not (Get-Module -ListAvailable -Name PnP.PowerShell)) {
        Write-Failure "PnP.PowerShell module is not installed."
        Write-Host "  Install it with: Install-Module PnP.PowerShell -Scope CurrentUser" -ForegroundColor Yellow
        return $false
    }

    try {
        Write-Step "Connecting to SharePoint Online at $url..."
        if ($ClientId) {
            Connect-PnPOnline -Url $url -Interactive -ClientId $ClientId
        }
        else {
            Connect-PnPOnline -Url $url -Interactive
        }

        Write-Step "Checking for existing theme..."
        $existingTheme = Get-PnPTenantTheme -Name $name -ErrorAction SilentlyContinue
        if ($existingTheme) {
            Write-Step "Removing existing theme to apply updated version..."
            Remove-PnPTenantTheme -Name $name
        }

        Write-Step "Registering theme at tenant level..."
        Add-PnPTenantTheme -Identity $name -Palette $palette -IsInverted $false -Overwrite

        Write-Step "Applying theme to site..."
        Set-PnPWebTheme -Theme $name

        Write-Success "Theme has been applied successfully to $url"

        Disconnect-PnPOnline
        return $true
    }
    catch {
        Write-Failure ("Error applying theme with PnP: " + $_.Exception.Message)
        Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
        return $false
    }
}

function Apply-ThemeWithSPO {
    param(
        [string]$url,
        [string]$adminUrl,
        [string]$name,
        [hashtable]$palette
    )

    Write-Step "Checking for Microsoft.Online.SharePoint.PowerShell module..."
    if (-not (Get-Module -ListAvailable -Name Microsoft.Online.SharePoint.PowerShell)) {
        Write-Failure "Microsoft.Online.SharePoint.PowerShell module is not installed."
        Write-Host "  Install it with: Install-Module Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser" -ForegroundColor Yellow
        return $false
    }

    try {
        Write-Step "Connecting to SharePoint Online Admin at $adminUrl..."
        Connect-SPOService -Url $adminUrl

        Write-Step "Checking for existing theme..."
        $existingThemes = Get-SPOTheme | Where-Object { $_.Name -eq $name }
        if ($existingThemes) {
            Write-Step "Removing existing theme to apply updated version..."
            Remove-SPOTheme -Name $name
        }

        Write-Step "Registering theme at tenant level..."
        Add-SPOTheme -Identity $name -Palette $palette -IsInverted $false -Overwrite

        Write-Step "Applying theme to site $url..."
        Set-SPOWebTheme -Theme $name -WebUrl $url

        Write-Success "Theme has been applied successfully to $url"

        Disconnect-SPOService
        return $true
    }
    catch {
        Write-Failure ("Error applying theme with SPO: " + $_.Exception.Message)
        Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
        return $false
    }
}

# Main execution
Write-Host ""
Write-Host "=========================================" -ForegroundColor White
Write-Host "  Service Desk Theme Deployment Script"    -ForegroundColor White
Write-Host "=========================================" -ForegroundColor White
Write-Host ""
Write-Host "  Site URL:   $SiteUrl" -ForegroundColor Gray
Write-Host "  Theme Name: $ThemeName" -ForegroundColor Gray

$methodLabel = "SPO Management Shell"
if ($UsePnP) { $methodLabel = "PnP PowerShell" }
Write-Host "  Method:     $methodLabel" -ForegroundColor Gray
Write-Host ""

if ($UsePnP) {
    $result = Apply-ThemeWithPnP -url $SiteUrl -name $ThemeName -palette $themePalette
}
else {
    if ([string]::IsNullOrWhiteSpace($TenantAdminUrl)) {
        Write-Failure "TenantAdminUrl is required when using SPO Management Shell."
        Write-Host "  Provide it with -TenantAdminUrl or use -UsePnP for PnP PowerShell." -ForegroundColor Yellow
        exit 1
    }
    $result = Apply-ThemeWithSPO -url $SiteUrl -adminUrl $TenantAdminUrl -name $ThemeName -palette $themePalette
}

if (-not $result) {
    Write-Host ""
    Write-Failure "Theme deployment failed. See errors above."
    exit 1
}

Write-Host ""
Write-Host "-----------------------------------------" -ForegroundColor White
Write-Host "  Post-deployment notes:" -ForegroundColor White
Write-Host "-----------------------------------------" -ForegroundColor White
Write-Host ""
Write-Host "  1. Navigate to $SiteUrl and verify the theme is applied." -ForegroundColor Gray
Write-Host "  2. Clear browser cache if you do not see changes immediately." -ForegroundColor Gray
Write-Host "  3. The theme is registered tenant-wide." -ForegroundColor Gray
Write-Host "  4. To remove later: Remove-PnPTenantTheme -Name $ThemeName" -ForegroundColor DarkGray
Write-Host ""
