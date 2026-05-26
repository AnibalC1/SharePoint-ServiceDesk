# SharePoint Service Desk

A complete, modern IT service desk / helpdesk system built entirely on Microsoft 365 — SharePoint Online, Power Apps, Power Automate, Power BI, and Teams.

Designed to look and feel like a premium SaaS product while running on infrastructure you already pay for with E3/E5 licensing.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Intake Channels                       │
│  Power Apps Portal  │  Email (Shared Mailbox)  │  Teams  │
└────────┬────────────┴──────────┬───────────────┴────┬───┘
         │                       │                    │
         ▼                       ▼                    ▼
┌─────────────────────────────────────────────────────────┐
│              Power Automate (Workflow Engine)            │
│  Ticket ID Gen │ Routing │ Notifications │ SLA Monitor  │
└────────────────────────────┬────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────┐
│              SharePoint Online (Data Layer)              │
│       Tickets List  │  Categories List  │  Agents List   │
└────────────────────────────┬────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────┐
│              Power BI (Reporting Dashboard)              │
│  KPIs │ SLA Compliance │ Agent Performance │ Trends     │
└─────────────────────────────────────────────────────────┘
```

## What's in This Repo

```
SharePoint-ServiceDesk/
├── sharepoint-lists/          # List schemas (PnP-compatible JSON)
│   ├── tickets-list.json      # Main tickets list with all fields
│   ├── categories-list.json   # Department categories + sample data
│   └── agents-list.json       # Agent roster and workload tracking
│
├── column-formatting/         # SharePoint column/view formatting
│   ├── status-pill.json       # Colored status badges
│   ├── priority-pill.json     # Priority indicators with icons
│   ├── ticket-id-format.json  # Monospace ticket ID styling
│   ├── sla-due-format.json    # Conditional SLA deadline coloring
│   └── view-formatting.json   # Card-style row formatting
│
├── power-apps/                # Power Apps canvas app
│   ├── screens/
│   │   ├── 01-dashboard-screen.yaml
│   │   ├── 02-submit-ticket-screen.yaml
│   │   ├── 03-ticket-detail-screen.yaml
│   │   └── 04-admin-queue-screen.yaml
│   ├── components/
│   │   └── theme-component.yaml
│   └── formulas/
│       └── app-formulas.md
│
├── power-automate/            # Power Automate flow definitions
│   ├── flows/
│   │   ├── 01-ticket-id-generator.json
│   │   ├── 02-auto-routing.json
│   │   ├── 03-email-to-ticket.json
│   │   ├── 04-notifications.json
│   │   └── 05-sla-escalation.json
│   └── expressions/
│       └── common-expressions.md
│
├── spfx-theme/                # SharePoint site theming
│   ├── theme.json
│   └── apply-theme.ps1
│
├── power-bi/                  # Power BI dashboard
│   └── dashboard-spec.md
│
├── teams-app/                 # Microsoft Teams integration
│   ├── manifest.json
│   └── adaptive-cards/
│       ├── ticket-notification.json
│       └── new-ticket-form.json
│
├── branding/                  # Design system
│   ├── style-guide.md
│   └── css-tokens.css
│
└── scripts/                   # Deployment scripts
    └── provision-lists.ps1
```

## Phased Deployment

### Phase 1 — Foundation (Week 1)
1. Create a Communication Site in SharePoint Online
2. Run `scripts/provision-lists.ps1` to create all three lists
3. Apply the theme from `spfx-theme/theme.json`
4. Apply column formatting from `column-formatting/`

### Phase 2 — Power App (Weeks 2–3)
1. Create a new Canvas App in Power Apps
2. Connect to the three SharePoint lists
3. Build screens following the YAML definitions in `power-apps/screens/`
4. Import components from `power-apps/components/`
5. Embed the app in your SharePoint landing page (full-bleed, no chrome)

### Phase 3 — Automation (Weeks 3–4)
1. Create flows from the definitions in `power-automate/flows/`
2. Set up a shared mailbox for email-to-ticket
3. Configure notification recipients and Teams channels
4. Test the SLA escalation flow

### Phase 4 — Reporting & Polish (Weeks 4–5)
1. Build the Power BI report following `power-bi/dashboard-spec.md`
2. Embed the dashboard in your SharePoint landing page
3. Deploy the Teams app from `teams-app/manifest.json`
4. Configure adaptive cards for Teams notifications

## Licensing Requirements

| Component | License Needed |
|-----------|---------------|
| SharePoint Lists | Microsoft 365 E3/E5 |
| Power Apps (SharePoint connector) | Included with M365 E3/E5 |
| Power Automate (standard connectors) | Included with M365 E3/E5 |
| Power BI (publish & embed) | Power BI Pro or Premium Per User |
| Teams App | Included with M365 E3/E5 |
| Premium connectors (SQL, Dataverse, custom APIs) | Power Apps per-app or per-user plan |

## Design Principles

- **No SharePoint Chrome**: Full-bleed Power App embed removes all SharePoint UI
- **Modern Dashboard Aesthetic**: KPI cards, colored pill badges, generous whitespace
- **Brand-First**: Custom theme, typography, and component library
- **SLA-Driven**: Every ticket has a calculated SLA target; breaches trigger escalation
- **Multi-Channel**: Portal, email, and Teams — same system, same data
- **Self-Service**: Requesters can submit, track, and close their own tickets
- **Zero-Code Maintenance**: Everything is M365-native, no custom code deployment needed
