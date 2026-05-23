# Spec: home-couple-sync

## Requirements

### 1. Custom Shared Message (home_couple_sync_01)

**Requirement**: Users can edit a shared message that appears as the Home screen title.

**User Story**:

- As a couple user, I want to set a custom message (e.g., "Mi amor" instead of "Tu espacio de pareja") so that the Home screen feels more personal.

**Acceptance Criteria**:

- [ ] Edit button (pencil icon) appears next to the custom message on Home screen
- [ ] Tapping Edit opens a modal with a text field
- [ ] Text is pre-filled with current custom_message
- [ ] Save button persists message to Supabase couple_rooms.custom_message
- [ ] On success, message updates on Home with fade animation
- [ ] If offline, message is cached locally (shared_preferences key: couple_message)
- [ ] If offline and first load, show fallback: "Tu espacio de pareja"
- [ ] Real-time sync: changes appear on partner's Home within 2 seconds

**Scenarios**:

1. User A edits message to "Mi amor" → saved to Supabase → User B's Home shows "Mi amor" within 2s
2. User A offline, edits message locally → goes online → syncs to Supabase and B's device
3. Both offline → each sees their cached copy; on sync, User A's latest version wins (last-write)

---

### 2. Incoming Partner Messages (home_couple_sync_02)

**Requirement**: Users can send a message to their partner that appears only on the partner's Home (not the sender's).

**User Story**:

- As a couple user, I want to send a private message to my partner that appears on their Home so we can communicate emotionally without a full chat interface.

**Acceptance Criteria**:

- [ ] Send Message button exists on Pareja screen
- [ ] Tapping opens a modal with a text input field
- [ ] Send button creates a couple_messages row in Supabase
- [ ] Message appears on partner's Home (replaces or augments "Todo está en orden, amor")
- [ ] Message does NOT appear on sender's Home (no self-messages)
- [ ] Only latest message shown (previous messages are replaced)
- [ ] Partner sees message in real-time (RLS/streaming)
- [ ] Message persists until next message from same sender
- [ ] Offline: message queued locally, sent when online
- [ ] Optional: Confirm toast on send

**Scenarios**:

1. User A sends "Te amo" → appears on User B's Home → does NOT appear on A's Home
2. User A sends "Te amo" → User A goes offline → "Te amo" still visible on B's Home
3. User B sends reply "Yo también" → now appears on A's Home, B's Home empty (no self)
4. User A offline, sends "Hola" → queued locally → User A goes online → sent to Supabase → appears on B's Home

---

### 3. Persistence & Sync (home_couple_sync_03)

**Requirement**: Messages persist in Supabase and sync in real-time.

**Acceptance Criteria**:

- [ ] couple_messages table exists with schema: id, room_id, sender_id, content, created_at, updated_at
- [ ] RLS policy: users can insert own messages, read messages where sender_id = auth.user_id OR recipient_id = auth.user_id
- [ ] MessageNotifier subscribes to couple_messages stream for messages NOT from current user
- [ ] couple_rooms.custom_message updates RLS: any partner can update, both read
- [ ] Optimistic updates: UI updates immediately while request in flight

---

## Delta Specs (Changes to Existing)

### Home Screen (lib/features/home/screens/home_screen.dart)

**Remove**:

- Hardcoded "Tu espacio de pareja" title
- Hardcoded "Todo está en orden, amor" message

**Add**:

- Watch `roomNotifier.select((r) => r?.customMessage)` → displays custom message with edit button
- Watch `incomingMessageProvider` → displays partner's incoming message if exists
- EditDialog component (modal for editing custom message)
- FadeTransition on message updates
- Tap animation on Edit button

**Behavior**:

```
Home Screen Title: [Custom Message] [Edit Button]
Card Below: [Incoming Message from Partner] or [Empty State]
Counts: (unchanged)
```

### Pareja Screen (lib/features/pareja/screens/pareja_screen.dart - new route/screen)

**Add**:

- FloatingActionButton or inline button: "Enviar mensaje"
- Tapping opens dialog with TextField
- Send button creates couple_messages entry

---

## Data Model: Supabase Tables

### couple_rooms (extend existing)

```sql
ALTER TABLE couple_rooms ADD COLUMN custom_message TEXT DEFAULT 'Tu espacio de pareja';
ALTER TABLE couple_rooms ADD COLUMN custom_message_updated_at TIMESTAMP;
```

### couple_messages (new table)

```sql
CREATE TABLE couple_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES couple_rooms(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now()
);

CREATE INDEX couple_messages_room_id ON couple_messages(room_id);
CREATE INDEX couple_messages_sender_id ON couple_messages(sender_id);
```

### RLS Policies

**couple_rooms** (custom_message):

- UPDATE: any authenticated user in the room can update custom_message
- SELECT: any authenticated user can select

**couple_messages**:

- INSERT: any authenticated user can insert (send own message)
- SELECT: user can select if sender_id = auth.user_id OR if message exists for their partner
- (Simplified: allow all authenticated users to read/write—rely on room_id foreign key)

---

## Offline Behavior

**Local Storage Keys**:

- `couple_message` → stores latest custom_message (cache)
- `pending_messages` → queue of unsent partner messages (JSON array)

**Fallback**:

- If offline and first load: use cached custom_message or default "Tu espacio de pareja"
- When online: fetch latest from Supabase, overwrite local cache
- If local > Supabase timestamp: sync local to server

---

## Empty States & Edge Cases

1. **No partner connected**: Don't show message fields (already handled by RoomNotifier)
2. **No incoming message**: Show placeholder: "Tu pareja aún no te ha dejado un mensaje ❤️"
3. **No custom message set**: Default: "Tu espacio de pareja"
4. **Message too long**: Truncate to 200 chars; warn in dialog
5. **Rapid updates**: Debounce custom_message saves (500ms)

---

## Acceptance Criteria Summary

- ✅ Custom message editable with pencil icon on Home
- ✅ Partner messages appear on other device in < 2s
- ✅ Self-messages don't appear on sender's Home
- ✅ Offline fallback works
- ✅ Tests cover: edit, send, receive, offline queue
- ✅ No analyzer warnings
