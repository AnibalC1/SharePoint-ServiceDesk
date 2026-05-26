# Power Fx Formula Reference

Complete reference for all Power Fx formulas used in the Service Desk canvas app.

## App.OnStart

```
// Initialize user context
Set(varCurrentUser, User());
Set(varUserEmail, User().Email);
Set(varUserDisplayName, User().FullName);

// Check if current user is an agent
Set(
    varIsAgent,
    !IsBlank(
        LookUp(
            Agents,
            Email = varUserEmail && IsActive = true
        )
    )
);

// Cache agent record if applicable
If(
    varIsAgent,
    Set(
        varAgentRecord,
        LookUp(Agents, Email = varUserEmail)
    )
);

// Load categories into a collection for fast filtering
ClearCollect(
    colCategories,
    Filter(Categories, IsActive = true)
);

// Load agents for assignment dropdowns
ClearCollect(
    colActiveAgents,
    Filter(Agents, IsActive = true)
);

// Initialize filter variables
Set(varFilterDepartment, Blank());
Set(varFilterStatus, Blank());
Set(varFilterPriority, Blank());
Set(varSearchText, "");

// Set default screen based on role
If(
    varIsAgent,
    Set(varDefaultScreen, scrAdminQueue),
    Set(varDefaultScreen, scrDashboard)
);
```

## Data Connections

The app connects to three SharePoint Online lists:
- **Tickets** — main ticket data
- **Categories** — department categories with SLA info
- **Agents** — agent roster

All connections use the SharePoint connector (standard, included with M365 E3/E5).

## KPI Calculations

### Open Tickets Count
```
CountRows(
    Filter(
        Tickets,
        Status <> "Resolved" && Status <> "Closed"
    )
)
```

### Overdue Tickets Count
```
CountRows(
    Filter(
        Tickets,
        Status <> "Resolved" && Status <> "Closed" &&
        SLADueDate < Now()
    )
)
```

### Average Resolution Time (hours)
```
Round(
    Average(
        Filter(
            Tickets,
            Status = "Resolved" || Status = "Closed"
        ),
        DateDiff(Created, ResolutionDate, TimeUnit.Hours)
    ),
    1
)
```

### SLA Compliance Rate
```
With(
    {
        resolvedTickets: Filter(
            Tickets,
            (Status = "Resolved" || Status = "Closed") &&
            !IsBlank(ResolutionDate) &&
            !IsBlank(SLADueDate)
        )
    },
    If(
        CountRows(resolvedTickets) = 0,
        100,
        Round(
            CountRows(
                Filter(
                    resolvedTickets,
                    ResolutionDate <= SLADueDate
                )
            ) / CountRows(resolvedTickets) * 100,
            1
        )
    )
)
```

## Filtering Logic

### Combined Filter for Ticket Gallery
```
Sort(
    Filter(
        Tickets,
        // Department filter
        (IsBlank(varFilterDepartment) || Department = varFilterDepartment) &&
        // Status filter
        (IsBlank(varFilterStatus) || Status = varFilterStatus) &&
        // Priority filter
        (IsBlank(varFilterPriority) || Priority = varFilterPriority) &&
        // Search filter (delegable with StartsWith)
        (IsBlank(varSearchText) || StartsWith(Title, varSearchText) || StartsWith(TicketID, varSearchText))
    ),
    Created,
    SortOrder.Descending
)
```

### Cascading Department → Category Dropdown
```
// Category dropdown Items property
Filter(
    colCategories,
    Department = drpDepartment.Selected.Value
)
```

### My Tickets Filter (Requester View)
```
Filter(
    Tickets,
    Requester.Email = varUserEmail
)
```

### My Queue Filter (Agent View)
```
Filter(
    Tickets,
    AssignedTo.Email = varUserEmail &&
    Status <> "Closed"
)
```

## Form Submission

### Submit New Ticket
```
// Submit button OnSelect
If(
    // Validation
    IsBlank(txtTitle.Text) || IsBlank(drpDepartment.Selected.Value),
    Notify("Please fill in all required fields.", NotificationType.Error),

    // Create ticket
    Set(
        varNewTicket,
        Patch(
            Tickets,
            Defaults(Tickets),
            {
                Title: txtTitle.Text,
                Description: rteDescription.HtmlText,
                Department: drpDepartment.Selected,
                Category: drpCategory.Selected,
                Priority: varSelectedPriority,
                Status: {Value: "New"},
                Requester: {
                    Claims: "i:0#.f|membership|" & varUserEmail,
                    Department: "",
                    DisplayName: varUserDisplayName,
                    Email: varUserEmail,
                    JobTitle: "",
                    Picture: ""
                },
                Source: {Value: "Portal"}
            }
        )
    );

    // Handle attachments
    If(
        CountRows(attUpload.Attachments) > 0,
        ForAll(
            attUpload.Attachments,
            Patch(
                Tickets,
                varNewTicket,
                {Attachments: attUpload.Attachments}
            )
        )
    );

    // Success feedback
    Notify("Ticket submitted successfully! ID will be assigned shortly.", NotificationType.Success);
    Reset(txtTitle);
    Reset(rteDescription);
    Reset(drpDepartment);
    Reset(drpCategory);
    Set(varSelectedPriority, "Medium");
    Navigate(scrDashboard, ScreenTransition.None)
)
```

### Update Ticket (Agent Actions)
```
// Change Status
Patch(
    Tickets,
    varSelectedTicket,
    {
        Status: drpStatus.Selected
    }
);
Notify("Status updated.", NotificationType.Success);

// Assign Ticket
Patch(
    Tickets,
    varSelectedTicket,
    {
        AssignedTo: {
            Claims: "i:0#.f|membership|" & drpAssignee.Selected.Email,
            Department: "",
            DisplayName: drpAssignee.Selected.Title,
            Email: drpAssignee.Selected.Email,
            JobTitle: "",
            Picture: ""
        },
        Status: {Value: "Assigned"}
    }
);
Notify("Ticket assigned to " & drpAssignee.Selected.Title, NotificationType.Success);

// Resolve Ticket
Patch(
    Tickets,
    varSelectedTicket,
    {
        Status: {Value: "Resolved"},
        ResolutionNotes: rteResolution.HtmlText,
        ResolutionDate: Now()
    }
);
Notify("Ticket resolved.", NotificationType.Success);

// Escalate Ticket
Patch(
    Tickets,
    varSelectedTicket,
    {
        EscalationLevel: varSelectedTicket.EscalationLevel + 1,
        Priority: {Value: "Critical"}
    }
);
Notify("Ticket escalated.", NotificationType.Warning);
```

## Status Transitions

### Allowed Status Transitions
```
// Returns valid next statuses based on current status and user role
Switch(
    varSelectedTicket.Status.Value,
    "New",       If(varIsAgent, Table({Value: "Assigned"}, {Value: "In Progress"}, {Value: "Closed"}), Table({Value: "Closed"})),
    "Assigned",  If(varIsAgent, Table({Value: "In Progress"}, {Value: "Pending Requester"}, {Value: "Closed"}), Table({Value: "Closed"})),
    "In Progress", If(varIsAgent, Table({Value: "Pending Requester"}, {Value: "Resolved"}, {Value: "Closed"}), Table({Value: "Closed"})),
    "Pending Requester", Table({Value: "In Progress"}, {Value: "Resolved"}, {Value: "Closed"}),
    "Resolved",  Table({Value: "In Progress"}, {Value: "Closed"}),
    "Closed",    If(varIsAgent, Table({Value: "In Progress"}), Blank())
)
```

## SLA Calculations

### SLA Color Logic (for display)
```
// Returns a color hex based on SLA status
If(
    IsBlank(ThisItem.SLADueDate),
    "#A19F9D",
    If(
        ThisItem.Status.Value = "Resolved" || ThisItem.Status.Value = "Closed",
        "#107C10",
        If(
            ThisItem.SLADueDate < Now(),
            "#A4262C",
            If(
                DateDiff(Now(), ThisItem.SLADueDate, TimeUnit.Hours) <= 4,
                "#D83B01",
                If(
                    DateDiff(Now(), ThisItem.SLADueDate, TimeUnit.Hours) <= 24,
                    "#CA5010",
                    "#107C10"
                )
            )
        )
    )
)
```

### SLA Text Label
```
If(
    IsBlank(ThisItem.SLADueDate),
    "No SLA",
    If(
        ThisItem.Status.Value = "Resolved" || ThisItem.Status.Value = "Closed",
        "Completed",
        If(
            ThisItem.SLADueDate < Now(),
            "OVERDUE by " & Text(DateDiff(ThisItem.SLADueDate, Now(), TimeUnit.Hours)) & "h",
            Text(DateDiff(Now(), ThisItem.SLADueDate, TimeUnit.Hours)) & "h remaining"
        )
    )
)
```

## Search Implementation

### Delegation-Safe Search
```
// Use StartsWith for delegation-safe search on indexed columns
// The search box OnChange triggers:
Set(varSearchText, Trim(txtSearch.Text));

// Gallery Items with search:
If(
    IsBlank(varSearchText),
    // No search — use standard filter
    Sort(
        Filter(Tickets, Status <> "Closed"),
        Created, SortOrder.Descending
    ),
    // With search — StartsWith is delegable for SharePoint
    Sort(
        Filter(
            Tickets,
            StartsWith(Title, varSearchText) || StartsWith(TicketID, varSearchText)
        ),
        Created, SortOrder.Descending
    )
)
```

### For non-delegable full-text search (small datasets only)
```
// Only use this if total tickets < 2000 (delegation threshold)
Filter(
    Tickets,
    varSearchText in Title || varSearchText in TicketID || varSearchText in Description
)
```

## Error Handling

### Safe Patch with Error Handling
```
Set(varIsSubmitting, true);
IfError(
    Patch(
        Tickets,
        Defaults(Tickets),
        {Title: txtTitle.Text, /* ... */}
    ),
    // Error handler
    Notify(
        "Failed to create ticket. Please try again. Error: " & FirstError.Message,
        NotificationType.Error
    );
    Set(varIsSubmitting, false),
    // Success handler
    Notify("Ticket created successfully!", NotificationType.Success);
    Set(varIsSubmitting, false);
    Navigate(scrDashboard)
)
```

### Loading States
```
// Show loading indicator during data operations
// Button template:
If(
    varIsSubmitting,
    "Submitting...",
    "Submit Ticket"
)
// DisplayMode:
If(varIsSubmitting, DisplayMode.Disabled, DisplayMode.Edit)
```

## Navigation

### Screen Navigation Patterns
```
// Navigate to ticket detail with context
Navigate(
    scrTicketDetail,
    ScreenTransition.None,
    {varSelectedTicket: ThisItem}
);

// Navigate back
Navigate(scrDashboard, ScreenTransition.None);

// Navigate with role-based routing
If(
    varIsAgent,
    Navigate(scrAdminQueue, ScreenTransition.None),
    Navigate(scrDashboard, ScreenTransition.None)
);
```

## Priority Button Group

### Visual Priority Selector
```
// For each priority button (e.g., btnPriorityHigh):
OnSelect: Set(varSelectedPriority, "High")
Fill: If(varSelectedPriority = "High", ColorValue("#D83B01"), ColorValue("#F3F2F1"))
Color: If(varSelectedPriority = "High", Color.White, ColorValue("#323130"))
BorderColor: If(varSelectedPriority = "High", ColorValue("#D83B01"), ColorValue("#E1DFDD"))
```

## Status Pill Component Properties

### Dynamic Fill Color
```
Switch(
    ThisItem.Status.Value,
    "New",                  ColorValue("#0078D4"),
    "Assigned",             ColorValue("#038387"),
    "In Progress",          ColorValue("#CA5010"),
    "Pending Requester",    ColorValue("#FFB900"),
    "Resolved",             ColorValue("#107C10"),
    "Closed",               ColorValue("#605E5C"),
    ColorValue("#D2D0CE")
)
```

### Dynamic Text Color
```
If(
    ThisItem.Status.Value = "Pending Requester",
    ColorValue("#323130"),
    Color.White
)
```

## Delegation Notes

SharePoint connector delegation limits:
- Default: 500 items, configurable up to 2000 in app settings
- **Delegable** operations: `=`, `<>`, `<`, `>`, `<=`, `>=`, `StartsWith`, `And`, `Or`, `Not`, `Filter`, `Sort`, `SortByColumns`, `In` (for column values)
- **Non-delegable**: `Search`, `LookUp` with complex expressions, `CountRows` on filtered galleries, text functions like `Mid`, `Len`, `Right`
- Always use `StartsWith` instead of `in` for text search on large lists
- Use `ClearCollect` to cache small reference lists (Categories, Agents) locally
