# Proposal: home-couple-sync

## Executive Summary

The accepted implementation enhances the Home and Pareja screens with room-scoped couple communication using the existing `couple_rooms` table. The final architecture does **not** create a separate `couple_messages` table. One-to-one messages are stored in `couple_rooms.message_for_user1` and `couple_rooms.message_for_user2`, with `message_updated_at` tracking the latest update.

## Accepted Scope

- Editable shared Home title via `couple_rooms.custom_message`.
- Incoming partner message shown on Home.
- Send message action from Pareja screen.
- Offline queue in `shared_preferences` for unsent messages.
- Local cached custom message fallback.
- Realtime updates by streaming the active `couple_rooms` row.
- Room-scoped RLS using `user1_id` and `user2_id` membership.

## Explicit Non-Goals

- No `couple_messages` table in the accepted baseline.
- No message history/threading.
- No UX redesign.
- No end-to-end encryption.

## Architecture Decision

| Decision | Why |
|---|---|
| Store messages in `couple_rooms.message_for_user1/message_for_user2` | Simpler MVP schema for one latest message per partner. |
| Stream `couple_rooms` instead of a separate messages table | Keeps realtime state aligned with room membership and custom message updates. |
| Keep offline queue local | Preserves send intent while the device is offline without introducing new backend tables. |

## Success Criteria

- Custom Home message can be edited and cached locally.
- Partner messages do not appear on the sender's Home.
- Latest message for each recipient is available from `couple_rooms`.
- Tests pass and analyzer is clean.