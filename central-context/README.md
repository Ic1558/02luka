# Central Context Workspace

This directory is used by the Luka backend service to exchange files with the rest of the 02luka system.

Folders:
- `boss/dropbox` – outbound tasks/messages created by the UI.
- `boss/sent` – archived copies of outbound messages for history reconstruction.
- `boss/inbox` – queries/responses returned by the automation stack.
- `boss/deliverables` – final outputs from the automation stack.
- `boss/drafts` – work-in-progress notes the boss can keep on hand.

The backend automatically creates these folders if they do not exist. Files written here should be treated as plain text/Markdown with an optional YAML front matter block that stores metadata such as the originating session and client identifier.
