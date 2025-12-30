## Scripts:

### getAD.ps1 -
Outputs the list of AD groups to `AD_Groups.csv`.
Outputs the list of AD users to `AD_Users.csv`.

NB - Group membership shows **direct membership**, i.e. which groups this group is directly a member of.
NB - Group membership also shows **nested membership**, i.e. all groups a user belongs to including nested groups. This means the user may not be added directly but is included through another group (groups within groups).

The fields `PrimarySMTPkasutus` and `ProxyKasutus` are reserved for use by a separate script that checks whether an email address was used in the last 90 days.


### getGPO_CSV.ps1

This script inventories GPOs (Group Policy Objects) in the domain: it fetches all GPOs, generates an XML report for each (`Get-GPOReport -All -ReportType Xml`), parses it and saves a summary table to CSV (`GPO_Report.csv`).

For each GPO the report shows name, GUID, description, modified date, status, where the GPO is linked (Links/LinkCount/Scope), how many "settings sections" are found in the XML (`SettingsCount`) and which principals are present in Security Filtering (who can `Apply Group Policy`).

* **LinkCount** — number of times this GPO is **linked** to AD objects. Calculated by counting `SOMPath` entries in the XML: each OU/site/domain root where the GPO is applied increases the count by 1.

* **SettingsCount** — number of `ExtensionData` blocks found in the report, i.e. **how many "sections/types of settings"** the GPO contains (for example Security/Registry/Scripts/Preferences, etc.). This is **not** the number of individual settings; one block can contain many policy items.


### getGPO_XMLS.ps1

This script exports all GPOs to individual XML files.

- Creates a `GPO_XML` folder next to the script,
- Gets all GPOs via `Get-GPO -All`,
- For each GPO generates an XML report via `Get-GPOReport ... -Path <file>.xml` (filename is made "safe" by replacing invalid characters).

Result: one XML file per GPO in `GPO_XML`, convenient for manual inspection/search/archive.

### getExchange_shared.ps1 (runs about 10 minutes)

This script for **Exchange Online** connects to EXO, collects **all shared mailboxes** and exports them to `Exchange_SharedMailboxes.csv`.

* For each shared mailbox it retrieves **statistics** (`LastLogonTime`, mailbox size in MB), a list of aliases/addresses (`ProxyAddresses` from `EmailAddresses`), creation date, and permissions: who has **FullAccess** (`Get-MailboxPermission`), who has **SendAs** (`Get-RecipientPermission`) and who is in **SendOnBehalf** (`GrantSendOnBehalfTo`).
* The output is an inventory of shared mailboxes: addresses + size/last logon + who has access/send-as/send-on-behalf permissions.

### getExchange.ps1

This is a large inventory script for **Exchange Online** that connects to EXO and exports several object types to CSV (each to its own file).

* **1) Distribution Groups** (`Exchange_DistributionGroups.csv`): name/alias/primary SMTP, proxy addresses, `IsDirSynced`, managers (`ManagedBy`), list of **members** (with attempts to resolve member emails by different methods), member count, member types, creation date.
* **2) Microsoft 365 Groups** (`Exchange_M365Groups.csv`): similar fields but for M365 groups — owners (as `ManagedBy`), members, `AccessType`, SharePoint site URL, GUID and `ExternalDirectoryObjectId`.
* **3) Dynamic Distribution Groups** (`Exchange_DynamicGroups.csv`): name/addresses + `RecipientFilter` (rule used to build the dynamic group), `ManagedBy`, creation date.
* **4) Mailboxes (non-shared)** (`Exchange_Mailboxes.csv`): list of normal mailboxes/recipient types (`RecipientTypeDetails`), primary SMTP, proxy addresses, creation date.

In short: it performs a full export of Exchange Online groups and mail objects so you can analyze membership, addresses, owners, and dynamic group filters in Excel.


### getSP_combined.ps1

This script creates a consolidated CSV report of SharePoint Online sites by combining:

1. **Usage/activity for the last 30 days** from Microsoft Graph Reports (`Get-MgReportSharePointSiteUsageDetail -Period D30`) — last activity date, page views, number of files, etc.
2. **Administrative site properties** from SharePoint Online Admin (`Get-SPOSite`) — Title/Url/GUID, owner, template, storage used, sharing, lock state, Teams connection, etc.

It then **matches** records by `SiteId` (GUID) and writes the result to `SP_Sites.csv`. Sites that appear in the usage log but are not returned by `Get-SPOSite` are also included and marked as `!!!!_not in SP - only in Activity log!!!`.

### getSP_personal.ps1
This script exports **personal sites (OneDrive / MySite)** from SharePoint Online Admin to CSV.

* It retrieves all sites via `Get-SPOSite -IncludePersonalSite $true`, then filters personal sites by template `SPSPERS*` or by domain `*-my.sharepoint.com*`.
* For each personal site it writes to `SP_SitesPersonal.csv` key fields: `Title/Url/GUID/Owner`, `LastContentModifiedDate`, template, storage used in GB, sharing/lock state and Teams-related indicators (usually empty/not applicable for OneDrive).


## Support scripts

### _export_Excel_ALL.ps1
This is a "report aggregator" script that merges CSV files into a single Excel workbook.

* It takes a list of CSV files (`$csvFiles`), creates an Excel file with a timestamp `_FullView_YYYY-MM-DD_HH-mm.xlsx` and for **each CSV** creates a separate sheet: sheet name = filename without `.csv`.
* Then `Import-Csv -Delimiter ";" | Export-Excel ... -Append` (module **ImportExcel**) writes the data to the sheet as a table (TableName = sheet name, style `Medium2`).
* Finally it prints `ready <filename>`. A commented block shows how to open the file later and add comments/formulas/edit cells.

Notes/risks:

* If you run it again with the same timestamp (within the same minute) and the file already exists, `-Append` may cause table/sheet conflicts.
* `TableName` in Excel must be unique and "safe"; long file names or names with spaces/dashes/brackets may need to be sanitized (also keep sheet names within ~31 characters).


### _getClassicSitesWithAdmins.ps1
This script for **SharePoint Online Admin** generates a CSV report of people/groups that have admin/owner rights on *classic sites*.

* It retrieves sites (`Get-SPOSite`), keeps templates **SITEPAGEPUBLISHING#0, STS#0, STS#3** (classic sites/team sites), and for each site extracts users/groups via `Get-SPOUser -Site <url>`.
* It filters to "active" principals — **site admins** or users who belong to groups with names like *administraatorid / redigeerijad / omanikud / owners* (admins/editors/owners), removes system accounts (app@sharepoint, `SHAREPOINT\system`, `Everyone`, etc.) and writes `SP_SiteAdmins_Filtered.csv` with rows: site, template, site owner, DisplayName/LoginName, flags `IsSiteAdmin/IsGroup` and list of groups.

Note: this collects elevated roles (admins/owners/editors), not regular members; there is a commented block showing how to collect Members/Visitors instead.


### _getClassicSitesWithMembers.ps1
This one is similar but collects **regular members/visitors** for classic sites.

* Selects classic site templates `SITEPAGEPUBLISHING#0`, `STS#0`, `STS#3`.
* For each site runs `Get-SPOUser -Site <url>`, then filters users/groups where `Groups` contains words **külastajad / visitors / members / liikmed** (visitors/members). System accounts are removed and results are written to `SP_SiteUsers_Filtered.csv`.

Note: the filter depends on group names (language/custom names). If groups are named differently (e.g. "Site Members" or site-specific group names) some members may be missed.


### _merge_ClassicSitesMembersCount.ps1
This script **enriches** the main SharePoint sites report (`SP_Sites.csv`) by adding two numbers: how many **Members** and how many **Admins** were found on each site (based on the two separate exports).

* It reads `SP_SiteUsers_Filtered.csv`, removes placeholder rows `"-"`, groups by `SiteUrl` and calculates `MembersCount` per site. It does the same for `SP_SiteAdmins_Filtered.csv` to get `AdminsCount`.
* Then it opens `SP_Sites.csv` and for sites with templates `SITEPAGEPUBLISHING#0` and `STS#3` fills these counts (if no data — sets 0), prints progress and saves `SP_Sites_WithCounts.csv`.

Notes:

* Currently it updates only templates `SITEPAGEPUBLISHING#0` and `STS#3` (skips `STS#0`) — if this is unintended, add `STS#0`.
* Matching is done by `$s.Url` ↔ `SiteUrl` (string equality). Differences in trailing slashes or case may prevent matches.


### _merge_SP_m365.ps1
This script takes `SP_Sites_WithCounts.csv` and merges Microsoft 365 Group data from `Exchange_M365Groups.csv`, but **only for sites with template `GROUP#0`** (sites tied to an M365 Group).

* For each `GROUP#0` site it searches M365 groups by URL (`SharePointSiteUrl == s.Url` or `SiteUrl == s.Url`). If a match is found it reads `ManagedBy`, counts owners as `AdminsCount`, and takes `MembersCount` from the M365 CSV, writing both back to the site.
* If no match is found, it sets `AdminsCount=0` and `MembersCount=0`. Result saved as `SP_Sites_WithCounts_Final.csv`.

Notes:

* `ManagedBy` in the M365 CSV represents owners; counting them as `AdminsCount` is logical, but they are **group owners**, not necessarily SPO site admins.
* URL matching is sensitive to small differences (trailing slash, case). Comparing lower-case and trimming trailing `/` can help.


### _mergeMaildata.ps1
This script enriches a CSV (currently `Exchange_SharedMailboxes.csv`) by filling the `ProxyKasutus` column using a reference `_mails.csv`.

* `_mails.csv` is read as table `mail → kasutus` and stored in a hash map (`$mailMap`) for fast lookup (case-insensitive).
* In the target file it splits `ProxyAddresses` into individual addresses (separators `&`, `,`, `;`), and if any address matches `_mails.csv`:
  * if `kasutus` is empty / `not active` / `error` → it's not counted as active,
  * if there is a valid value → sets **`ProxyKasutus = "active"`** (dates are normalized to simply "active" in this workflow).
* If **no** proxy address is found in `_mails.csv` → leaves `ProxyKasutus` empty.
  If addresses were found but all were inactive/empty/error → sets `ProxyKasutus = "no activity"`.
* The script overwrites the original CSV (`$outFile = "$usersFile"`).


### _setAdminSelfClassicSites.ps1
This script for **SharePoint Online Admin** dumps all users/groups that have access to selected classic sites and writes them to CSV.

* It fetches all sites via `Get-SPOSite -Limit All`, keeps templates `SITEPAGEPUBLISHING#0` and `STS#3`, lists them in the console, and for each site runs `Get-SPOUser -Site <url>` and writes `SiteUrl`, `DisplayName`, `LoginName`, flags `IsSiteAdmin`, `IsGroup` and `Groups`.
* Output is `SP_SiteUsers_allFull.csv`. A commented block with `Set-SPOUser ... -IsSiteCollectionAdmin $true` is an attempt to **add yourself as Site Collection Admin on all these sites** (dangerous; it is good that it is commented out).


### check.ps1
This Exchange Online script reads `_mails.csv` (`mail;kasutus`) and fills email activity based on Message Trace for the last **90 days**.

* For each `mail` it first checks whether the address exists in Exchange (`Get-Recipient`). If not found — sets `kasutus = "error"` and saves progress.
* If the address exists — it searches backwards in 10-day windows using `Get-MessageTraceV2 -RecipientAddress <email>`; when it finds messages it records the last message date (`Received`) in `yyyy-MM-dd` format. If no messages are found in the period — writes `not active`.
* The script saves progress after each address, uses random pauses and waits (on errors) to avoid hitting API rate limits.

Result: `_mails.csv` becomes a lookup table `email → last activity / not active / error`, which other scripts use to fill `ProxyKasutus`.


### inserttodb.ps1
This script **adds missing email addresses** from `newmails.csv` into the main `mails.csv`.

* It reads `mails.csv` (format `mail;kasutus`), normalizes `mail` (trim + lower-case), then reads `newmails.csv` as a list of emails (one per line).
* For each new email that is **not already** in `mails.csv` it creates a record `{ mail = email; kasutus = "" }` and appends it.
* Finally it rewrites `mails.csv` with the updated list and prints how many addresses were added.
