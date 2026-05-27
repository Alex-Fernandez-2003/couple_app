# Design: home-couple-sync

## Accepted Architecture

```text
Home / Pareja UI
  -> Riverpod providers
  -> SupabaseService
  -> couple_rooms row
  -> shared_preferences fallback / pending queue
```

The current baseline intentionally keeps one-to-one messaging inside `couple_rooms`:

- `message_for_user1`: latest message intended for `user1_id`.
- `message_for_user2`: latest message intended for `user2_id`.
- `message_updated_at`: timestamp for the latest message update.

There is no separate `couple_messages` table in the accepted implementation.

## State Flow

### Custom message

1. Home opens edit dialog.
2. User saves a new title.
3. `RoomNotifier.updateCustomMessage()` calls `SupabaseService.updateCustomMessage()`.
4. `couple_rooms.custom_message` updates.
5. Room stream refreshes local state.
6. Value is cached in `shared_preferences`.

### Partner message

1. Pareja screen opens send message dialog.
2. `MessageNotifier.sendMessage()` calls `SupabaseService.sendMessage()`.
3. `SupabaseService.assignRoomUser()` confirms whether sender is `user1_id` or `user2_id`.
4. Sender `user1_id` writes `message_for_user2`; sender `user2_id` writes `message_for_user1`.
5. Receiver stream maps the room row to an incoming `Message` object.
6. Send failures are stored in `pending_messages` for retry.

## Provider Contracts

- `roomStateProvider`: owns active room state, custom message, relationship dates, and room subscription.
- `currentUserIdProvider`: reads Supabase anonymous auth user id.
- `messageProvider((roomId, userId))`: owns latest incoming message and send/sync methods.
- `messageQueueProvider`: exposes local pending message queue.

## Supabase Contract

`MIGRATIONS.sql` is the source of truth for the schema. It creates/updates:

- `couple_rooms`
- `shared_items`
- RLS policies for authenticated room members
- Realtime publication for `couple_rooms` and `shared_items`

## Tradeoff

This design favors a small, stable MVP schema over message history. If threaded chat is needed later, that should be a new SDD change with a dedicated migration from room-column messages to a message table.