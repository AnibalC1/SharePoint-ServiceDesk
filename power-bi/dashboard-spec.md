# Power BI Dashboard Specification -- Service Desk Analytics

## 1. Overview

This document specifies the complete Power BI dashboard for the SharePoint Service Desk system. The dashboard provides real-time operational visibility, SLA tracking, agent performance metrics, and trend analysis for IT and departmental support operations.

**Report name:** Service Desk Analytics  
**Data refresh:** Scheduled every 30 minutes during business hours (6 AM -- 8 PM)  
**Row-level security:** Department-based; agents see their department, managers see all  
**Target audience:** Service Desk agents, Team Leads, IT Managers, Executives

---

## 2. Data Sources

### 2.1 SharePoint Online Connector

All data is sourced from SharePoint Online lists via the native SharePoint Online connector in Power BI.

#### Power Query (M) -- Connect to SharePoint Lists

```m
// =====================================================================
// Tickets List
// =====================================================================
let
    Source = SharePoint.Tables(
        "https://contoso.sharepoint.com/sites/ServiceDesk",
        [Implementation = "2.0", ViewMode = "All"]
    ),
    Tickets_Table = Source{[Title = "Tickets"]}[Items],
    // Select and rename columns
    SelectColumns = Table.SelectColumns(Tickets_Table, {
        "TicketID", "Title", "Department", "Priority", "Status",
        "Requester", "AssignedTo", "SLADueDate", "ResolutionDate",
        "ResolutionNotes", "Source", "EscalationLevel",
        "Created", "Modified", "Category"
    }),
    // Type conversions
    TypedColumns = Table.TransformColumnTypes(SelectColumns, {
        {"Created", type datetimezone},
        {"Modified", type datetimezone},
        {"SLADueDate", type datetimezone},
        {"ResolutionDate", type datetimezone},
        {"EscalationLevel", Int64.Type}
    }),
    // Expand User columns to display names
    ExpandRequester = Table.ExpandRecordColumn(TypedColumns, "Requester",
        {"DisplayName", "EMail"},
        {"RequesterName", "RequesterEmail"}),
    ExpandAssignee = Table.ExpandRecordColumn(ExpandRequester, "AssignedTo",
        {"DisplayName", "EMail"},
        {"AssigneeName", "AssigneeEmail"}),
    // Expand Category lookup
    ExpandCategory = Table.ExpandRecordColumn(ExpandAssignee, "Category",
        {"Value"}, {"CategoryName"}),
    // Add calculated columns
    AddResolutionHours = Table.AddColumn(ExpandCategory, "ResolutionHours",
        each if [ResolutionDate] <> null and [Created] <> null
             then Duration.TotalHours([ResolutionDate] - [Created])
             else null,
        type number),
    AddSLAMet = Table.AddColumn(AddResolutionHours, "SLAMet",
        each if [ResolutionDate] <> null and [SLADueDate] <> null
             then [ResolutionDate] <= [SLADueDate]
             else if [Status] <> "Resolved" and [Status] <> "Closed"
                  and [SLADueDate] <> null
             then DateTime.LocalNow() <= [SLADueDate]
             else null,
        type logical),
    AddCreatedDate = Table.AddColumn(AddSLAMet, "CreatedDate",
        each DateTime.Date([Created]), type date),
    AddCreatedMonth = Table.AddColumn(AddCreatedDate, "CreatedMonth",
        each Date.StartOfMonth([CreatedDate]), type date),
    AddCreatedWeek = Table.AddColumn(AddCreatedMonth, "CreatedWeek",
        each Date.StartOfWeek([CreatedDate], Day.Monday), type date),
    AddIsOpen = Table.AddColumn(AddCreatedWeek, "IsOpen",
        each [Status] <> "Resolved" and [Status] <> "Closed", type logical),
    AddIsResolved = Table.AddColumn(AddIsOpen, "IsResolved",
        each [Status] = "Resolved" or [Status] = "Closed", type logical),
    AddAgeHours = Table.AddColumn(AddIsResolved, "AgeHours",
        each if [IsOpen]
             then Duration.TotalHours(DateTime.LocalNow() - [Created])
             else [ResolutionHours],
        type number)
in
    AddAgeHours
```

```m
// =====================================================================
// Date Dimension Table (generated, not from SharePoint)
// =====================================================================
let
    StartDate = #date(2024, 1, 1),
    EndDate = Date.From(DateTime.LocalNow()) + #duration(90, 0, 0, 0),
    DateCount = Duration.Days(EndDate - StartDate) + 1,
    DateList = List.Dates(StartDate, DateCount, #duration(1, 0, 0, 0)),
    ToTable = Table.FromList(DateList, Splitter.SplitByNothing(), {"Date"}, null, ExtraValues.Error),
    TypedDate = Table.TransformColumnTypes(ToTable, {{"Date", type date}}),
    AddYear = Table.AddColumn(TypedDate, "Year", each Date.Year([Date]), Int64.Type),
    AddMonth = Table.AddColumn(AddYear, "Month", each Date.Month([Date]), Int64.Type),
    AddMonthName = Table.AddColumn(AddMonth, "MonthName",
        each Date.ToText([Date], "MMMM"), type text),
    AddMonthShort = Table.AddColumn(AddMonthName, "MonthShort",
        each Date.ToText([Date], "MMM"), type text),
    AddQuarter = Table.AddColumn(AddMonthShort, "Quarter",
        each "Q" & Text.From(Date.QuarterOfYear([Date])), type text),
    AddWeekday = Table.AddColumn(AddQuarter, "Weekday",
        each Date.DayOfWeekName([Date]), type text),
    AddWeekNum = Table.AddColumn(AddWeekday, "WeekNumber",
        each Date.WeekOfYear([Date]), Int64.Type),
    AddIsWeekend = Table.AddColumn(AddWeekNum, "IsWeekend",
        each Date.DayOfWeek([Date], Day.Monday) >= 5, type logical),
    AddYearMonth = Table.AddColumn(AddIsWeekend, "YearMonth",
        each Date.ToText([Date], "yyyy-MM"), type text),
    AddMonthStart = Table.AddColumn(AddYearMonth, "MonthStart",
        each Date.StartOfMonth([Date]), type date)
in
    AddMonthStart
```

```m
// =====================================================================
// SLA Configuration Reference Table (manual entry or from SharePoint)
// =====================================================================
let
    Source = Table.FromRecords({
        [Priority = "Critical", SLAHours = 4,  ResponseHours = 0.5],
        [Priority = "High",     SLAHours = 8,  ResponseHours = 1],
        [Priority = "Medium",   SLAHours = 24, ResponseHours = 4],
        [Priority = "Low",      SLAHours = 72, ResponseHours = 8]
    }),
    Typed = Table.TransformColumnTypes(Source, {
        {"Priority", type text},
        {"SLAHours", Int64.Type},
        {"ResponseHours", Int64.Type}
    })
in
    Typed
```

### 2.2 Data Model Relationships

| From Table | From Column | To Table | To Column | Cardinality | Cross-filter |
|---|---|---|---|---|---|
| Tickets | CreatedDate | DateDim | Date | Many-to-One | Single |
| Tickets | Priority | SLAConfig | Priority | Many-to-One | Single |

---

## 3. DAX Measures

All measures are organized in a dedicated `_Measures` table (a disconnected table with a single placeholder column).

### 3.1 Volume Metrics

```dax
// Total Tickets
Total Tickets =
COUNTROWS(Tickets)

// Open Tickets (not resolved or closed)
Open Tickets =
CALCULATE(
    COUNTROWS(Tickets),
    Tickets[IsOpen] = TRUE
)

// Resolved Tickets
Resolved Tickets =
CALCULATE(
    COUNTROWS(Tickets),
    Tickets[IsResolved] = TRUE
)

// New Tickets Today
New Tickets Today =
CALCULATE(
    COUNTROWS(Tickets),
    Tickets[CreatedDate] = TODAY()
)

// New Tickets This Week
New Tickets This Week =
CALCULATE(
    COUNTROWS(Tickets),
    DATESINPERIOD(DateDim[Date], TODAY(), -7, DAY)
)

// New Tickets This Month
New Tickets This Month =
CALCULATE(
    COUNTROWS(Tickets),
    DATESMTD(DateDim[Date])
)

// Tickets Closed This Month
Closed This Month =
CALCULATE(
    COUNTROWS(Tickets),
    Tickets[IsResolved] = TRUE,
    MONTH(Tickets[ResolutionDate]) = MONTH(TODAY()),
    YEAR(Tickets[ResolutionDate]) = YEAR(TODAY())
)
```

### 3.2 Resolution Time

```dax
// Average Resolution Time (hours)
Avg Resolution Time (Hours) =
AVERAGE(Tickets[ResolutionHours])

// Median Resolution Time (hours)
Median Resolution Time (Hours) =
MEDIAN(Tickets[ResolutionHours])

// Average Resolution Time (formatted as "Xh Ym")
Avg Resolution Time Formatted =
VAR AvgHrs = [Avg Resolution Time (Hours)]
VAR Hours = INT(AvgHrs)
VAR Minutes = ROUND((AvgHrs - Hours) * 60, 0)
RETURN
    IF(
        ISBLANK(AvgHrs),
        "--",
        FORMAT(Hours, "0") & "h " & FORMAT(Minutes, "00") & "m"
    )

// P90 Resolution Time (90th percentile)
P90 Resolution Time =
PERCENTILEX.INC(
    FILTER(Tickets, Tickets[ResolutionHours] <> BLANK()),
    Tickets[ResolutionHours],
    0.9
)
```

### 3.3 SLA Compliance

```dax
// SLA Compliance Rate
SLA Compliance Rate =
VAR TicketsWithSLA =
    CALCULATE(
        COUNTROWS(Tickets),
        Tickets[SLAMet] <> BLANK()
    )
VAR TicketsMet =
    CALCULATE(
        COUNTROWS(Tickets),
        Tickets[SLAMet] = TRUE
    )
RETURN
    IF(
        TicketsWithSLA = 0,
        BLANK(),
        DIVIDE(TicketsMet, TicketsWithSLA, 0)
    )

// SLA Compliance Rate (formatted)
SLA Compliance % =
FORMAT([SLA Compliance Rate], "0.0%")

// SLA Breached Count
SLA Breached =
CALCULATE(
    COUNTROWS(Tickets),
    Tickets[SLAMet] = FALSE
)

// SLA At Risk (open tickets within 2 hours of SLA due)
SLA At Risk =
CALCULATE(
    COUNTROWS(Tickets),
    Tickets[IsOpen] = TRUE,
    Tickets[SLADueDate] <> BLANK(),
    Tickets[SLADueDate] <= NOW() + (2 / 24),
    Tickets[SLADueDate] > NOW()
)

// Overdue Tickets
Overdue Tickets =
CALCULATE(
    COUNTROWS(Tickets),
    Tickets[IsOpen] = TRUE,
    Tickets[SLADueDate] <> BLANK(),
    Tickets[SLADueDate] < NOW()
)
```

### 3.4 Tickets by Dimension

```dax
// Tickets by Department (for use with Department on axis)
Tickets by Department =
COUNTROWS(Tickets)

// Tickets by Category
Tickets by Category =
COUNTROWS(Tickets)

// Tickets by Priority
Tickets by Priority =
COUNTROWS(Tickets)

// Tickets by Source Channel
Tickets by Source =
COUNTROWS(Tickets)

// Priority Distribution %
Priority Distribution % =
DIVIDE(
    COUNTROWS(Tickets),
    CALCULATE(COUNTROWS(Tickets), ALL(Tickets[Priority])),
    0
)

// Department Share %
Department Share % =
DIVIDE(
    COUNTROWS(Tickets),
    CALCULATE(COUNTROWS(Tickets), ALL(Tickets[Department])),
    0
)
```

### 3.5 Agent Workload

```dax
// Tickets Per Agent (currently assigned, open)
Agent Open Tickets =
CALCULATE(
    COUNTROWS(Tickets),
    Tickets[IsOpen] = TRUE
)

// Agent Resolved Count (in selected period)
Agent Resolved Count =
CALCULATE(
    COUNTROWS(Tickets),
    Tickets[IsResolved] = TRUE
)

// Agent Avg Resolution Time
Agent Avg Resolution =
CALCULATE(
    AVERAGE(Tickets[ResolutionHours]),
    Tickets[IsResolved] = TRUE
)

// Agent SLA Compliance
Agent SLA Compliance =
VAR AgentTotal =
    CALCULATE(
        COUNTROWS(Tickets),
        Tickets[SLAMet] <> BLANK()
    )
VAR AgentMet =
    CALCULATE(
        COUNTROWS(Tickets),
        Tickets[SLAMet] = TRUE
    )
RETURN
    DIVIDE(AgentMet, AgentTotal, BLANK())

// Unassigned Tickets
Unassigned Tickets =
CALCULATE(
    COUNTROWS(Tickets),
    Tickets[IsOpen] = TRUE,
    ISBLANK(Tickets[AssigneeName])
)

// Unique Active Agents
Active Agents =
DISTINCTCOUNT(Tickets[AssigneeName])
```

### 3.6 Trend Metrics

```dax
// Daily Ticket Volume
Daily Volume =
CALCULATE(
    COUNTROWS(Tickets),
    DATESINPERIOD(DateDim[Date], MAX(DateDim[Date]), -1, DAY)
)

// Weekly Ticket Volume (rolling 7 days)
Weekly Rolling Volume =
CALCULATE(
    COUNTROWS(Tickets),
    DATESINPERIOD(DateDim[Date], MAX(DateDim[Date]), -7, DAY)
)

// Monthly Ticket Volume
Monthly Volume =
CALCULATE(
    COUNTROWS(Tickets),
    DATESMTD(DateDim[Date])
)

// Week-over-Week Change %
WoW Change % =
VAR ThisWeek =
    CALCULATE(
        COUNTROWS(Tickets),
        DATESINPERIOD(DateDim[Date], TODAY(), -7, DAY)
    )
VAR LastWeek =
    CALCULATE(
        COUNTROWS(Tickets),
        DATESINPERIOD(DateDim[Date], TODAY() - 7, -7, DAY)
    )
RETURN
    DIVIDE(ThisWeek - LastWeek, LastWeek, BLANK())

// Month-over-Month Change %
MoM Change % =
VAR ThisMonth = [New Tickets This Month]
VAR LastMonth =
    CALCULATE(
        COUNTROWS(Tickets),
        DATEADD(DateDim[Date], -1, MONTH)
    )
RETURN
    DIVIDE(ThisMonth - LastMonth, LastMonth, BLANK())

// Cumulative Open Tickets Over Time
Cumulative Open =
VAR CurrentDate = MAX(DateDim[Date])
RETURN
    CALCULATE(
        COUNTROWS(Tickets),
        Tickets[CreatedDate] <= CurrentDate,
        OR(
            Tickets[IsOpen] = TRUE,
            Tickets[ResolutionDate] > CurrentDate
        )
    )
```

### 3.7 First Response Time

```dax
// First Response Time (hours) -- estimated from Created to first Modified
// Note: Accurate first-response tracking requires a dedicated "First Response Date"
// column. This approximation uses the first modification after creation.
First Response Time =
DATEDIFF(
    Tickets[Created],
    Tickets[Modified],
    HOUR
)

// Avg First Response Time
Avg First Response Time =
AVERAGEX(
    FILTER(Tickets, Tickets[Status] <> "New"),
    DATEDIFF(Tickets[Created], Tickets[Modified], HOUR)
)
```

### 3.8 Reopen Rate

```dax
// Reopen Rate
// Requires an "IsReopened" flag set by Power Automate when status moves
// from Resolved/Closed back to an open state.
// Approximation: tickets resolved more than once (multiple resolution dates).
Reopen Rate =
VAR TotalResolved =
    CALCULATE(
        COUNTROWS(Tickets),
        Tickets[IsResolved] = TRUE
    )
VAR Reopened =
    CALCULATE(
        COUNTROWS(Tickets),
        Tickets[EscalationLevel] > 0,
        Tickets[IsResolved] = TRUE
    )
RETURN
    DIVIDE(Reopened, TotalResolved, 0)

// Reopen Rate (formatted)
Reopen Rate % =
FORMAT([Reopen Rate], "0.0%")
```

### 3.9 Escalation Metrics

```dax
// Escalation Rate
Escalation Rate =
DIVIDE(
    CALCULATE(COUNTROWS(Tickets), Tickets[EscalationLevel] > 0),
    COUNTROWS(Tickets),
    0
)

// Avg Escalation Level
Avg Escalation Level =
AVERAGE(Tickets[EscalationLevel])
```

---

## 4. Report Pages

### 4.1 Page 1: Executive Summary

**Purpose:** High-level KPIs and trends for leadership at a glance.

#### Layout

```
+------------------------------------------------------------------+
|  SERVICE DESK ANALYTICS          [Date Range Slicer] [Dept Slicer]|
+------------------------------------------------------------------+
|                                                                    |
|  [KPI: Total]  [KPI: Open]  [KPI: SLA%]  [KPI: Avg Res Time]    |
|                                                                    |
+------------------------------------------------------------------+
|                                |                                   |
|  Ticket Volume Trend           |  SLA Compliance Gauge             |
|  (Area chart, daily, 90 days)  |  (Gauge: target 95%, max 100%)   |
|                                |                                   |
|                                |  [Overdue]  [At Risk]             |
|                                |                                   |
+------------------------------------------------------------------+
|                                |                                   |
|  Priority Distribution         |  Top 5 Categories                 |
|  (Donut chart)                 |  (Horizontal bar chart)           |
|                                |                                   |
+------------------------------------------------------------------+
|                                                                    |
|  Tickets by Department (Stacked bar, colored by priority)          |
|                                                                    |
+------------------------------------------------------------------+
```

#### Visuals

| Visual | Type | Measures / Fields | Notes |
|---|---|---|---|
| Total Tickets KPI | Card | `[Total Tickets]` | Large number, subtitle "All Time" |
| Open Tickets KPI | Card | `[Open Tickets]` | Conditional: red if > threshold |
| SLA Compliance KPI | Card | `[SLA Compliance %]` | Green >= 95%, yellow >= 85%, red < 85% |
| Avg Resolution Time KPI | Card | `[Avg Resolution Time Formatted]` | With trend arrow via MoM change |
| Volume Trend | Area chart | Axis: `DateDim[Date]`, Values: `[Total Tickets]` | 90-day default, line + area fill |
| SLA Gauge | Gauge | Value: `[SLA Compliance Rate]`, Target: 0.95 | Green/yellow/red bands |
| Priority Donut | Donut chart | Legend: `Tickets[Priority]`, Values: `[Total Tickets]` | Custom colors per priority |
| Top Categories | Bar chart (horiz) | Axis: `Tickets[CategoryName]`, Values: `[Total Tickets]` | Top N = 5, sorted desc |
| Dept Breakdown | Stacked bar | Axis: `Tickets[Department]`, Values: `[Total Tickets]`, Legend: `Tickets[Priority]` | Custom priority colors |

#### Conditional formatting

- SLA Compliance card: background color rule -- green (#DFF6DD) if >= 0.95, yellow (#FFF4CE) if >= 0.85, red (#FDE7E9) if < 0.85.
- Open Tickets card: font color red (#A4262C) if value > 50.

---

### 4.2 Page 2: Department View

**Purpose:** Per-department deep dive with drill-through from Executive Summary.

#### Layout

```
+------------------------------------------------------------------+
|  DEPARTMENT VIEW                   [Department Slicer] [Date]     |
+------------------------------------------------------------------+
|                                                                    |
|  [KPI: Dept Tickets]  [KPI: Dept Open]  [KPI: Dept SLA%]         |
|                                                                    |
+------------------------------------------------------------------+
|                                |                                   |
|  Category Breakdown            |  Status Distribution              |
|  (Treemap)                     |  (Donut chart)                    |
|                                |                                   |
+------------------------------------------------------------------+
|                                |                                   |
|  Monthly Volume by Dept        |  Priority Split                   |
|  (Line chart, multi-series)    |  (Stacked column)                 |
|                                |                                   |
+------------------------------------------------------------------+
|                                                                    |
|  Department Ticket Detail Table (drill-through target)             |
|  Columns: TicketID, Title, Priority, Status, Assignee, Age,       |
|           SLA Due, SLA Met                                         |
|                                                                    |
+------------------------------------------------------------------+
```

#### Drill-through configuration

- Drill-through field: `Tickets[Department]`
- Back button in top-left corner
- Source page: Executive Summary (department bar chart)

---

### 4.3 Page 3: Agent Performance

**Purpose:** Individual agent metrics and team comparison.

#### Layout

```
+------------------------------------------------------------------+
|  AGENT PERFORMANCE               [Agent Slicer] [Date Range]      |
+------------------------------------------------------------------+
|                                                                    |
|  [KPI: Agent Resolved]  [KPI: Agent Avg Time]  [KPI: Agent SLA%] |
|                                                                    |
+------------------------------------------------------------------+
|                                                                    |
|  Agent Comparison Matrix (Table visual)                            |
|  Columns: Agent | Open | Resolved | Avg Time | SLA% | Escalated  |
|  Conditional formatting on all metric columns                      |
|                                                                    |
+------------------------------------------------------------------+
|                                |                                   |
|  Agent Resolution Time         |  Agent Workload Distribution      |
|  (Box plot / scatter)          |  (Bar chart: open tickets/agent)  |
|                                |                                   |
+------------------------------------------------------------------+
|                                                                    |
|  Agent Trend (Line chart: resolved tickets per week per agent)     |
|                                                                    |
+------------------------------------------------------------------+
```

#### Agent Comparison Matrix -- conditional formatting rules

| Column | Rule |
|---|---|
| Avg Time | Data bars, blue gradient |
| SLA% | Icons: green check >= 95%, yellow dash >= 85%, red X < 85% |
| Open | Background color scale: white (0) to red (max) |

---

### 4.4 Page 4: Trends and Forecasting

**Purpose:** Historical trends with built-in forecasting for capacity planning.

#### Layout

```
+------------------------------------------------------------------+
|  TRENDS & FORECASTING                            [Date Range]     |
+------------------------------------------------------------------+
|                                                                    |
|  [KPI: WoW Change %]  [KPI: MoM Change %]  [KPI: Avg Daily Vol] |
|                                                                    |
+------------------------------------------------------------------+
|                                                                    |
|  Daily Ticket Volume with Forecast                                 |
|  (Line chart + built-in forecast, 30-day lookahead,               |
|   95% confidence interval)                                         |
|                                                                    |
+------------------------------------------------------------------+
|                                |                                   |
|  Weekly Heatmap                |  Resolution Time Trend             |
|  (Matrix: weekday x hour)     |  (Line chart: avg res time/week)   |
|                                |                                   |
+------------------------------------------------------------------+
|                                |                                   |
|  Cumulative Open Over Time     |  Source Channel Trend              |
|  (Area chart)                  |  (Stacked area by source)          |
|                                |                                   |
+------------------------------------------------------------------+
```

#### Forecasting settings

- Algorithm: built-in Power BI forecasting (ETS)
- Forecast length: 30 days
- Confidence interval: 95%
- Seasonality: auto-detect (expected weekly pattern)
- Ignore last: 3 data points

---

## 5. Filters and Slicers

### Global Slicers (synced across all pages)

| Slicer | Field | Type | Default |
|---|---|---|---|
| Date Range | `DateDim[Date]` | Between (date range) | Last 90 days |
| Department | `Tickets[Department]` | Dropdown, multi-select | All |

### Page-specific Slicers

| Page | Slicer | Field | Type |
|---|---|---|---|
| Agent Performance | Agent | `Tickets[AssigneeName]` | Dropdown, multi-select |
| Department View | Department | `Tickets[Department]` | Single select |
| Trends | Granularity | (parameter) | Buttons: Daily / Weekly / Monthly |

---

## 6. Color Theme

Apply the following colors consistently across all visuals:

| Purpose | Hex | Usage |
|---|---|---|
| Primary | #0078D4 | Default data series, links |
| Secondary | #106EBE | Secondary series, hover states |
| Accent | #038387 | Tertiary series, accents |
| Background | #FAF9F8 | Page background |
| Surface | #FFFFFF | Card and visual backgrounds |
| Text Primary | #323130 | Titles, labels |
| Text Secondary | #605E5C | Subtitles, axis labels |
| Critical | #A4262C | Critical priority, SLA breach |
| High | #D83B01 | High priority |
| Medium | #0078D4 | Medium priority |
| Low | #8A8886 | Low priority |
| Warning | #FFB900 | Warning indicators |
| Success | #107C10 | SLA met, resolved |

### Power BI Theme JSON (paste into View > Themes > Customize)

```json
{
  "name": "ServiceDeskTheme",
  "dataColors": [
    "#0078D4", "#038387", "#106EBE", "#CA5010",
    "#8764B8", "#107C10", "#D83B01", "#005A9E"
  ],
  "background": "#FAF9F8",
  "foreground": "#323130",
  "tableAccent": "#0078D4",
  "good": "#107C10",
  "neutral": "#FFB900",
  "bad": "#A4262C",
  "maximum": "#A4262C",
  "center": "#FFB900",
  "minimum": "#107C10",
  "visualStyles": {
    "*": {
      "*": {
        "background": [{ "color": { "solid": { "color": "#FFFFFF" } } }],
        "border": [{ "color": { "solid": { "color": "#EDEBE9" } } }],
        "title": [{
          "fontColor": { "solid": { "color": "#323130" } },
          "fontFamily": "Segoe UI Semibold",
          "fontSize": 12
        }]
      }
    }
  }
}
```

---

## 7. Embedding in SharePoint

### 7.1 Publish to Power BI Service

1. Publish the report from Power BI Desktop to a workspace.
2. Configure scheduled refresh with SharePoint Online credentials (OAuth2).
3. Verify data gateway is not required (cloud-to-cloud connector).

### 7.2 Embed via Power BI Web Part

1. Navigate to the Service Desk SharePoint site.
2. Edit the target page (e.g., "Dashboard" page).
3. Add the **Power BI** web part.
4. Paste the report URL from Power BI Service.
5. Configure web part settings:
   - Show navigation pane: **Yes**
   - Show filter pane: **No** (use slicers on the report canvas)
   - Show bookmarks bar: **Optional**
   - Page: Select default page (Executive Summary)
6. Publish the SharePoint page.

### 7.3 Embed via iframe (alternative)

```html
<iframe
  title="Service Desk Analytics"
  width="100%"
  height="800"
  src="https://app.powerbi.com/reportEmbed?reportId=YOUR_REPORT_ID&autoAuth=true&ctid=YOUR_TENANT_ID"
  frameborder="0"
  allowFullScreen="true">
</iframe>
```

### 7.4 Row-Level Security

Configure RLS in Power BI Desktop:

1. Go to Modeling > Manage Roles.
2. Create role **DepartmentFilter**:
   ```dax
   [Department] = USERPRINCIPALNAME()
   ```
   Note: For production, map UPN to department via a security table:
   ```dax
   // Security table approach
   CONTAINS(
       SecurityTable,
       SecurityTable[UserEmail], USERPRINCIPALNAME(),
       SecurityTable[Department], Tickets[Department]
   )
   ```
3. Create role **AllAccess** with no filter (for IT managers).
4. Assign users to roles in Power BI Service workspace settings.

---

## 8. Performance Optimization

- **Aggregations:** Pre-aggregate daily ticket counts in a summary table for large datasets (> 50,000 rows).
- **Incremental refresh:** Configure incremental refresh on the Tickets table with a 30-day rolling window for full refresh and 2-year archive.
- **Query folding:** Ensure Power Query steps fold to the SharePoint connector where possible. Avoid custom M functions that break folding.
- **Visual count:** Keep visuals per page under 10 for optimal render performance.
- **Bookmarks:** Use bookmarks for alternate views rather than cramming all visuals onto one page.

---

## 9. Maintenance

| Task | Frequency | Owner |
|---|---|---|
| Validate data refresh succeeds | Daily (automated alert) | Power BI Admin |
| Review SLA thresholds | Quarterly | Service Desk Manager |
| Update category/department lists | As needed | SharePoint Admin |
| Review RLS role assignments | Monthly | Power BI Admin |
| Archive historical data | Annually | SharePoint Admin |
