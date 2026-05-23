# Proposal: home-couple-sync

## Executive Summary

Enhance the Home screen to enable real-time emotional communication between partners through two mechanisms: (1) an editable shared message that appears as the page title (replacing "Tu espacio de pareja"), synced via Supabase couple_rooms table with offline fallback; and (2) a message inbox showing unread partner messages (replacing the "Todo está en orden, amor" placeholder), persisted in a new couple_messages table.

## Intent

Currently, the Home screen is static—it displays pending counts and a fixed welcome message. Partners have no way to communicate emotionally or leave each other personalized messages. This feature fills that gap by adding bidirectional messaging with cloud sync.

## Scope

**In Scope**:

- Add custom_message field to couple_rooms table (shared editable message)
- Create couple_messages table (sender → recipient unread messages)
- UI: Add Edit button + modal dialog for custom message on Home
- UI: Show incoming partner message in Home (replaces "Todo está en orden, amor")
- UI: Add Send Message button in Pareja screen
- Provider: Create MessageNotifier to handle message state (AsyncValue pattern)
- Provider: Extend RoomNotifier to include custom_message sync
- Real-time streaming: Subscribe to couple_messages for active recipient
- Offline fallback: Last fetched custom_message stored in shared_preferences

**Out of Scope**:

- Message history/threading (single message at a time)
- Image/emoji support in messages
- Message read/unread indicators (UI only)
- End-to-end encryption

## Approach

1. **Database**: Extend Supabase schema with couple_messages table
2. **State Management**: Create MessageNotifier provider using Riverpod AsyncValue
3. **Sync**: Extend RoomNotifier to fetch and cache custom_message; stream couple_messages in real-time
4. **UI**: Add EditDialog for custom message + animate on update; replace hardcoded message with provider watch
5. **Offline**: Use shared_preferences to cache custom_message locally

## Tradeoffs

| Decision                          | Pro                                     | Con                           |
| --------------------------------- | --------------------------------------- | ----------------------------- |
| Single message (not threaded)     | Simpler UI, forces emotional directness | Limited conversation depth    |
| Anonymous auth (no login visible) | Maintains existing UX                   | Can't link to real identities |
| Offline fallback (local cache)    | Works without connection                | May show stale message        |
| Real-time streaming               | Instant updates                         | Requires active subscription  |

## Why This Design

- **Emotional directness**: One message at a time ensures partners read and respond meaningfully
- **Cloud-first with offline grace**: Supabase backend scales + local fallback prevents blank screens
- **Minimal disruption**: Reuses existing patterns (Riverpod, go_router, shared_preferences)
- **Consistent architecture**: Follows NotesNotifier/BoxesNotifier patterns already in codebase

## Success Criteria

- ✅ Custom message editable and syncs between devices within 2 seconds
- ✅ Incoming partner messages appear immediately on Home
- ✅ Sending a message to partner shows on their Home (not sender's)
- ✅ Offline mode: custom message and last message visible with local cache
- ✅ Tests pass (unit + widget)
- ✅ No console errors or analyzer warnings
