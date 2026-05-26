# Power Automate Common Expressions Reference

All expressions, OData filters, and patterns used across the Service Desk flows.

## Date/Time Calculations

### Current UTC Time
```
utcNow()
```

### Add SLA Hours to Created Date
```
addHours(triggerOutputs()?['body/Created'], int(body('Get_Category')?['SLAHours']))
```

### SLA Due Date with Business Hours Only (skip weekends)
```
// Calculate SLA due accounting for weekends
// If created on Friday at 5pm with 8-hour SLA, due Monday 5pm
addHours(
  if(
    equals(dayOfWeek(triggerOutputs()?['body/Created']), 6),
    addDays(triggerOutputs()?['body/Created'], 2),
    if(
      equals(dayOfWeek(triggerOutputs()?['body/Created']), 0),
      addDays(triggerOutputs()?['body/Created'], 1),
      triggerOutputs()?['body/Created']
    )
  ),
  int(body('Get_Category')?['SLAHours'])
)
```

### Check if Date is Overdue
```
less(
  formatDateTime(items('Apply_to_each')?['SLADueDate'], 'yyyy-MM-ddTHH:mm:ssZ'),
  utcNow()
)
```

### Time Until SLA Breach (in hours)
```
div(
  sub(
    ticks(items('Apply_to_each')?['SLADueDate']),
    ticks(utcNow())
  ),
  36000000000
)
```

### Format Date for Display
```
formatDateTime(triggerOutputs()?['body/Created'], 'MMM dd, yyyy hh:mm tt')
```

### Calculate Resolution Time in Hours
```
div(
  sub(
    ticks(body('Get_Ticket')?['ResolutionDate']),
    ticks(body('Get_Ticket')?['Created'])
  ),
  36000000000
)
```

## String Formatting

### Generate Ticket ID
```
concat('INC-', formatNumber(int(body('Get_Counter')?['Value']), '0000'))
```

### Build Email Subject with Ticket ID
```
concat('[', body('Get_Ticket')?['TicketID'], '] ', body('Get_Ticket')?['Title'])
```

### Truncate Long Text for Notifications
```
if(
  greater(length(triggerOutputs()?['body/Description']), 200),
  concat(substring(triggerOutputs()?['body/Description'], 0, 200), '...'),
  triggerOutputs()?['body/Description']
)
```

### Strip HTML Tags from Rich Text
```
// Basic HTML stripping for plain-text emails
replace(
  replace(
    replace(
      triggerOutputs()?['body/Description'],
      '<br>', ' '
    ),
    '<br/>', ' '
  ),
  '<[^>]+>', ''
)
```

### Priority Display with Emoji
```
concat(
  if(equals(body('Get_Ticket')?['Priority']?['Value'], 'Critical'), '🔴 ',
  if(equals(body('Get_Ticket')?['Priority']?['Value'], 'High'), '🟠 ',
  if(equals(body('Get_Ticket')?['Priority']?['Value'], 'Medium'), '🔵 ',
  '⚪ '))),
  body('Get_Ticket')?['Priority']?['Value']
)
```

## OData Filter Queries

### Open Tickets (not resolved or closed)
```
Status ne 'Resolved' and Status ne 'Closed'
```

### Overdue Tickets
```
SLADueDate lt '@{utcNow()}' and Status ne 'Resolved' and Status ne 'Closed'
```

### Tickets by Department
```
Department eq 'IT' and Status ne 'Closed'
```

### My Assigned Tickets
```
AssignedTo/EMail eq '@{body('Get_my_profile_(V2)')?['mail']}'
```

### Active Agents in Department
```
Department eq '@{triggerOutputs()?['body/Department']?['Value']}' and IsActive eq 1
```

### Categories by Department
```
Department eq '@{triggerOutputs()?['body/Department']?['Value']}' and IsActive eq 1
```

### Tickets Approaching SLA (within 4 hours)
```
SLADueDate ge '@{utcNow()}' and SLADueDate le '@{addHours(utcNow(), 4)}' and Status ne 'Resolved' and Status ne 'Closed'
```

### Tickets by Escalation Level
```
EscalationLevel ge 1 and Status ne 'Resolved' and Status ne 'Closed'
```

### Tickets Created Today
```
Created ge '@{startOfDay(utcNow())}'
```

### Tickets Created This Week
```
Created ge '@{addDays(utcNow(), mul(-1, dayOfWeek(utcNow())))}'
```

## Condition Expressions

### Check if Ticket is Overdue
```
@less(formatDateTime(items('Apply_to_each')?['SLADueDate'], 'yyyy-MM-ddTHH:mm:ssZ'), utcNow())
```

### Check Status is Open
```
@and(
  not(equals(triggerOutputs()?['body/Status']?['Value'], 'Resolved')),
  not(equals(triggerOutputs()?['body/Status']?['Value'], 'Closed'))
)
```

### Check if Priority Changed
```
@not(equals(
  triggerOutputs()?['body/Priority']?['Value'],
  triggerOutputs()?['body/{VersionTag}']}
))
```

### Route by Department
```
// Use a Switch action with this expression:
triggerOutputs()?['body/Department']?['Value']

// Cases: IT, HR, Operations, Finance, Facilities
```

### Check if Agent Has Capacity
```
@less(
  int(body('Get_Agent_Ticket_Count')),
  int(items('Loop_Through_Agents')?['MaxTickets'])
)
```

## Dynamic Content References

### Trigger Outputs (When item is created)
```
// Title
triggerOutputs()?['body/Title']

// Department choice value
triggerOutputs()?['body/Department']?['Value']

// Requester email
triggerOutputs()?['body/Requester']?['Email']

// Requester display name
triggerOutputs()?['body/Requester']?['DisplayName']

// Item ID
triggerOutputs()?['body/ID']

// Created date
triggerOutputs()?['body/Created']

// Category lookup ID
triggerOutputs()?['body/Category']?['Id']

// Priority choice value
triggerOutputs()?['body/Priority']?['Value']
```

### Get Item Outputs
```
// After a "Get item" action named "Get_Ticket":
body('Get_Ticket')?['TicketID']
body('Get_Ticket')?['Status']?['Value']
body('Get_Ticket')?['AssignedTo']?['Email']
body('Get_Ticket')?['SLADueDate']
body('Get_Ticket')?['EscalationLevel']
```

## Email Templates

### New Ticket Confirmation (HTML)
```html
<div style="font-family: 'Segoe UI', sans-serif; max-width: 600px; margin: 0 auto;">
  <div style="background: #0078D4; color: white; padding: 20px; border-radius: 8px 8px 0 0;">
    <h2 style="margin: 0;">Service Desk</h2>
    <p style="margin: 4px 0 0; opacity: 0.9;">Ticket Confirmation</p>
  </div>
  <div style="padding: 24px; background: #fff; border: 1px solid #E1DFDD; border-top: none; border-radius: 0 0 8px 8px;">
    <p>Hi @{triggerOutputs()?['body/Requester']?['DisplayName']},</p>
    <p>Your ticket has been received and assigned ID <strong style="font-family: 'Cascadia Code', monospace; color: #0078D4;">@{body('Update_Ticket_ID')?['TicketID']}</strong>.</p>
    <table style="width: 100%; border-collapse: collapse; margin: 16px 0;">
      <tr><td style="padding: 8px; color: #605E5C; width: 120px;">Title</td><td style="padding: 8px; font-weight: 600;">@{triggerOutputs()?['body/Title']}</td></tr>
      <tr style="background: #FAF9F8;"><td style="padding: 8px; color: #605E5C;">Department</td><td style="padding: 8px;">@{triggerOutputs()?['body/Department']?['Value']}</td></tr>
      <tr><td style="padding: 8px; color: #605E5C;">Priority</td><td style="padding: 8px;">@{triggerOutputs()?['body/Priority']?['Value']}</td></tr>
      <tr style="background: #FAF9F8;"><td style="padding: 8px; color: #605E5C;">Status</td><td style="padding: 8px;">New</td></tr>
    </table>
    <p>We'll keep you updated as your ticket progresses. You can track your ticket in the <a href="https://yourtenant.sharepoint.com/sites/servicedesk" style="color: #0078D4;">Service Desk Portal</a>.</p>
    <p style="color: #605E5C; font-size: 13px; margin-top: 24px; padding-top: 16px; border-top: 1px solid #E1DFDD;">This is an automated message from the Service Desk system.</p>
  </div>
</div>
```

### Status Change Notification (HTML)
```html
<div style="font-family: 'Segoe UI', sans-serif; max-width: 600px; margin: 0 auto;">
  <div style="background: #0078D4; color: white; padding: 20px; border-radius: 8px 8px 0 0;">
    <h2 style="margin: 0;">Ticket Update</h2>
    <p style="margin: 4px 0 0; opacity: 0.9;">@{body('Get_Ticket')?['TicketID']}</p>
  </div>
  <div style="padding: 24px; background: #fff; border: 1px solid #E1DFDD; border-top: none; border-radius: 0 0 8px 8px;">
    <p>Hi @{body('Get_Ticket')?['Requester']?['DisplayName']},</p>
    <p>Your ticket <strong>@{body('Get_Ticket')?['Title']}</strong> has been updated:</p>
    <div style="background: #FAF9F8; padding: 16px; border-radius: 8px; margin: 16px 0; text-align: center;">
      <span style="display: inline-block; padding: 6px 16px; border-radius: 16px; background: #605E5C; color: white; font-weight: 600; font-size: 13px;">@{body('Get_Previous_Version')?['Status']?['Value']}</span>
      <span style="margin: 0 12px; color: #605E5C;">→</span>
      <span style="display: inline-block; padding: 6px 16px; border-radius: 16px; background: #0078D4; color: white; font-weight: 600; font-size: 13px;">@{triggerOutputs()?['body/Status']?['Value']}</span>
    </div>
    <p style="color: #605E5C; font-size: 13px; margin-top: 24px; padding-top: 16px; border-top: 1px solid #E1DFDD;">This is an automated message from the Service Desk system.</p>
  </div>
</div>
```

## Error Handling (Try-Catch Scope Pattern)

### Structure
```
Scope: "Try"
  → Actions that might fail
  → Configure Run After: Succeeded

Scope: "Catch"
  → Configure Run After: has Failed, has Timed Out, is Skipped
  → Get error: result('Try')?['error']?['message']
  → Send alert email / log to error list
  → Terminate with "Failed" status

Scope: "Finally"
  → Configure Run After: Succeeded, has Failed, has Timed Out, is Skipped
  → Cleanup actions (reset variables, etc.)
```

### Get Error Details
```
// Inside Catch scope:
result('Try')?['error']?['code']
result('Try')?['error']?['message']

// For actions in a loop:
actions('Update_item')?['outputs']?['body']?['error']?['message']
```

## Concurrency Control

### Flow Settings for Critical Flows
```json
{
  "operationOptions": "DisableAsyncPattern",
  "concurrency": {
    "runs": 1
  },
  "retryPolicy": {
    "type": "exponential",
    "count": 3,
    "interval": "PT5S",
    "minimumInterval": "PT5S",
    "maximumInterval": "PT1H"
  }
}
```

### Ticket ID Generator — Must Run Sequentially
Set concurrency to 1 on the trigger to prevent duplicate IDs:
- Trigger Settings → Concurrency Control → On → Degree of Parallelism: 1

### SLA Escalation — Can Run Concurrently
Apply to Each loop parallelism: 20 (default) for processing multiple tickets simultaneously.

## Adaptive Card Action Handling

### Action.Execute Response
```json
{
  "statusCode": 200,
  "type": "application/vnd.microsoft.card.adaptive",
  "value": {
    "type": "AdaptiveCard",
    "body": [
      {
        "type": "TextBlock",
        "text": "✅ Ticket @{body('Get_Ticket')?['TicketID']} assigned to you.",
        "weight": "Bolder",
        "color": "Good"
      }
    ],
    "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
    "version": "1.5"
  }
}
```

## Useful Utility Expressions

### Generate Random 6-Character Reference
```
substring(guid(), 0, 6)
```

### Check if String Contains Value
```
contains(toLower(triggerOutputs()?['body/Subject']), 'urgent')
```

### Null-Safe Field Access
```
coalesce(triggerOutputs()?['body/AssignedTo']?['Email'], 'unassigned@company.com')
```

### Convert SharePoint Person to Email
```
triggerOutputs()?['body/Requester']?['Email']
```

### Build SharePoint Item URL
```
concat(
  'https://yourtenant.sharepoint.com/sites/servicedesk/Lists/Tickets/DispForm.aspx?ID=',
  string(triggerOutputs()?['body/ID'])
)
```
