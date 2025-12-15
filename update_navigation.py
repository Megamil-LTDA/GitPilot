import re

path = '/private/var/www/html/stacks/movida/app/GitPilot/GitPilot/Views/MainWindowView.swift'
with open(path, 'r') as f:
    content = f.read()

# 1. Update CheckLogDetailView struct definition to add onFollowLog property
# Find: struct CheckLogDetailView: View {
#       let log: CheckLog
# Add:  var onFollowLog: ((CheckLog) -> Void)? = nil

view_def_pattern = r'(struct CheckLogDetailView: View \{\s*let log: CheckLog)'
replacement_def = r'\1\n    var onFollowLog: ((CheckLog) -> Void)? = nil'

content = re.sub(view_def_pattern, replacement_def, content)

# 2. Update the Button action in CheckLogDetailView
# Previously: _ = await gitMonitor.pullRepository(repo)
# New: 
#    if let newLog = await gitMonitor.pullRepository(repo) {
#        onFollowLog?(newLog)
#    }

button_action_pattern = r'_\s*=\s*await\s+gitMonitor\.pullRepository\(repo\)'
replacement_action = 'if let newLog = await gitMonitor.pullRepository(repo) { onFollowLog?(newLog) }'

content = re.sub(button_action_pattern, replacement_action, content)

# 3. Update CheckLogsView instantiation of CheckLogDetailView
# Find: .sheet(item: $selectedLog) { log in CheckLogDetailView(log: log) }
# Replace with: .sheet(item: $selectedLog) { log in CheckLogDetailView(log: log) { newLog in selectedLog = newLog } }

# Note: The pattern might span newlines.
sheet_pattern = r'\.sheet\(item: \$selectedLog\)\s*\{\s*log\s*in\s*CheckLogDetailView\(log:\s*log\)\s*\}'
# Or simply specific constructor call if it matches.

# Since I check my previous cat output:
#         .sheet(item: $selectedLog) { log in
#             CheckLogDetailView(log: log)
#         }

sheet_pattern_multiline = r'\.sheet\(item: \$selectedLog\)\s*\{\s*log\s*in\s*CheckLogDetailView\(log:\s*log\)\s*\}'

# Let's try to match specific string first.
target_sheet = 'CheckLogDetailView(log: log)'
replacement_sheet = 'CheckLogDetailView(log: log, onFollowLog: { newLog in selectedLog = newLog })'

if target_sheet in content:
    content = content.replace(target_sheet, replacement_sheet)
    print("✅ Updated CheckLogsView sheet binding")
else:
    # Try regex if spacing is different
    content = re.sub(r'CheckLogDetailView\(log:\s*log\)', replacement_sheet, content)
    print("✅ Updated CheckLogsView sheet binding (regex)")

with open(path, 'w') as f:
    f.write(content)
