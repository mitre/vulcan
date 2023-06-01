# Vulcan v2.1.3

### Exciting New Features 🎉
* VULCAN-551: Enabling SMTP feature to send emails via ActionMailer by @smarlaku820 in https://github.com/mitre/vulcan/pull/584
* VULCAN-570: Control View Only and Edit Mode UX refactor by @vanessuniq in https://github.com/mitre/vulcan/pull/583
### Other Changes
* VULCAN-579: Fix project update logic for detecting name changes correctly by @smarlaku820 in https://github.com/mitre/vulcan/pull/580
* VULCAN-581: Enhance Import from Spreadsheet workflow  by @vanessuniq in https://github.com/mitre/vulcan/pull/582

# Vulcan v2.1.2

### Exciting New Features 🎉
* VULCAN-563: Export/Import inspec control body by @vanessuniq in https://github.com/mitre/vulcan/pull/564
* Enabled editing component STIG ID prefix by @vanessuniq in https://github.com/mitre/vulcan/pull/558
### Other Changes
* Group histories with the same name, created_at, and comment; add tooltip for rule status by @vanessuniq in https://github.com/mitre/vulcan/pull/562
* Adding the option to group/sort controls by SrG ID by @vanessuniq in https://github.com/mitre/vulcan/pull/566
* VULCAN- 565: Add latest release version tag to Navbar component by @vanessuniq in https://github.com/mitre/vulcan/pull/567
* VULCAN-559: Support for Multiple CCIs by @vanessuniq in https://github.com/mitre/vulcan/pull/569

# vulcan v2.1.1

### 👒 Dependencies
* Bump rack from 2.2.6.3 to 2.2.6.4 by @dependabot in https://github.com/mitre/vulcan/pull/548
* Bump nokogiri from 1.14.2 to 1.14.3 by @dependabot in https://github.com/mitre/vulcan/pull/554
### Other Changes
* VULCAN-348: Aternative testing by @vanessuniq in https://github.com/mitre/vulcan/pull/546
* Customized parser to not interpret character/html entity by @vanessuniq in https://github.com/mitre/vulcan/pull/550
* VULCAN-372: Add additional component question of url type by @freddyfeelgood in https://github.com/mitre/vulcan/pull/553
* Up to deep linking by @vanessuniq in https://github.com/mitre/vulcan/pull/552
* Use title for description if description blank by @rlakey in https://github.com/mitre/vulcan/pull/557

# Vulcan v2.1.0

### Exciting New Features 🎉
* Enable XCCDF export of a single component by @vanessuniq in https://github.com/mitre/vulcan/pull/511
* VULCAN-496: Completed #496 by @vanessuniq in https://github.com/mitre/vulcan/pull/523
* Added Filtering capability to SRG dropdown by @freddyfeelgood in https://github.com/mitre/vulcan/pull/526:
* Feature DISA Export Excel complete with tests by @smarlaku820 in https://github.com/mitre/vulcan/pull/529
* Disallow new project creation if not admin by default by @smarlaku820 in https://github.com/mitre/vulcan/pull/539
* Created an ENV variable for controlling USER registrations on Vulcan app (Enabled by Default) by @smarlaku820 in https://github.com/mitre/vulcan/pull/535
* Added OIDC Integration capability for Vulcan by @smarlaku820 in https://github.com/mitre/vulcan/pull/540
* VULCAN-389: Integrate Slack With Vulcan by @smarlaku820 in https://github.com/mitre/vulcan/pull/549
### 👒 Dependencies
* Bump nokogiri from 1.13.4 to 1.13.5 by @dependabot in https://github.com/mitre/vulcan/pull/435
* Bump nokogiri from 1.13.5 to 1.13.6 by @dependabot in https://github.com/mitre/vulcan/pull/437
* Bump rack from 2.2.3 to 2.2.3.1 by @dependabot in https://github.com/mitre/vulcan/pull/439
* Bump eventsource from 1.1.0 to 1.1.1 by @dependabot in https://github.com/mitre/vulcan/pull/440
* Bump rails-html-sanitizer from 1.4.2 to 1.4.3 by @dependabot in https://github.com/mitre/vulcan/pull/446
* Bump terser from 4.8.0 to 4.8.1 by @dependabot in https://github.com/mitre/vulcan/pull/450
* Bump moment from 2.29.2 to 2.29.4 by @dependabot in https://github.com/mitre/vulcan/pull/451
* Bump omniauth from 1.9.1 to 1.9.2 by @dependabot in https://github.com/mitre/vulcan/pull/466
* Bump express from 4.17.1 to 4.18.2 by @dependabot in https://github.com/mitre/vulcan/pull/506
* Bump nokogiri from 1.13.6 to 1.13.10 by @dependabot in https://github.com/mitre/vulcan/pull/508
* Bump minimatch from 3.0.4 to 3.1.2 by @dependabot in https://github.com/mitre/vulcan/pull/507
* Bump loader-utils from 1.4.0 to 1.4.2 by @dependabot in https://github.com/mitre/vulcan/pull/500
* Bump loofah from 2.18.0 to 2.19.1 by @dependabot in https://github.com/mitre/vulcan/pull/509
* Bump decode-uri-component from 0.2.0 to 0.2.2 by @dependabot in https://github.com/mitre/vulcan/pull/502
* Bump rails-html-sanitizer from 1.4.3 to 1.4.4 by @dependabot in https://github.com/mitre/vulcan/pull/510
* Bump globalid from 1.0.0 to 1.0.1 by @dependabot in https://github.com/mitre/vulcan/pull/521
* Bump json5 from 1.0.1 to 1.0.2 by @dependabot in https://github.com/mitre/vulcan/pull/513
* Bump rack from 2.2.4 to 2.2.6.2 by @dependabot in https://github.com/mitre/vulcan/pull/520
* Bump omniauth and gitlab_omniauth-ldap by @dependabot in https://github.com/mitre/vulcan/pull/541
* Bump omniauth-rails_csrf_protection Gem by @smarlaku820 in https://github.com/mitre/vulcan/pull/543
* Bump rack from 2.2.6.2 to 2.2.6.3 by @dependabot in https://github.com/mitre/vulcan/pull/545
### Other Changes
* VULCAN-429: Fix deleting a control prevents the deleting of the component by @timwongj in https://github.com/mitre/vulcan/pull/430
* VULCAN-433: Modify rules_count to exclude deleted rules by @timwongj in https://github.com/mitre/vulcan/pull/436
* VULCAN-414: Sort displayed components by @timwongj in https://github.com/mitre/vulcan/pull/434
* VULCAN-301: Display loading... when uploading SRG by @timwongj in https://github.com/mitre/vulcan/pull/431
* VULCAN-298: SRG page enhancements by @timwongj in https://github.com/mitre/vulcan/pull/428
* VULCAN-362: Account for controls marked as duplicate on existing SRG content import by @timwongj in https://github.com/mitre/vulcan/pull/427
* VULCAN-419: Sort Inspec tags by @timwongj in https://github.com/mitre/vulcan/pull/432
* fix add new control by @timwongj in https://github.com/mitre/vulcan/pull/443
* VULCAN-454: Implement find and replace by @timwongj in https://github.com/mitre/vulcan/pull/455
* VULCAN-410: Swap diff view comparison by @sgober in https://github.com/mitre/vulcan/pull/441
* VULCAN-415: Show version and release for overlaid components suggestions by @timwongj in https://github.com/mitre/vulcan/pull/438
* VULCAN-445: Title box visibility by @timwongj in https://github.com/mitre/vulcan/pull/456
* VULCAN-449: Fix mark as duplicate for proj/comp admin/authors by @timwongj in https://github.com/mitre/vulcan/pull/460
* VULCAN-457: Add tooltip for mark as duplicate by @timwongj in https://github.com/mitre/vulcan/pull/459
* VULCAN-447: Enable context-aware popover help icons, depending on Status field by @timwongj in https://github.com/mitre/vulcan/pull/461
* VULCAN-448: Add concept of compensating controls and POA&M statuses to Applicable - Does Not Meet status by @timwongj in https://github.com/mitre/vulcan/pull/462
* VULCAN-452: Review workflow improvements by @timwongj in https://github.com/mitre/vulcan/pull/464
* VULCAN-448: mitigations are always shown by @timwongj in https://github.com/mitre/vulcan/pull/465
*  VULCAN-470: change the color of the mark as duplicate button by @vanessuniq in https://github.com/mitre/vulcan/pull/482
* VULCAN-475: fixes #475 by @wdower in https://github.com/mitre/vulcan/pull/477
* Add GitHub logo to README by @ChrisHinchey in https://github.com/mitre/vulcan/pull/481
* Fix GitHub logo in README by @ChrisHinchey in https://github.com/mitre/vulcan/pull/485
* Update push-to-docker.yml by @vanessuniq in https://github.com/mitre/vulcan/pull/489
* Debugged: added the missing currentUserId prop to RuleEditorHeader co… by @vanessuniq in https://github.com/mitre/vulcan/pull/486
* VULCAN-501: copy component fails when selecting a newer srg version and a control has been previously deleted in the source component by @vanessuniq in https://github.com/mitre/vulcan/pull/503
* VULCAN-495: export to excel does not work if components have the same name by @vanessuniq in https://github.com/mitre/vulcan/pull/505
* VULCAN-517: update SRG info on control view by @rlakey in https://github.com/mitre/vulcan/pull/519
* VULCAN-315: added toggle for stig id to srg id by @rlakey in https://github.com/mitre/vulcan/pull/516
* Properly using #dup method for expected behavior: by @vanessuniq in https://github.com/mitre/vulcan/pull/522
* VULCAN-524: fix answer cloning issue by @rlakey in https://github.com/mitre/vulcan/pull/525
* VULCAN-530: populate gid and rid in inspec body data by @rlakey in https://github.com/mitre/vulcan/pull/533
* VULCAN-531: fix for copy comp w new srg for vuln disc by @rlakey in https://github.com/mitre/vulcan/pull/532
* Sorted excel output and misc bug fixes by @rlakey in https://github.com/mitre/vulcan/pull/537

# Vulcan v2.0.0
