# Raycast Scripts Conventions

## Location
All Raycast scripts should be saved to: `~/raycast scripts`

## Output Policy
Scripts should default to **silent mode** unless the output is important enough to display in the Raycast UI.

### Use Silent Mode
```bash
# @raycast.mode silent
```

### When to Show Output
Only show output for:
- Error messages
- Critical success confirmations (e.g., file size after compression)
- Information the user explicitly needs to see

Avoid verbose logging, progress messages, or debugging output in the Raycast UI.

## Standard Script Structure
```bash
#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Your Script Title
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 📝
# @raycast.packageName Category Name

# Documentation:
# @raycast.description Brief description of what the script does
# @raycast.author assistant2

# Script logic here...
```

## Examples
See existing scripts in this directory for reference patterns.
