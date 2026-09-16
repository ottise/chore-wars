---
name: Web Interface Guidelines
description: Review files for compliance with Web Interface Guidelines by fetching the latest rules from Vercel. Use this to review UI code after implementation.
---
# Web Interface Guidelines

Review files for compliance with Web Interface Guidelines.

## How It Works
1. Fetch the latest guidelines from the source URL below.
2. Read the specified files (or prompt user for files/pattern).
3. Check against all rules in the fetched guidelines.
4. Output findings in the terse `file:line` format.

## Guidelines Source
Fetch fresh guidelines before each review:
`https://raw.githubusercontent.com/vercel-labs/web-interface-guidelines/main/command.md`

Use WebFetch (or `read_url_content`) to retrieve the latest rules. The fetched content contains all the rules and output format instructions.

## Usage
When a user provides a file or pattern argument:
- Fetch guidelines from the source URL above
- Read the specified files
- Apply all rules from the fetched guidelines
- Output findings using the format specified in the guidelines

If no files specified, ask the user which files to review.
