<#
.SYNOPSIS
    Applies the Service Desk theme to a SharePoint Online site.

.DESCRIPTION
    This script applies the Service Desk branded theme to a SharePoint Online
    site using either PnP PowerShell or the SharePoint Online Management Shell.
    The theme uses the organization's brand colors for a consistent Service Desk
    experience across SharePoint pages, lists, and web parts.

.PARAMETER SiteUrl
    The URL of the SharePoint site to apply the theme to.

.PARAMETER ThemeName
    The name to register the theme as. Defaults to "Service Desk Theme".

.PARAMETER UsePnP
    Use PnP PowerShell module instead of SPO Management Shell.

.PARAMETER TenantAdminUrl
    The SharePoint Online tenant admin URL. Required when not using PnP.
    Example: https://contoso-admin.sharepoint.com

.EXAMPLE
    # Using PnP PowerShell (recommended)
    .\apply-theme.ps1 -SiteUrl "https://contoso.sharepoint.com/sites/ServiceDesk" -UsePnP

.EXAMPLE
    # Using SPO Management Shell
    .\apply-theme.ps1 -SiteUrl "https://contoso.sharepoint.com/sites/ServiceDesk" `
                       -TenantAdminUrl "https://contoso-admin.sharepoint.com"

.EXAMPLE
    # Custom theme name
    .\apply-theme.ps1 -SiteUrl "https://contoso.sharepoint.com/sites/ServiceDesk" `
                       -ThemeName "IT Service Desk" -UsePnP

.NOTES
    Prerequisites:
    - For PnP approach:    Install-Module PnP.PowerShell -Scope CurrentUser
    - For SPO approach:    Install-Module Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser
    - SharePoint Admin or Global Admin permissions are required to register tenant themes.
    - Site Collection Admin permissions are required to apply a theme to a specific site.

    Author:  SharePoint Service Desk Project
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "SharePoint site URL to apply the theme to.")]
    [ValidateNotNullOrEmpty()]
    [string]$SiteUrl,

    [Parameter(Mandatory = $false)]
    [string]$ThemeName = "Service Desk Theme",

    [Parameter(Mandatory = $false)]
    [switch]$UsePnP,

    [Parameter(Mandatory = $false, HelpMessage = "Tenant admin URL (required for SPO Management Shell approach).")]
    [string]$TenantAdminUrl
)

# ---------------------------------------------------------------------------
# Theme palette definition
# ---------------------------------------------------------------------------
$themePalette = @{
    "themePrimary"               = "#0078D4"
    "themeLighterAlt"            = "#EFF6FC"
    "themeLighter"               = "#DEECF9"
    "themeLight"                 = "#C7E0F4"
    "themeTertiary"              = "#71AFE5"
    "themeSecondary"             = "#2B88D8"
    "themeDarkAlt"               = "#106EBE"
    "themeDark"                  = "#005A9E"
    "themeDarker"                = "#004578"
    "neutralLighterAlt"          = "#FAF9F8"
    "neutralLighter"             = "#F3F2F1"
    "neutralLight"               = "#EDEBE9"
    "neutralQuaternaryAlt"       = "#E1DFDD"
    "neutralQuaternary"          = "#D2D0CE"
    "neutralTertiaryAlt"         = "#C8C6C4"
    "neutralTertiary"            = "#A19F9D"
    "neutralSecondary"           = "#605E5C"
    "neutralSecondaryAlt"        = "#8A8886"
    "neutralPrimaryAlt"          = "#3B3A39"
    "neutralPrimary"             = "#323130"
    "neutralDark"                = "#201F1E"
    "black"                      = "#000000"
    "white"                      = "#FFFFFF"
    "primaryBackground"          = "#FFFFFF"
    "primaryText"                = "#323130"
    "bodyBackground"             = "#FFFFFF"
    "bodyText"                   = "#323130"
    "disabledBackground"         = "#F3F2F1"
    "disabledText"               = "#A19F9D"
    "error"                      = "#A4262C"
    "accent"                     = "#038387"
    "headerBackground"           = "#0078D4"
    "headerBackgroundSearch"     = "#FFFFFF"
    "headerBrandText"            = "#FFFFFF"
    "headerTextIcons"            = "#FFFFFF"
    "headerSearchScope"          = "#FFFFFF"
    "suiteBarBackground"         = "#004578"
    "suiteBarText"               = "#FFFFFF"
    "suiteBarDisabledText"       = "#71AFE5"
    "searchBoxBackground"        = "#DEECF9"
    "topBarBackground"           = "#0078D4"
    "topBarText"                 = "#FFFFFF"
}

# ---------------------------------------------------------------------------
# Helper: Write-Step
# ---------------------------------------------------------------------------
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

# =========================================================================
# APPROACH 1: PnP PowerShell
# =========================================================================
function Apply-ThemeWithPnP {
    param(
        [string]$SiteUrl,
        [string]$ThemeName,
        [hashtable]$Palette
    )

    Write-Step "Checking for PnP.PowerShell module..."
    if (-not (Get-Module -ListAvailable -Name PnP.PowerShell)) {
        Write-Failure "PnP.PowerShell module is not installed."
        Write-Host "  Install it with: Install-Module PnP.PowerShell -Scope CurrentUser" -ForegroundColor Yellow
        return $false
    }

    try {
        # Connect to SharePoint Online (interactive login)
        Write-Step "Connecting to SharePoint Online at $SiteUrl..."
        Connect-PnPOnline -Url $SiteUrl -Interactive

        # Check if theme already exists and remove it for a clean apply
        Write-Step "Checking for existing theme '$ThemeName'..."
        $existingTheme = Get-PnPTenantTheme -Name $ThemeName -ErrorAction SilentlyContinue
        if ($existingTheme) {
            Write-Step "Removing existing theme '$ThemeName' to apply updated version..."
            Remove-PnPTenantTheme -Name $ThemeName
        }

        # Register the theme at the tenant level
        Write-Step "Registering theme '$ThemeName' at tenant level..."
        Add-PnPTenantTheme -Identity $ThemeName -Palette $Palette -IsInverted $false -Overwrite

        # Apply the theme to the specific site
        Write-Step "Applying theme '$ThemeName' to site $SiteUrl..."
        Set-PnPWebTheme -Theme $ThemeName

        Write-Success "Theme '$ThemeName' has been applied successfully to $SiteUrl"

        # Disconnect
        Disconnect-PnPOnline
        return $true
    }
    catch {
        Write-Failure "Error applying theme with PnP: $($_.Exception.Message)"
        Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
        return $false
    }
}

# =========================================================================
# APPROACH 2: SharePoint Online Management Shell
# =========================================================================
function Apply-ThemeWithSPO {
    param(
        [string]$SiteUrl,
        [string]$TenantAdminUrl,
        [string]$ThemeName,
        [hashtable]$Palette
    )

    Write-Step "Checking for Microsoft.Online.SharePoint.PowerShell module..."
    if (-not (Get-Module -ListAvailable -Name Microsoft.Online.SharePoint.PowerShell)) {
        Write-Failure "Microsoft.Online.SharePoint.PowerShell module is not installed."
        Write-Host "  Install it with: Install-Module Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser" -ForegroundColor Yellow
        return $false
    }

    try {
        # Connect to SharePoint Online Admin
        Write-Step "Connecting to SharePoint Online Admin at $TenantAdminUrl..."
        Connect-SPOService -Url $TenantAdminUrl

        # Check if theme already exists
        Write-Step "Checking for existing theme '$ThemeName'..."
        $existingThemes = Get-SPOTheme | Where-Object { $_.Name -eq $ThemeName }
        if ($existingThemes) {
            Write-Step "Removing existing theme '$ThemeName' to apply updated version..."
            Remove-SPOTheme -Name $ThemeName
        }

        # Register the theme
        Write-Step "Registering theme '$ThemeName' at tenant level..."
        Add-SPOTheme -Identity $ThemeName -Palette $Palette -IsInverted $false -Overwrite

        # Apply the theme to the site
        Write-Step "Applying theme to site $SiteUrl..."
        Set-SPOWebTheme -Theme $ThemeName -WebUrl $SiteUrl

        Write-Success "Theme '$ThemeName' has been applied successfully to $SiteUrl"

        # Disconnect
        Disconnect-SPOService
        return $true
    }
    catch {
        Write-Failure "Error applying theme with SPO Management Shell: $($_.Exception.Message)"
        Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
        return $false
    }
}

# =========================================================================
# Main execution
# =========================================================================
Write-Host ""
Write-Host "=========================================" -ForegroundColor White
Write-Host "  Service Desk Theme Deployment Script"    -ForegroundColor White
Write-Host "=========================================" -ForegroundColor White
Write-Host ""
Write-Host "  Site URL:   $SiteUrl" -ForegroundColor Gray
Write-Host "  Theme Name: $ThemeName" -ForegroundColor Gray
Write-Host "  Method:     $(if ($UsePnP) { 'PnP PowerShell' } else { 'SPO Management Shell' })" -ForegroundColor Gray
Write-Host ""

if ($UsePnP) {
    $result = Apply-ThemeWithPnP -SiteUrl $SiteUrl -ThemeName $ThemeName -Palette $themePalette
}
else {
    # Validate TenantAdminUrl for SPO approach
    if ([string]::IsNullOrWhiteSpace($TenantAdminUrl)) {
        Write-Failure "TenantAdminUrl is required when using SPO Management Shell."
        Write-Host "  Provide it with -TenantAdminUrl or use -UsePnP for PnP PowerShell." -ForegroundColor Yellow
        exit 1
    }
    $result = Apply-ThemeWithSPO -SiteUrl $SiteUrl -TenantAdminUrl $TenantAdminUrl -ThemeName $ThemeName -Palette $themePalette
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
Write-Host "  3. The theme is registered tenant-wide. Other site admins can" -ForegroundColor Gray
Write-Host "     select '$ThemeName' from the Change the Look panel." -ForegroundColor Gray
Write-Host "  4. To remove the theme later, run:" -ForegroundColor Gray
Write-Host "       Remove-PnPTenantTheme -Name '$ThemeName'" -ForegroundColor DarkGray
Write-Host "     or" -ForegroundColor Gray
Write-Host "       Remove-SPOTheme -Name '$ThemeName'" -ForegroundColor DarkGray
Write-Host ""
