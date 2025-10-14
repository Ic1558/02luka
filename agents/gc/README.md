# Agent: gc

**Memory:** [memory/gc/](../../memory/gc/)
**Owner:** gc
**Type:** Calendar & Orchestration Agent

## Scope
- Manage iCalendar and Google Calendar integration
- Orchestrate multi-agent coordination
- Schedule and track automated tasks
- Maintain system health and status endpoints
- Handle calendar build and sync operations
- Provide health proxy endpoints (port 3002)
- Coordinate daily operations across agents

## Commands
- Create memo: `make mem agent=gc title="Note"`
- Search boss: `make boss-find q="…"`

## Key Files
- `g/tools/calendar_build_ics.sh` - ICS builder
- `g/tools/calendar_sync_gcal.sh` - Google Calendar sync
- `g/tools/calendar_health_endpoint.sh` - Health status
- `g/tools/health_proxy.js` - Health proxy server

## Integration
- iCalendar format (ICS files)
- Google Calendar API
- LaunchAgents for automation
- Health endpoints for monitoring
