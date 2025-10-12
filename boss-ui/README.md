# Boss Workspace UI

The Boss Workspace UI provides a Gmail-style workspace that surfaces files stored in the Boss human folders. It consumes the Boss API to resolve logical folder names (such as `human:inbox`) into real paths before listing and previewing Markdown files.

## Boss flow overview

1. **Intake** – Humans drop files into the Dropbox (`human:dropbox`).
2. **Routing** – The router processes new dropbox files and forwards them to the Inbox for questions or Sent for answers.
3. **Collaboration** – Agents work the Inbox (`human:inbox`) and Sent (`human:sent`) folders, iterating on drafts.
4. **Finalization** – Approved deliverables land in `human:deliverables`, while supporting materials live in Drafts/Documents.

The UI surfaces these folders so operators can quickly navigate the workspace, inspect files, and confirm routing outcomes.

## Getting started

### Prerequisites

- Node.js 18+
- A running instance of the [Boss API](../boss-api) on `http://localhost:4000`

### Installation

```bash
cd boss-ui
npm install
```

### Development server

```bash
npm run dev
```

Open the printed URL (defaults to `http://localhost:5173`) in your browser. The UI will fetch folder listings and file previews from the Boss API.

### Production build

```bash
npm run build
npm run preview
```

## Smoke test plan

1. **Inbox preview** – Place a Markdown file in `human:inbox` using the path resolver. Verify that it appears in the Inbox list and that selecting it renders the Markdown preview in the viewer pane.
2. **Dropbox visibility** – Place a file in `human:dropbox`. Confirm that it shows up under the Dropbox tab so the router can pick it up later.
