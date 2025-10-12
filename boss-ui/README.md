# Boss Workspace UI

The Boss Workspace UI provides a Gmail-like interface for browsing folders mapped through the Boss routing flow. It communicates exclusively with the Boss API, which resolves logical human namespace keys (for example, `human:inbox`) into real filesystem locations via `g/tools/path_resolver.sh`.

## Boss flow overview

1. **Router drops inputs into `human:dropbox`.** Files deposited here still need to be triaged.
2. **Operators review the inbox.** Once a file is ready for action, the router or an operator moves it into `human:inbox` for review.
3. **Responses are staged.** When a reply or deliverable is ready, it moves into `human:sent` or `human:deliverables`.
4. **Reference material lives in `human:documents` and drafts in `human:drafts`.** These folders are read-only from the UI perspective.

The UI mirrors these folders in its sidebar so operators can switch between stages quickly.

## Getting started

### Prerequisites

- Node.js 18+
- The Boss API running locally (see `../boss-api` for setup)

### Install dependencies

```bash
cd boss-ui
npm install
```

### Run the development server

```bash
npm run dev
```

The app reads its runtime configuration from `/config.json`, which the Boss API now serves dynamically. Adjust environment variables such as `API_BASE` before starting the API to point the UI at a different backend without rebuilding.

### Build for production

```bash
npm run build
```

## Smoke test plan

1. Place a Markdown file inside the path resolved by `g/tools/path_resolver.sh human:inbox`. Open the Inbox in the UI and verify the file appears in the list and renders in the preview when selected.
2. Place a file in `human:dropbox`. The UI should display it when the Dropbox folder is selected, ensuring the router can later pick it up for processing.

