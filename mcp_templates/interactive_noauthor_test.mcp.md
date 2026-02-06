---
name: interactive_noauthor_test
description: Interactive-key test
agent: agent
argument-hint: 
model: gpt-4o-mini
tools:
  - AKV
  - Azure
---

1) We are using a guest MSA account in a MSDN dev/test tenant where the account is a full owner and we can not only test out the dev/test workflow but also the prod workflow so there could be concerns with #EXT# and RBAC.`n2) We need to use the Azure MCP servers as well as MS documentation`n3) We need to use/track all 46 Azure policies for AKV`n4) We need to test all workflows for dev/test, rproduction as well as using the concepts of audit, deny, enforce, etc`n5) We need to have a plan for what we need to do in dev/test (for a different subscription down the road) and for production (again a different subscription than what we are using now)`n6) I don't want any helper or external scripts. Please keep all code inline to the main Setup script and AzPolicy implementation script`n7) Please track all work in the todos.md and in the workspace`n8) Please don't patch the reports, fix the source code that generates the reports`n9) If we need to enable public firewall access to allow a creation of an object/artifact or to test something, this is acceptable until the needed operation is complete - then disable public access.`n
