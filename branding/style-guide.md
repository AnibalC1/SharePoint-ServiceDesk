# Service Desk -- Branding & Style Guide

This document defines the visual language for the SharePoint Service Desk system. It applies to all surfaces: SharePoint pages, SPFx web parts, Power Apps screens, Adaptive Cards in Teams, and Power BI reports.

---

## 1. Color Palette

### 1.1 Primary Colors

| Name | Hex | RGB | Usage |
|---|---|---|---|
| Primary | `#0078D4` | 0, 120, 212 | Buttons, links, active states, navigation highlights |
| Primary Dark | `#106EBE` | 16, 110, 190 | Hover states, pressed buttons, secondary emphasis |
| Primary Darker | `#005A9E` | 0, 90, 158 | Header backgrounds, deep contrast areas |
| Primary Darkest | `#004578` | 0, 69, 120 | Suite bar, extreme contrast needs |
| Primary Light | `#C7E0F4` | 199, 224, 244 | Selected row highlights, focus outlines |
| Primary Lighter | `#DEECF9` | 222, 236, 249 | Hover backgrounds, info banners |
| Primary Lightest | `#EFF6FC` | 239, 246, 252 | Subtle backgrounds, alternating rows |

### 1.2 Accent

| Name | Hex | RGB | Usage |
|---|---|---|---|
| Accent / Teal | `#038387` | 3, 131, 135 | Secondary actions, accent borders, category badges |
| Accent Light | `#4BB4B7` | 75, 180, 183 | Hover state on accent elements |
| Accent Dark | `#006E6E` | 0, 110, 110 | Pressed state on accent elements |

### 1.3 Semantic Colors

| Name | Hex | RGB | Usage |
|---|---|---|---|
| Error / Critical | `#A4262C` | 164, 38, 44 | Error messages, critical priority, validation failures |
| Error Background | `#FDE7E9` | 253, 231, 233 | Error banners, critical alert backgrounds |
| Warning | `#FFB900` | 255, 185, 0 | Warning banners, pending states, SLA at-risk |
| Warning Background | `#FFF4CE` | 255, 244, 206 | Warning alert backgrounds |
| Success | `#107C10` | 16, 124, 16 | Resolved status, success messages, SLA met |
| Success Background | `#DFF6DD` | 223, 246, 221 | Success banners, resolved ticket highlights |
| Info | `#0078D4` | 0, 120, 212 | Informational banners (uses primary) |
| Info Background | `#EFF6FC` | 239, 246, 252 | Info banner backgrounds |

### 1.4 Neutral Colors

| Name | Hex | Usage |
|---|---|---|
| Black | `#000000` | Rarely used; extreme emphasis only |
| Neutral Dark | `#201F1E` | Headings (h1, h2) |
| Neutral Primary | `#323130` | Body text, primary labels |
| Neutral Primary Alt | `#3B3A39` | Secondary headings |
| Neutral Secondary | `#605E5C` | Subtitles, helper text, timestamps |
| Neutral Secondary Alt | `#8A8886` | Placeholder text, disabled icons |
| Neutral Tertiary | `#A19F9D` | Disabled text, muted labels |
| Neutral Tertiary Alt | `#C8C6C4` | Borders, dividers (subtle) |
| Neutral Quaternary | `#D2D0CE` | Borders (standard) |
| Neutral Quaternary Alt | `#E1DFDD` | Hover backgrounds (neutral) |
| Neutral Light | `#EDEBE9` | Dividers, separators, table borders |
| Neutral Lighter | `#F3F2F1` | Disabled backgrounds, alternate rows |
| Neutral Lightest Alt | `#FAF9F8` | Page background, surface background |
| White | `#FFFFFF` | Card backgrounds, input backgrounds |

### 1.5 Priority Colors

| Priority | Foreground | Background | Badge BG |
|---|---|---|---|
| Critical | `#FFFFFF` | `#A4262C` | `#A4262C` |
| High | `#FFFFFF` | `#D83B01` | `#D83B01` |
| Medium | `#FFFFFF` | `#0078D4` | `#0078D4` |
| Low | `#323130` | `#F3F2F1` | `#F3F2F1` |

### 1.6 Status Colors

| Status | Foreground | Background | Badge BG |
|---|---|---|---|
| New | `#FFFFFF` | `#0078D4` | `#0078D4` |
| Assigned | `#FFFFFF` | `#038387` | `#038387` |
| In Progress | `#FFFFFF` | `#CA5010` | `#CA5010` |
| Pending Requester | `#323130` | `#FFB900` | `#FFB900` |
| Resolved | `#FFFFFF` | `#107C10` | `#107C10` |
| Closed | `#FFFFFF` | `#605E5C` | `#605E5C` |

---

## 2. Typography

### 2.1 Font Family

| Role | Font Stack |
|---|---|
| Primary | `"Segoe UI", -apple-system, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif` |
| Monospace | `"Cascadia Code", "Fira Code", Consolas, "Courier New", monospace` |

### 2.2 Type Scale

| Token | Size | Weight | Line Height | Usage |
|---|---|---|---|---|
| `--font-size-hero` | 28px | 700 (Bold) | 36px | Dashboard hero numbers, KPI values |
| `--font-size-xxl` | 24px | 700 (Bold) | 32px | Page titles |
| `--font-size-xl` | 20px | 600 (Semibold) | 28px | Section headers |
| `--font-size-l` | 16px | 600 (Semibold) | 24px | Card titles, form section headers |
| `--font-size-m` | 14px | 400 (Regular) | 20px | Body text (default) |
| `--font-size-s` | 12px | 400 (Regular) | 16px | Captions, badges, helper text |
| `--font-size-xs` | 10px | 600 (Semibold) | 14px | Overline labels, micro-badges |

### 2.3 Font Weight Tokens

| Token | Weight | Usage |
|---|---|---|
| `--font-weight-regular` | 400 | Body text |
| `--font-weight-semibold` | 600 | Labels, column headers, emphasis |
| `--font-weight-bold` | 700 | Headings, KPI values |

### 2.4 Line Height Rules

- Body text: 1.5x font size (e.g., 14px text = 20px line height)
- Headings: 1.25x to 1.35x font size
- Single-line elements (badges, pills): 1.0x

---

## 3. Spacing

### 3.1 Base Unit

All spacing uses a 4px base unit.

| Token | Value | Usage |
|---|---|---|
| `--spacing-xxs` | 2px | Micro-adjustments, icon-to-text gap (tight) |
| `--spacing-xs` | 4px | Inline spacing, compact element padding |
| `--spacing-s` | 8px | Default gap between inline elements |
| `--spacing-m` | 12px | Form field gaps, small card padding |
| `--spacing-l` | 16px | Standard card padding, section gaps |
| `--spacing-xl` | 20px | Major section spacing |
| `--spacing-xxl` | 24px | Page-level vertical spacing between sections |
| `--spacing-xxxl` | 32px | Hero section padding, page margins |
| `--spacing-jumbo` | 48px | Major layout separations |

### 3.2 Layout Spacing Rules

- **Form fields:** 12px vertical gap between fields; 8px between label and input.
- **Cards:** 16px internal padding; 16px gap between cards in a grid.
- **Page sections:** 24px vertical spacing between major sections.
- **Inline elements:** 8px horizontal gap (e.g., badge groups, button rows).

---

## 4. Component Patterns

### 4.1 Pills / Badges

Used for Priority and Status indicators throughout the system.

```
Shape:       Rounded capsule (border-radius: 16px)
Padding:     4px 16px
Font:        12px / Semibold (600)
Min width:   70px
Text align:  Center
Shadow:      0 1px 4px rgba(color, 0.3) -- color matches badge background
```

**Priority badges:** Solid background with white text (except Low which uses neutral background with dark text).

**Status badges:** Solid background with white text (except Pending Requester which uses yellow background with dark text).

### 4.2 Cards

```
Background:     #FFFFFF
Border:         1px solid #EDEBE9
Border radius:  8px (use 4px for nested cards)
Padding:        16px
Shadow:         0 1.6px 3.6px rgba(0, 0, 0, 0.13), 0 0.3px 0.9px rgba(0, 0, 0, 0.11)
Shadow (hover): 0 3.2px 7.2px rgba(0, 0, 0, 0.13), 0 0.6px 1.8px rgba(0, 0, 0, 0.11)
Transition:     box-shadow 0.2s ease
```

**KPI Cards (Dashboard):**
```
Layout:      Number (hero size) + label below
Number:      28px / Bold / Neutral Dark (#201F1E)
Label:       12px / Semibold / Neutral Secondary (#605E5C)
Trend arrow: 12px icon, green (up-good) or red (up-bad)
```

### 4.3 Buttons

**Primary button:**
```
Background:     #0078D4
Text:           #FFFFFF, 14px, Semibold
Padding:        6px 20px
Border radius:  4px
Border:         none
Hover:          #106EBE
Active:         #005A9E
Focus:          2px solid #0078D4, 1px offset
Disabled:       Background #F3F2F1, Text #A19F9D
Min height:     32px
```

**Default (secondary) button:**
```
Background:     #FFFFFF
Text:           #323130, 14px, Semibold
Padding:        6px 20px
Border:         1px solid #8A8886
Border radius:  4px
Hover:          Background #F3F2F1
Active:         Background #EDEBE9
Focus:          2px solid #0078D4, 1px offset
```

**Danger button:**
```
Background:     #A4262C
Text:           #FFFFFF
Hover:          #8C2025
Active:         #751B1F
```

**Ghost / Link button:**
```
Background:     transparent
Text:           #0078D4
Hover:          Background #EFF6FC
```

### 4.4 Form Fields

```
Background:     #FFFFFF
Border:         1px solid #8A8886
Border radius:  4px
Padding:        6px 12px
Font:           14px / Regular
Height:         32px (single line)
Focus border:   2px solid #0078D4 (bottom only for underline style)
Error border:   1px solid #A4262C
Error text:     12px / #A4262C / below the field
Disabled:       Background #F3F2F1, border #C8C6C4
Placeholder:    #605E5C
Label:          12px / Semibold / #323130, 8px above input
Required mark:  " *" in #A4262C after label text
```

### 4.5 Avatars

```
Shape:          Circle
Sizes:          24px (compact), 32px (default), 40px (profile), 48px (detail)
Fallback:       Initials on colored background
Initial colors: Computed from user name hash, drawn from palette:
                #0078D4, #038387, #CA5010, #8764B8, #107C10, #D83B01
Font:           10px / 12px / 14px / 16px (matches size), Semibold, #FFFFFF
```

### 4.6 Tables / Lists

```
Header:             Background #FAF9F8, text #605E5C, 12px Semibold, uppercase
Row:                Background #FFFFFF, text #323130, 14px Regular
Row (alternate):    Background #FAF9F8
Row (hover):        Background #F3F2F1
Row (selected):     Background #EFF6FC, left border 3px solid #0078D4
Divider:            1px solid #EDEBE9
Cell padding:       8px 12px
```

---

## 5. Icons

### 5.1 Recommended Icon Set

Use **Fluent UI System Icons** (https://github.com/microsoft/fluentui-system-icons) for consistency with the Microsoft 365 ecosystem.

### 5.2 Key Icons

| Purpose | Fluent Icon Name | Usage |
|---|---|---|
| New ticket | `TicketDiagonal` | Create ticket buttons, new ticket form |
| Dashboard | `DataUsage` | Analytics navigation |
| Priority | `ArrowCircleUp` / `ArrowCircleDown` | Priority indicators |
| SLA clock | `Clock` | SLA due dates, time displays |
| Agent | `Person` | Agent assignment, profile |
| Department | `Building` | Department selectors |
| Status | `CircleSmall` (filled) | Status dot indicators |
| Search | `Search` | Search bars, ticket lookup |
| Filter | `Filter` | List filtering |
| Settings | `Settings` | Configuration panels |
| Notification | `Alert` | Notification badges |
| Attachment | `Attach` | File attachments |
| Comment | `Comment` | Ticket comments, notes |
| Escalation | `ArrowUpRight` | Escalation indicators |
| Warning | `Warning` | SLA breach, alerts |
| Checkmark | `CheckmarkCircle` | Resolved status, success |

### 5.3 Icon Sizing

| Context | Size | Notes |
|---|---|---|
| Inline with text | 16px | Aligned to text baseline |
| Navigation | 20px | Nav items, tab icons |
| Card icon | 24px | Card header icons |
| Hero | 28-32px | Page headers, empty states |
| Button icon | 16px | Left of button label, 8px gap |

### 5.4 Icon Color Rules

- Use `#323130` (neutral primary) for default icon state
- Use `#0078D4` (primary) for interactive/active icons
- Use `#605E5C` (neutral secondary) for muted/disabled icons
- Match semantic color for status icons (error, warning, success)

---

## 6. Responsive Breakpoints

| Breakpoint | Width | Target |
|---|---|---|
| xs (mobile) | < 480px | Mobile phones |
| s (mobile landscape) | 480px -- 639px | Phones in landscape |
| m (tablet) | 640px -- 1023px | Tablets, small laptops |
| l (desktop) | 1024px -- 1365px | Standard desktop |
| xl (wide) | 1366px -- 1919px | Wide desktop monitors |
| xxl (ultra-wide) | >= 1920px | Large / multi-monitor |

### Layout Rules

- **Mobile (< 640px):** Single column, stacked cards, hamburger nav, full-width form fields.
- **Tablet (640px -- 1023px):** Two-column grid, side panel collapses, compact table view.
- **Desktop (>= 1024px):** Multi-column grid (2-4 columns), persistent side navigation, full table view.
- **Card grid:** Use CSS Grid with `minmax(280px, 1fr)` for responsive card layouts.

---

## 7. Accessibility

### 7.1 WCAG AA Compliance

All color combinations must meet WCAG 2.1 AA contrast ratios:

| Element | Minimum Ratio | Standard |
|---|---|---|
| Normal text (< 18px) | 4.5:1 | AA |
| Large text (>= 18px bold or >= 24px) | 3:1 | AA |
| UI components and graphical objects | 3:1 | AA |

### 7.2 Verified Contrast Ratios

| Foreground | Background | Ratio | Pass |
|---|---|---|---|
| `#323130` on `#FFFFFF` | Body text on white | 14.7:1 | AA/AAA |
| `#605E5C` on `#FFFFFF` | Secondary text on white | 7.2:1 | AA/AAA |
| `#FFFFFF` on `#0078D4` | Button text on primary | 4.5:1 | AA |
| `#FFFFFF` on `#A4262C` | Text on error/critical | 6.5:1 | AA/AAA |
| `#FFFFFF` on `#107C10` | Text on success | 5.1:1 | AA |
| `#FFFFFF` on `#038387` | Text on accent | 4.6:1 | AA |
| `#323130` on `#FFB900` | Dark text on warning | 8.5:1 | AA/AAA |
| `#323130` on `#F3F2F1` | Text on low-priority badge | 12.6:1 | AA/AAA |
| `#FFFFFF` on `#D83B01` | Text on high-priority | 4.6:1 | AA |
| `#FFFFFF` on `#CA5010` | Text on in-progress | 4.5:1 | AA |
| `#FFFFFF` on `#605E5C` | Text on closed status | 5.0:1 | AA |

### 7.3 Accessibility Guidelines

- Never use color alone to convey meaning. Always pair color with text labels, icons, or patterns.
- All interactive elements must have visible focus indicators (2px solid `#0078D4`).
- Priority and status badges include text labels; color is supplementary.
- Maintain a minimum touch target of 44x44px for mobile interactions.
- All images and icons must have `alt` text or `aria-label`.
- Form fields must have associated `<label>` elements or `aria-label`.
- Data tables must use proper `<th>` headers with `scope` attributes.
- Support keyboard navigation: Tab for focus, Enter/Space for activation, Escape for dismiss.
- Respect `prefers-reduced-motion` by disabling animations when the user preference is set.
- Adaptive Cards include `speak` property for screen reader announcements.

---

## 8. Design Tokens

All design values are available as CSS custom properties in `css-tokens.css`. Reference that file from any SPFx web part, SharePoint page custom CSS, or embedded component.

Import example:

```css
@import url('/sites/ServiceDesk/SiteAssets/css-tokens.css');
```

SPFx web part usage:

```typescript
import styles from './ServiceDeskWebPart.module.scss';

// In SCSS:
// @import '../../../branding/css-tokens.css';
// .title { color: var(--sd-color-text-primary); }
```

See the companion file `branding/css-tokens.css` for the complete token reference.

---

## 9. Motion and Animation

| Property | Duration | Easing | Usage |
|---|---|---|---|
| Hover transitions | 200ms | ease | Background, shadow, border color |
| Expand/collapse | 250ms | ease-in-out | Panels, accordions, drawers |
| Fade in | 200ms | ease-in | Content appearing |
| Fade out | 150ms | ease-out | Content disappearing |
| Slide in | 300ms | cubic-bezier(0.1, 0.9, 0.2, 1) | Side panels, modals |

When `prefers-reduced-motion: reduce` is active, all durations collapse to 0ms and transforms are removed.

---

## 10. File Naming Conventions

| Asset Type | Pattern | Example |
|---|---|---|
| Icons (color) | `icon-color-{size}.png` | `icon-color-192x192.png` |
| Icons (outline) | `icon-outline-{size}.png` | `icon-outline-32x32.png` |
| Screenshots | `screenshot-{feature}-{size}.png` | `screenshot-dashboard-1024.png` |
| CSS | `kebab-case.css` | `css-tokens.css` |
| JSON configs | `kebab-case.json` | `ticket-notification.json` |
