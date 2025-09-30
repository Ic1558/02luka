# Path Keys (must use via resolver)

human.dropbox → boss/dropbox/
human.inbox → boss/inbox/
human.sent → boss/sent/
human.deliverables → boss/deliverables/
reports.system → g/reports/
reports.runtime → output/reports/
bridge.inbox → f/bridge/inbox/
bridge.outbox → f/bridge/outbox/
status.system → run/system_status.v2.json
status.tickets → run/tickets/

Example (bash):
  TARGET="$(bash g/tools/path_resolver.sh human:inbox)"
  echo "hello" > "$TARGET/example.txt"
