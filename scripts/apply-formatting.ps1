<#
.SYNOPSIS
    Applies column formatting and configures the Service Desk site home page.

.PARAMETER SiteUrl
    The SharePoint Online site URL.

.PARAMETER ClientId
    Optional Entra ID App Client ID for authentication.

.EXAMPLE
    .\apply-formatting.ps1 -SiteUrl "https://contoso.sharepoint.com/sites/ServiceDesk"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SiteUrl,

    [Parameter(Mandatory = $false)]
    [string]$ClientId
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoRoot = Split-Path -Parent $ScriptDir
$FormattingDir = Join-Path $RepoRoot "column-formatting"

# Verify formatting files exist
$formattingFiles = @{
    "Status"     = Join-Path $FormattingDir "status-pill.json"
    "Priority"   = Join-Path $FormattingDir "priority-pill.json"
    "TicketID"   = Join-Path $FormattingDir "ticket-id-format.json"
    "SLADueDate" = Join-Path $FormattingDir "sla-due-format.json"
}

foreach ($entry in $formattingFiles.GetEnumerator()) {
    if (-not (Test-Path $entry.Value)) {
        throw "Formatting file not found: $($entry.Value)"
    }
}

$viewFormattingPath = Join-Path $FormattingDir "view-formatting.json"
if (-not (Test-Path $viewFormattingPath)) {
    throw "View formatting file not found: $viewFormattingPath"
}

# Connect
if (-not (Get-Module -ListAvailable -Name PnP.PowerShell)) {
    Install-Module -Name PnP.PowerShell -Scope CurrentUser -Force -AllowClobber
}
Import-Module PnP.PowerShell -ErrorAction Stop

Write-Host "`nConnecting to $SiteUrl ..." -ForegroundColor Cyan
if ($ClientId) {
    Connect-PnPOnline -Url $SiteUrl -Interactive -ClientId $ClientId
} else {
    Connect-PnPOnline -Url $SiteUrl -Interactive
}
Write-Host "Connected." -ForegroundColor Green

# =====================================================================
# 1. Apply column formatting to Tickets list
# =====================================================================
$listName = "Tickets"
Write-Host "`n=======================================" -ForegroundColor Cyan
Write-Host "  Applying column formatting: $listName" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan

foreach ($entry in $formattingFiles.GetEnumerator()) {
    $fieldName = $entry.Key
    $filePath = $entry.Value
    $json = Get-Content -Raw $filePath

    Write-Host "  Formatting column: $fieldName ..." -ForegroundColor White
    try {
        $field = Get-PnPField -List $listName -Identity $fieldName -ErrorAction Stop
        $field.CustomFormatter = $json
        $field.Update()
        Invoke-PnPQuery
        Write-Host "    Done." -ForegroundColor Green
    }
    catch {
        Write-Host "    Warning: Could not format $fieldName - $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# =====================================================================
# 2. Apply view formatting to All Tickets view
# =====================================================================
Write-Host "`n  Applying view formatting: All Tickets ..." -ForegroundColor White
try {
    $viewJson = Get-Content -Raw $viewFormattingPath
    $views = Get-PnPView -List $listName
    $defaultView = $views | Where-Object { $_.DefaultView -eq $true } | Select-Object -First 1
    if (-not $defaultView) {
        $defaultView = $views | Select-Object -First 1
    }

    $defaultView.CustomFormatter = $viewJson
    $defaultView.Update()
    Invoke-PnPQuery
    Write-Host "    Done." -ForegroundColor Green
}
catch {
    Write-Host "    Warning: Could not format view - $($_.Exception.Message)" -ForegroundColor Yellow
}

# =====================================================================
# 3. Update the home page - add Tickets list web part
# =====================================================================
Write-Host "`n=======================================" -ForegroundColor Cyan
Write-Host "  Configuring home page" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan

try {
    $ticketsList = Get-PnPList -Identity $listName
    $listId = $ticketsList.Id.ToString()
    $listUrl = $ticketsList.RootFolder.ServerRelativeUrl

    # Get the home page
    $homePage = Get-PnPHomePage
    Write-Host "  Home page: $homePage" -ForegroundColor Gray

    # Clear default web parts and add Tickets list
    $page = Get-PnPPage -Identity $homePage -ErrorAction SilentlyContinue
    if ($page) {
        Write-Host "  Removing default web parts..." -ForegroundColor White

        # Remove existing web parts
        $webparts = $page.Controls
        foreach ($wp in $webparts) {
            Remove-PnPPageComponent -Page $homePage -InstanceId $wp.InstanceId -Force
        }
        Write-Host "    Cleared $($webparts.Count) web parts." -ForegroundColor Green

        # Add the Tickets list web part
        Write-Host "  Adding Tickets list web part..." -ForegroundColor White
        Add-PnPPageWebPart -Page $homePage -DefaultWebPartType "List" -WebPartProperties @{
            "selectedListId"  = $listId
            "selectedListUrl" = $listUrl
        }
        Write-Host "    Done." -ForegroundColor Green

        # Set page to full-width layout
        Write-Host "  Setting full-width layout..." -ForegroundColor White
        Set-PnPPage -Identity $homePage -LayoutType Home
        Write-Host "    Done." -ForegroundColor Green
    }
    else {
        Write-Host "  Could not access home page for editing. You can manually add a List web part." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "  Warning: Could not update home page - $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "  You can manually edit the home page and add a List web part for Tickets." -ForegroundColor Yellow
}

# =====================================================================
# Summary
# =====================================================================
Write-Host "`n=======================================" -ForegroundColor Green
Write-Host "  Formatting Complete!" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Column formatting applied:" -ForegroundColor White
Write-Host "    - Status:     colored pill badges" -ForegroundColor Gray
Write-Host "    - Priority:   colored badges with warning icon" -ForegroundColor Gray
Write-Host "    - TicketID:   monospace code style" -ForegroundColor Gray
Write-Host "    - SLADueDate: conditional red/orange/green" -ForegroundColor Gray
Write-Host "    - View:       card-style rows with avatars" -ForegroundColor Gray
Write-Host ""
Write-Host "  Navigate to $SiteUrl to see the changes." -ForegroundColor White
Write-Host ""

Disconnect-PnPOnline
Write-Host "Disconnected." -ForegroundColor Cyan
