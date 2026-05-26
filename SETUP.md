# Setup Guide

Step-by-step instructions for deploying the SharePoint Service Desk.

## Prerequisites

- Microsoft 365 E3 or E5 tenant with admin access
- SharePoint Online admin permissions
- Power Platform environment access
- PnP PowerShell module installed (`Install-Module PnP.PowerShell`)
- Power BI Pro license (for dashboard embedding)

## Phase 1: SharePoint Foundation

### 1.1 Create the Communication Site

```powershell
Connect-PnPOnline -Url "https://yourtenant-admin.sharepoint.com" -Interactive
New-PnPSite -Type CommunicationSite `
  -Title "Service Desk" `
  -Url "https://yourtenant.sharepoint.com/sites/servicedesk" `
  -Description "IT Service Desk Portal"
```

### 1.2 Provision Lists

```powershell
.\scripts\provision-lists.ps1 -SiteUrl "https://yourtenant.sharepoint.com/sites/servicedesk"
```

This creates:
- **Tickets** list with all columns, content type, and views
- **Categories** list with sample data for IT, HR, and Operations
- **Agents** list for agent management

### 1.3 Apply Column Formatting

For each list column, go to **Column Settings → Format this column → Advanced mode** and paste the corresponding JSON:

| Column | File |
|--------|------|
| Tickets → Status | `column-formatting/status-pill.json` |
| Tickets → Priority | `column-formatting/priority-pill.json` |
| Tickets → TicketID | `column-formatting/ticket-id-format.json` |
| Tickets → SLADueDate | `column-formatting/sla-due-format.json` |

For the All Tickets view, go to **View Settings → Format current view → Advanced mode** and paste `column-formatting/view-formatting.json`.

### 1.4 Apply Site Theme

```powershell
.\spfx-theme\apply-theme.ps1 -SiteUrl "https://yourtenant.sharepoint.com/sites/servicedesk"
```

## Phase 2: Power Apps Canvas App

### 2.1 Create the App

1. Go to [make.powerapps.com](https://make.powerapps.com)
2. Create a new **Canvas App** → Tablet layout
3. Set app dimensions to 1366×768 (responsive)
4. Add data sources: Tickets, Categories, Agents (SharePoint connector)

### 2.2 Build Screens

Follow the YAML definitions in `power-apps/screens/`. For each screen:

1. Create the screen in Power Apps Studio
2. Add controls matching the YAML layout
3. Copy formulas from the YAML `Properties` sections
4. Reference `power-apps/formulas/app-formulas.md` for detailed formula explanations

Screen order:
1. **Dashboard** (`01-dashboard-screen.yaml`) — main landing
2. **Submit Ticket** (`02-submit-ticket-screen.yaml`) — new ticket form
3. **Ticket Detail** (`03-ticket-detail-screen.yaml`) — view/edit ticket
4. **Admin Queue** (`04-admin-queue-screen.yaml`) — agent workspace

### 2.3 Set Up Components

Import the component definitions from `power-apps/components/theme-component.yaml`:
- StatusPill, PriorityPill, KPICard, TicketRow
- Apply the theme constants (colors, fonts, spacing) across all screens

### 2.4 App.OnStart Configuration

```
// See power-apps/formulas/app-formulas.md for the full OnStart formula
// Key actions:
// 1. Cache user profile
// 2. Load categories into collection
// 3. Load agents into collection
// 4. Set default filter values
// 5. Check if user is an agent (controls admin screen visibility)
```

### 2.5 Embed in SharePoint

1. Go to your Service Desk SharePoint site
2. Edit the home page
3. Add a **Power Apps** web part
4. Select your canvas app
5. Set the web part to **Full width** column
6. Remove all other web parts — aim for full-bleed embed
7. Alternatively, link directly to the Power App URL (no SharePoint chrome at all)

## Phase 3: Power Automate Flows

### 3.1 Ticket ID Generator

1. Go to [make.powerautomate.com](https://make.powerautomate.com)
2. Create flow from `power-automate/flows/01-ticket-id-generator.json`
3. Trigger: SharePoint → When an item is created → Tickets list
4. Test by creating a ticket — verify it gets "INC-0001"

### 3.2 Auto-Routing

1. Create flow from `power-automate/flows/02-auto-routing.json`
2. Configures: department-based routing, load balancing, SLA calculation
3. Test by creating tickets in different departments

### 3.3 Email-to-Ticket

1. Create a shared mailbox (e.g., `support@yourdomain.com`) in Exchange Admin
2. Create flow from `power-automate/flows/03-email-to-ticket.json`
3. Configure the mailbox trigger
4. Test by sending an email to the shared mailbox

### 3.4 Notifications

1. Create flow from `power-automate/flows/04-notifications.json`
2. Configure Teams channel for notifications
3. Update email templates with your branding
4. Test each notification trigger

### 3.5 SLA Escalation

1. Create flow from `power-automate/flows/05-sla-escalation.json`
2. Runs every 30 minutes on a schedule
3. Configure escalation contacts per department
4. Test by creating a ticket with a past SLA due date

## Phase 4: Reporting & Polish

### 4.1 Power BI Dashboard

1. Open Power BI Desktop
2. Connect to SharePoint Online lists (Get Data → SharePoint Online List)
3. Follow `power-bi/dashboard-spec.md` for:
   - Data model and relationships
   - DAX measures
   - Page layouts and visuals
4. Publish to Power BI Service
5. Embed in SharePoint page using the Power BI web part

### 4.2 Teams App Deployment

1. Update `teams-app/manifest.json` with your Power App ID and tenant info
2. Package: zip the manifest + icons into a `.zip` file
3. Upload to Teams Admin Center → Manage Apps → Upload
4. Or sideload for testing: Teams → Apps → Upload a custom app
5. Pin the app in Teams for easy access

## Maintenance

### Adding New Departments
1. Add the department choice to Tickets.Department and Categories.Department columns
2. Add categories in the Categories list
3. Add agents in the Agents list
4. Update the auto-routing flow conditions

### Adding New Categories
1. Add item to the Categories list with department, SLA hours, and default assignee
2. The cascading dropdown in Power Apps picks it up automatically

### Monitoring SLA Compliance
1. Check the Power BI dashboard daily
2. Review the SLA escalation flow run history for failures
3. Adjust SLA hours per category as needed

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Ticket ID not generating | Check the ticket-id-generator flow run history |
| Cascading dropdown empty | Verify Categories list has items for that department |
| SLA not calculating | Check auto-routing flow; verify SLAHours in Categories |
| Email-to-ticket not working | Check shared mailbox permissions and flow trigger |
| Power App slow to load | Reduce OnStart operations; use concurrent loading |
| Delegation warnings | Keep filters delegation-friendly (no in-memory operations on large sets) |
