# Project Documentation

This directory contains project documentation, design decisions, and important conversation history.

## 📝 Saving Cline/Claude Conversations

Key conversations with AI assistants (Cline, Claude) that contain important architectural decisions, problem-solving sessions, or complex implementation details should be saved here for future reference.

### How to Save a Conversation

1. In Cline's conversation list, click the **Export** button (download icon)
2. Save the file as `docs/conversations/YYYY-MM-DD-short-description.md`
3. Alternatively, copy-paste the relevant parts manually

### File Naming Convention

```
docs/conversations/2026-06-19-devcontainer-setup.md
docs/conversations/2026-06-19-ci-cd-pipeline-review.md
```

### What to Save

- Architectural decisions and rationale
- Complex debugging sessions
- Configuration choices (e.g., why a particular library or version)
- Any conversation you'd want to revisit later or share with team members

## Folder Structure

```
docs/
├── README.md          # This file
└── conversations/     # Saved AI assistant conversations
```

## Why This Matters

- **Permanent record** — conversations are git-tracked and won't be lost
- **Shareable** — team members can see how decisions were made
- **Searchable** — `grep` across all docs to find solutions