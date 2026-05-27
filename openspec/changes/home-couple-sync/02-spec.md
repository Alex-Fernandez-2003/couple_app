# Spec: home-couple-sync

## Current Baseline

The implemented baseline uses `couple_rooms` as the single Supabase source for shared couple state and one-to-one messages.

## Requirements

### 1. Custom Shared Message

Users can edit a shared message that appears as the Home screen title.

Acceptance criteria:

- [x] Home screen reads the active room custom message.
- [x] Edit dialog exists for updating the custom message.
- [x] Save persists to `couple_rooms.custom_message`.
- [x] Room state caches the message locally for offline fallback.
- [x] Room stream updates partner devices through `couple_rooms` realtime.

### 2. Incoming Partner Messages

Users can send a private latest-message value to their partner.

Acceptance criteria:

- [x] Pareja screen exposes a send message action.
- [x] Message send resolves the sender's room role.
- [x] If sender is `user1_id`, content is stored in `message_for_user2`.
- [x] If sender is `user2_id`, content is stored in `message_for_user1`.
- [x] Sender does not read their own outbound column as an incoming message.
- [x] Offline failures are queued in local storage for retry.

### 3. Persistence & Sync

Acceptance criteria:

- [x] `couple_rooms` includes `custom_message`, `custom_message_updated_at`, `message_for_user1`, `message_for_user2`, and `message_updated_at`.
- [x] RLS allows authenticated room members to read/update room-scoped shared state.
- [x] Realtime publication includes `couple_rooms`.
- [x] No `couple_messages` table is required for the accepted MVP baseline.

## Data Model

### `couple_rooms`

Important fields:

```text
id
invite_code
user1_id
user2_id
custom_message
custom_message_updated_at
message_for_user1
message_for_user2
message_updated_at
relationship_start_date
period_started_at
created_at
last_activity_at
```

### Local Storage Keys

```text
couple_message
pending_messages
current_room_id
current_room_invite_code
relationship_start_date
period_started_at
```

## Out of Scope

- Message history.
- Separate `couple_messages` table.
- Read receipts.
- UX changes beyond the already implemented controls.