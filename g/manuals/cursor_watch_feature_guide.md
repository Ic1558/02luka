# How to Use Cursor's "Watch" Feature for Documentation

This screenshot shows Cursor's "Watch" feature in the `@Doc` context menu. This is a powerful way to keep your documentation synchronized with external sources.

## What is "Watch"?

When you see `@Doc` with a "Watch" option (or similar terminology like "Crawled"), it means Cursor can:

1.  **Crawl a URL:** You provide a documentation URL (e.g., `https://docs.cursor.com/`).
2.  **Index Content:** Cursor downloads and processes the text from that site.
3.  **Semantic Search:** It adds this content to its local vector database.
4.  **Contextual Retrieval:** When you ask a question in Chat or Composer, Cursor can search this indexed documentation to provide accurate, up-to-date answers based on the external docs.

## How to Use It

1.  **Open Chat/Composer:** Press `Cmd+L` (Chat) or `Cmd+I` (Composer).
2.  **Type `@Doc`:** This opens the documentation context menu.
3.  **Add a New Doc:**
    *   Select **"Add new doc"**.
    *   Paste the URL of the documentation you want to index.
    *   Give it a name (e.g., "Cursor Docs", "Stripe API").
4.  **Let it Index:** Cursor will crawl the site. This might take a moment depending on the site's size.
5.  **Ask Questions:** Once indexed, you can type `@Cursor Docs how do I use tab completion?` and Cursor will answer using the knowledge from that URL.

## Why is this useful?

*   **Up-to-date Info:** LLMs have a knowledge cutoff. This feature lets you inject *current* documentation into the model's context.
*   **Specific Libraries:** If you're using a niche or internal library, indexing its docs allows Cursor to write code for it correctly.
*   **Reduced Hallucination:** The model grounds its answers in the provided text rather than guessing.

## In the Screenshot

The screenshot specifically highlights:
*   **`@Cursor Directory`**: Likely a pre-indexed or local directory context.
*   **`@Files` / `@Code`**: Standard context options.
*   **`@Doc`**: The entry point for external documentation.
*   **The `Docs` list**: Shows previously added documentation sources (e.g., "Cursor", "02luka docs" if added).

*Tip: You can manage these sources in `Cursor Settings > Features > Docs` to resync or delete them.*
