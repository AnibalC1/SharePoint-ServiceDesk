<#
.SYNOPSIS
    Provisions the Service Desk SharePoint lists (Categories, Tickets, Agents)
    from JSON schema definitions using PnP PowerShell.

.DESCRIPTION
    This script creates three SharePoint Online lists for a Service Desk system:
      1. Categories - Ticket categories with SLA targets and default assignments
      2. Tickets    - Main ticket tracking list with lookup to Categories
      3. Agents     - Agent roster with skills and workload caps

    It reads JSON schema files from ../sharepoint-lists/, creates each list with
    all columns, content types, and views, seeds the Categories list with sample
    data, and wires up the lookup relationship between Tickets and Categories.

.PARAMETER SiteUrl
    The full URL of the SharePoint Online site where lists will be provisioned.
    Example: https://contoso.sharepoint.com/sites/ServiceDesk

.PARAMETER CredentialPath
    (Optional) Path to a saved PnP credential XML. If omitted the script will
    prompt for interactive login.

.EXAMPLE
    .\provision-lists.ps1 -SiteUrl "https://contoso.sharepoint.com/sites/ServiceDesk"

.NOTES
    Prerequisites:
      - PnP.PowerShell module (Install-Module PnP.PowerShell -Scope CurrentUser)
      - SharePoint Online site with site collection admin permissions
      - PowerShell 7.2+ recommended

    Author : Service Desk DevOps
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "SharePoint Online site URL (e.g., https://contoso.sharepoint.com/sites/ServiceDesk)")]
    [ValidateNotNullOrEmpty()]
    [string]$SiteUrl,

    [Parameter(Mandatory = $false, HelpMessage = "Entra ID App Registration Client ID for PnP PowerShell interactive login.")]
    [string]$ClientId,

    [Parameter(Mandatory = $false, HelpMessage = "Use device code login instead of interactive browser login.")]
    [switch]$DeviceLogin,

    [Parameter(Mandatory = $false, HelpMessage = "Optional path to saved PnP credential XML file")]
    [string]$CredentialPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Resolve schema file paths relative to this script
# ---------------------------------------------------------------------------
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$SchemaDir  = Join-Path (Split-Path -Parent $ScriptDir) "sharepoint-lists"

$CategoriesSchemaPath = Join-Path $SchemaDir "categories-list.json"
$TicketsSchemaPath    = Join-Path $SchemaDir "tickets-list.json"
$AgentsSchemaPath     = Join-Path $SchemaDir "agents-list.json"

foreach ($path in @($CategoriesSchemaPath, $TicketsSchemaPath, $AgentsSchemaPath)) {
    if (-not (Test-Path $path)) {
        throw "Schema file not found: $path"
    }
}

# ---------------------------------------------------------------------------
# Load schemas
# ---------------------------------------------------------------------------
Write-Host "Loading JSON schemas..." -ForegroundColor Cyan
$CategoriesSchema = Get-Content -Raw $CategoriesSchemaPath | ConvertFrom-Json
$TicketsSchema    = Get-Content -Raw $TicketsSchemaPath    | ConvertFrom-Json
$AgentsSchema     = Get-Content -Raw $AgentsSchemaPath     | ConvertFrom-Json

# ---------------------------------------------------------------------------
# Ensure PnP.PowerShell module
# ---------------------------------------------------------------------------
if (-not (Get-Module -ListAvailable -Name PnP.PowerShell)) {
    Write-Host "PnP.PowerShell module not found. Installing..." -ForegroundColor Yellow
    Install-Module -Name PnP.PowerShell -Scope CurrentUser -Force -AllowClobber
}
Import-Module PnP.PowerShell -ErrorAction Stop

# ---------------------------------------------------------------------------
# Connect to SharePoint Online
# ---------------------------------------------------------------------------
Write-Host "`nConnecting to $SiteUrl ..." -ForegroundColor Cyan
if ($CredentialPath -and (Test-Path $CredentialPath)) {
    $cred = Import-Clixml -Path $CredentialPath
    Connect-PnPOnline -Url $SiteUrl -Credentials $cred
}
elseif ($ClientId) {
    Write-Host "Using interactive login with Client ID: $ClientId" -ForegroundColor Cyan
    Connect-PnPOnline -Url $SiteUrl -Interactive -ClientId $ClientId
}
elseif ($DeviceLogin) {
    Write-Host "Using device code login..." -ForegroundColor Cyan
    Connect-PnPOnline -Url $SiteUrl -DeviceLogin
}
else {
    Write-Host "Using web login (browser-based)..." -ForegroundColor Cyan
    Connect-PnPOnline -Url $SiteUrl -WebLogin
}
Write-Host "Connected successfully." -ForegroundColor Green

# ===================================================================
# Helper functions
# ===================================================================

function Remove-ListIfExists {
    <#
    .SYNOPSIS
        Removes an existing list by title so it can be re-provisioned cleanly.
    #>
    param([string]$ListTitle)

    $existing = Get-PnPList -Identity $ListTitle -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "  Removing existing list '$ListTitle'..." -ForegroundColor Yellow
        Remove-PnPList -Identity $ListTitle -Force
    }
}

function Add-FieldToList {
    <#
    .SYNOPSIS
        Adds a single field to a SharePoint list based on a schema field definition object.
    #>
    param(
        [string]$ListTitle,
        [PSCustomObject]$FieldDef
    )

    $internalName = $FieldDef.InternalName
    $displayName  = $FieldDef.DisplayName
    $fieldType    = $FieldDef.Type
    $required     = if ($FieldDef.PSObject.Properties.Name -contains "Required") { $FieldDef.Required } else { $false }

    # Skip the built-in Title field — we just rename it if needed
    if ($internalName -eq "Title") {
        # Rename the Title field display name if it differs
        if ($displayName -ne "Title") {
            $titleField = Get-PnPField -List $ListTitle -Identity "Title"
            Set-PnPField -List $ListTitle -Identity "Title" -Values @{ Title = $displayName }
            Write-Host "    Renamed Title field to '$displayName'" -ForegroundColor DarkGray
        }
        return
    }

    # If SchemaXml is provided, use it directly for full fidelity
    if ($FieldDef.PSObject.Properties.Name -contains "SchemaXml" -and $FieldDef.SchemaXml) {
        Write-Host "    Adding field '$displayName' ($fieldType) via SchemaXml..." -ForegroundColor DarkGray
        Add-PnPFieldFromXml -List $ListTitle -FieldXml $FieldDef.SchemaXml
        return
    }

    Write-Host "    Adding field '$displayName' ($fieldType)..." -ForegroundColor DarkGray

    switch ($fieldType) {
        "Text" {
            $params = @{
                List         = $ListTitle
                DisplayName  = $displayName
                InternalName = $internalName
                Type         = "Text"
                Required     = $required
            }
            Add-PnPField @params | Out-Null

            if ($FieldDef.PSObject.Properties.Name -contains "Indexed" -and $FieldDef.Indexed) {
                $f = Get-PnPField -List $ListTitle -Identity $internalName
                $f.Indexed = $true
                $f.Update()
                Invoke-PnPQuery
            }
            if ($FieldDef.PSObject.Properties.Name -contains "EnforceUniqueValues" -and $FieldDef.EnforceUniqueValues) {
                $f = Get-PnPField -List $ListTitle -Identity $internalName
                $f.EnforceUniqueValues = $true
                $f.Update()
                Invoke-PnPQuery
            }
        }

        "Note" {
            $xml = "<Field Type='Note' DisplayName='$displayName' Required='$(if($required){'TRUE'}else{'FALSE'})'"
            if ($FieldDef.PSObject.Properties.Name -contains "RichText" -and $FieldDef.RichText) {
                $xml += " RichText='TRUE'"
                if ($FieldDef.PSObject.Properties.Name -contains "RichTextMode") {
                    $xml += " RichTextMode='$($FieldDef.RichTextMode)'"
                }
            } else {
                $xml += " RichText='FALSE'"
            }
            $numLines = if ($FieldDef.PSObject.Properties.Name -contains "NumberOfLines") { $FieldDef.NumberOfLines } else { 6 }
            $xml += " NumLines='$numLines' StaticName='$internalName' Name='$internalName' />"
            Add-PnPFieldFromXml -List $ListTitle -FieldXml $xml
        }

        "Choice" {
            $choices = $FieldDef.Choices
            $default = if ($FieldDef.PSObject.Properties.Name -contains "Default") { $FieldDef.Default } else { "" }

            $params = @{
                List         = $ListTitle
                DisplayName  = $displayName
                InternalName = $internalName
                Type         = "Choice"
                Required     = $required
                Choices      = $choices
            }
            Add-PnPField @params | Out-Null

            if ($default) {
                Set-PnPField -List $ListTitle -Identity $internalName -Values @{ DefaultValue = $default }
            }
        }

        "Lookup" {
            # Handled separately after all lists are created
        }

        "User" {
            $xml = "<Field Type='User' DisplayName='$displayName' Required='$(if($required){'TRUE'}else{'FALSE'})' UserSelectionMode='PeopleOnly' UserSelectionScope='0' StaticName='$internalName' Name='$internalName' />"
            Add-PnPFieldFromXml -List $ListTitle -FieldXml $xml
        }

        "DateTime" {
            $format = if ($FieldDef.PSObject.Properties.Name -contains "Format") { $FieldDef.Format } else { "DateOnly" }
            $xml = "<Field Type='DateTime' DisplayName='$displayName' Required='$(if($required){'TRUE'}else{'FALSE'})' Format='$format' StaticName='$internalName' Name='$internalName' />"
            Add-PnPFieldFromXml -List $ListTitle -FieldXml $xml
        }

        "Number" {
            $xml = "<Field Type='Number' DisplayName='$displayName' Required='$(if($required){'TRUE'}else{'FALSE'})'"
            if ($FieldDef.PSObject.Properties.Name -contains "Min") { $xml += " Min='$($FieldDef.Min)'" }
            if ($FieldDef.PSObject.Properties.Name -contains "Max") { $xml += " Max='$($FieldDef.Max)'" }
            if ($FieldDef.PSObject.Properties.Name -contains "Decimals") { $xml += " Decimals='$($FieldDef.Decimals)'" }
            $xml += " StaticName='$internalName' Name='$internalName'"
            $defaultVal = if ($FieldDef.PSObject.Properties.Name -contains "Default") { $FieldDef.Default } else { $null }
            if ($null -ne $defaultVal) {
                $xml += "><Default>$defaultVal</Default></Field>"
            } else {
                $xml += " />"
            }
            Add-PnPFieldFromXml -List $ListTitle -FieldXml $xml
        }

        "Boolean" {
            $defaultBool = if ($FieldDef.PSObject.Properties.Name -contains "Default" -and $FieldDef.Default -eq $true) { "1" } else { "0" }
            $xml = "<Field Type='Boolean' DisplayName='$displayName' Required='$(if($required){'TRUE'}else{'FALSE'})' StaticName='$internalName' Name='$internalName'><Default>$defaultBool</Default></Field>"
            Add-PnPFieldFromXml -List $ListTitle -FieldXml $xml
        }

        default {
            Write-Warning "    Unsupported field type '$fieldType' for field '$displayName'. Skipping."
        }
    }
}

function Add-ViewToList {
    <#
    .SYNOPSIS
        Creates a view on a list from a view definition object.
    #>
    param(
        [string]$ListTitle,
        [PSCustomObject]$ViewDef
    )

    $viewName  = $ViewDef.viewName
    $isDefault = if ($ViewDef.PSObject.Properties.Name -contains "isDefault") { $ViewDef.isDefault } else { $false }
    $rowLimit  = if ($ViewDef.PSObject.Properties.Name -contains "rowLimit") { $ViewDef.rowLimit } else { 30 }
    $paged     = if ($ViewDef.PSObject.Properties.Name -contains "paged") { $ViewDef.paged } else { $true }
    $query     = if ($ViewDef.PSObject.Properties.Name -contains "query") { $ViewDef.query } else { "" }

    # Map field names: replace "Title" with "LinkTitle" for views
    $viewFields = @()
    foreach ($f in $ViewDef.viewFields) {
        if ($f -eq "Title") {
            $viewFields += "LinkTitle"
        } else {
            $viewFields += $f
        }
    }

    Write-Host "    Creating view '$viewName'..." -ForegroundColor DarkGray

    $params = @{
        List       = $ListTitle
        Title      = $viewName
        Fields     = $viewFields
        RowLimit   = $rowLimit
        Paged      = $paged
        SetAsDefault = $isDefault
    }

    if ($query) {
        $params["Query"] = $query
    }

    Add-PnPView @params | Out-Null
}

# ===================================================================
# 1. Provision Categories list (must be first — Tickets depends on it)
# ===================================================================
Write-Host "`n=======================================" -ForegroundColor Cyan
Write-Host "  Provisioning: $($CategoriesSchema.listName)" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan

Remove-ListIfExists -ListTitle $CategoriesSchema.listName

Write-Host "  Creating list '$($CategoriesSchema.listName)'..." -ForegroundColor White
New-PnPList -Title $CategoriesSchema.listName `
            -Template GenericList `
            -EnableVersioning `
            -OnQuickLaunch | Out-Null

# Set description
Set-PnPList -Identity $CategoriesSchema.listName -Description $CategoriesSchema.listDescription

# Add fields
Write-Host "  Adding fields..." -ForegroundColor White
foreach ($fieldDef in $CategoriesSchema.fields) {
    Add-FieldToList -ListTitle $CategoriesSchema.listName -FieldDef $fieldDef
}

# Add views
Write-Host "  Creating views..." -ForegroundColor White
foreach ($viewDef in $CategoriesSchema.views) {
    Add-ViewToList -ListTitle $CategoriesSchema.listName -ViewDef $viewDef
}

# Seed sample data
if ($CategoriesSchema.PSObject.Properties.Name -contains "sampleData" -and $CategoriesSchema.sampleData.Count -gt 0) {
    Write-Host "  Seeding $($CategoriesSchema.sampleData.Count) sample categories..." -ForegroundColor White
    foreach ($item in $CategoriesSchema.sampleData) {
        $values = @{
            Title = $item.Title
        }
        if ($item.PSObject.Properties.Name -contains "Department" -and $item.Department) {
            $values["Department"] = $item.Department
        }
        if ($item.PSObject.Properties.Name -contains "CategoryDescription" -and $item.CategoryDescription) {
            $values["CategoryDescription"] = $item.CategoryDescription
        }
        if ($item.PSObject.Properties.Name -contains "IsActive") {
            $values["IsActive"] = $item.IsActive
        }
        if ($item.PSObject.Properties.Name -contains "DefaultPriority" -and $item.DefaultPriority) {
            $values["DefaultPriority"] = $item.DefaultPriority
        }
        if ($item.PSObject.Properties.Name -contains "SLAHours" -and $item.SLAHours) {
            $values["SLAHours"] = $item.SLAHours
        }

        Add-PnPListItem -List $CategoriesSchema.listName -Values $values | Out-Null
        Write-Host "    Added: $($item.Title) ($($item.Department))" -ForegroundColor DarkGray
    }
}

Write-Host "  Categories list provisioned successfully." -ForegroundColor Green

# ===================================================================
# 2. Provision Agents list
# ===================================================================
Write-Host "`n=======================================" -ForegroundColor Cyan
Write-Host "  Provisioning: $($AgentsSchema.listName)" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan

Remove-ListIfExists -ListTitle $AgentsSchema.listName

Write-Host "  Creating list '$($AgentsSchema.listName)'..." -ForegroundColor White
New-PnPList -Title $AgentsSchema.listName `
            -Template GenericList `
            -EnableVersioning `
            -OnQuickLaunch | Out-Null

Set-PnPList -Identity $AgentsSchema.listName -Description $AgentsSchema.listDescription

Write-Host "  Adding fields..." -ForegroundColor White
foreach ($fieldDef in $AgentsSchema.fields) {
    Add-FieldToList -ListTitle $AgentsSchema.listName -FieldDef $fieldDef
}

Write-Host "  Creating views..." -ForegroundColor White
foreach ($viewDef in $AgentsSchema.views) {
    Add-ViewToList -ListTitle $AgentsSchema.listName -ViewDef $viewDef
}

Write-Host "  Agents list provisioned successfully." -ForegroundColor Green

# ===================================================================
# 3. Provision Tickets list
# ===================================================================
Write-Host "`n=======================================" -ForegroundColor Cyan
Write-Host "  Provisioning: $($TicketsSchema.listName)" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan

Remove-ListIfExists -ListTitle $TicketsSchema.listName

Write-Host "  Creating list '$($TicketsSchema.listName)'..." -ForegroundColor White
New-PnPList -Title $TicketsSchema.listName `
            -Template GenericList `
            -EnableVersioning `
            -OnQuickLaunch | Out-Null

Set-PnPList -Identity $TicketsSchema.listName -Description $TicketsSchema.listDescription

# Set major version limit
$ticketList = Get-PnPList -Identity $TicketsSchema.listName
$ticketList.MajorVersionLimit = $TicketsSchema.majorVersionLimit
$ticketList.Update()
Invoke-PnPQuery

Write-Host "  Adding fields..." -ForegroundColor White
foreach ($fieldDef in $TicketsSchema.fields) {
    # Skip the Lookup field — we add it manually below
    if ($fieldDef.Type -eq "Lookup") {
        continue
    }
    Add-FieldToList -ListTitle $TicketsSchema.listName -FieldDef $fieldDef
}

# ---------------------------------------------------------------
# Set up Lookup column: Tickets.Category -> Categories.Title
# ---------------------------------------------------------------
Write-Host "  Configuring lookup column: Category -> Categories list..." -ForegroundColor White

$categoriesList = Get-PnPList -Identity $CategoriesSchema.listName
$categoriesListId = $categoriesList.Id.ToString()

$lookupFieldDef = $TicketsSchema.fields | Where-Object { $_.Type -eq "Lookup" } | Select-Object -First 1

if ($lookupFieldDef) {
    $lookupXml = "<Field Type='Lookup' DisplayName='$($lookupFieldDef.DisplayName)' " +
                 "Required='$(if($lookupFieldDef.Required){'TRUE'}else{'FALSE'})' " +
                 "List='{$categoriesListId}' " +
                 "ShowField='Title' " +
                 "StaticName='$($lookupFieldDef.InternalName)' " +
                 "Name='$($lookupFieldDef.InternalName)' " +
                 "Description='$($lookupFieldDef.Description)' />"

    Add-PnPFieldFromXml -List $TicketsSchema.listName -FieldXml $lookupXml
    Write-Host "    Lookup field 'Category' created and linked to Categories list (ID: $categoriesListId)" -ForegroundColor DarkGray
}

# Add views
Write-Host "  Creating views..." -ForegroundColor White
foreach ($viewDef in $TicketsSchema.views) {
    Add-ViewToList -ListTitle $TicketsSchema.listName -ViewDef $viewDef
}

Write-Host "  Tickets list provisioned successfully." -ForegroundColor Green

# ===================================================================
# 4. Set version limits on Categories and Agents lists
# ===================================================================
Write-Host "`nApplying version limits..." -ForegroundColor White

$catList = Get-PnPList -Identity $CategoriesSchema.listName
$catList.MajorVersionLimit = $CategoriesSchema.majorVersionLimit
$catList.Update()

$agentList = Get-PnPList -Identity $AgentsSchema.listName
$agentList.MajorVersionLimit = $AgentsSchema.majorVersionLimit
$agentList.Update()

Invoke-PnPQuery

# ===================================================================
# Summary
# ===================================================================
Write-Host "`n=======================================" -ForegroundColor Green
Write-Host "  Provisioning Complete!" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Lists created:" -ForegroundColor White
Write-Host "    - $($CategoriesSchema.listName): $($CategoriesSchema.fields.Count) fields, $($CategoriesSchema.views.Count) views, $($CategoriesSchema.sampleData.Count) sample items" -ForegroundColor Gray
Write-Host "    - $($AgentsSchema.listName): $($AgentsSchema.fields.Count) fields, $($AgentsSchema.views.Count) views" -ForegroundColor Gray
Write-Host "    - $($TicketsSchema.listName): $($TicketsSchema.fields.Count) fields, $($TicketsSchema.views.Count) views" -ForegroundColor Gray
Write-Host ""
Write-Host "  Lookup relationship:" -ForegroundColor White
Write-Host "    Tickets.Category -> Categories.Title (List ID: $categoriesListId)" -ForegroundColor Gray
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
Write-Host "    1. Configure Power Automate flow for auto-generating TicketID values" -ForegroundColor Gray
Write-Host "    2. Set up column formatting (see ../column-formatting/)" -ForegroundColor Gray
Write-Host "    3. Configure permissions for agents and requesters" -ForegroundColor Gray
Write-Host "    4. Deploy the Power Apps front-end (see ../power-apps/)" -ForegroundColor Gray
Write-Host ""

# Disconnect
Disconnect-PnPOnline
Write-Host "Disconnected from SharePoint Online." -ForegroundColor Cyan
