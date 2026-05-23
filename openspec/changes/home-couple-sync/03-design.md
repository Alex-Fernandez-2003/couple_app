# Design: home-couple-sync

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│ Home Screen (lib/features/home/screens/)        │
├─────────────────────────────────────────────────┤
│ - Title: [Custom Message] [Edit Button]         │
│ - Card: [Incoming Partner Message] or empty    │
│ - Counts: (unchanged)                           │
│ - Edit dialog modal (EditDialog widget)         │
└─────────────────────────────────────────────────┘
                        ↓
        ┌──────────────────────────────────┐
        │ State Management (Riverpod)      │
        ├──────────────────────────────────┤
        │ - roomNotifier.select(custom)    │
        │ - messageNotifier (new)          │
        │ - messageQueueProvider (local)   │
        └──────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────┐
│ Supabase Backend                                 │
├──────────────────────────────────────────────────┤
│ - couple_rooms.custom_message (sync)             │
│ - couple_messages table (stream)                 │
│ - RLS policies (room-scoped)                     │
└──────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────┐
│ Local Storage (shared_preferences)               │
├──────────────────────────────────────────────────┤
│ - couple_message (cache custom message)          │
│ - pending_messages (queue unsent partner msgs)   │
└──────────────────────────────────────────────────┘
```

## State Flow

### Custom Message Flow

```
Edit Dialog Opens
  ↓
User types new message
  ↓
Save button pressed
  ↓
Provider.notifyListeners() (optimistic)
  ↓
POST to Supabase couple_rooms UPDATE
  ├─ Success: sync_timestamp updated
  ├─ Failure: revert to previous value
  └─ Offline: queue locally + mark dirty
  ↓
RoomNotifier watches updates via stream
  ↓
Home Screen FadeTransition updates title
```

### Incoming Message Flow

```
Partner sends message
  ↓
MessageNotifier streaming listener triggers
  ↓
Filter: if sender_id ≠ current_user_id
  ↓
Update state (latest message from each partner)
  ↓
Home Screen watches messageNotifier
  ↓
FadeTransition shows incoming message card
```

## Provider Architecture

### New MessageNotifier

```dart
class Message {
  final String id;
  final String roomId;
  final String senderId;
  final String content;
  final DateTime createdAt;
}

class MessageNotifier extends StateNotifier<AsyncValue<Message?>> {
  // Constructor subscribes to couple_messages stream (filtered: not from self)
  // Methods:
  // - sendMessage(content) → insert to Supabase + queue if offline
  // - _syncPendingMessages() → on reconnect, flush queue
}

final messageNotifier = StateNotifierProvider<MessageNotifier, AsyncValue<Message?>>((ref) {
  final room = ref.watch(roomNotifier);
  final currentUserId = ref.watch(authProvider).user!.id;
  return MessageNotifier(room, currentUserId);
});

// Filtered: only incoming messages (not from self)
final incomingMessageProvider = Provider<Message?>((ref) {
  return ref.watch(messageNotifier).whenData((msg) {
    return msg?.senderId != ref.watch(authProvider).user!.id ? msg : null;
  });
});

// Local queue for offline
final messageQueueProvider = StateNotifierProvider<List<String>>((ref) {
  // Load from shared_preferences on init
});
```

### Extend RoomNotifier

```dart
// Add field to Room model
class Room {
  final String id;
  final String customMessage; // NEW
  final DateTime? customMessageUpdatedAt; // NEW
}

// In RoomNotifier.build():
// - Fetch couple_rooms → include custom_message
// - Subscribe to couple_rooms via stream for real-time updates
// - Cache custom_message locally on every update
```

## UI Components

### EditDialog (new widget)

```dart
class EditCustomMessageDialog extends StatefulWidget {
  final String initialValue;
  final Function(String) onSave;

  // Modal with TextField + Save button
  // Validates: max 200 chars
  // Shows loading state while saving
}
```

### Home Screen Changes

```dart
// In build():
final customMessage = ref.watch(
  roomNotifier.select((r) => r?.customMessage ?? 'Tu espacio de pareja')
);
final incomingMsg = ref.watch(incomingMessageProvider);

// Replace title text with:
GestureDetector(
  onTap: _showEditDialog,
  child: FadeTransition(
    opacity: _titleAnimation,
    child: Row(
      children: [
        Text(customMessage),
        Icon(Icons.edit, size: 16),
      ],
    ),
  ),
);

// In card section, add:
if (incomingMsg != null) {
  FadeTransition(
    opacity: _messageAnimation,
    child: Card(
      child: Text(incomingMsg.content),
    ),
  );
} else {
  EmptyStateCard(text: 'Tu pareja aún no te ha dejado un mensaje ❤️');
}
```

### Pareja Screen Changes

**Add new screen**: lib/features/pareja/screens/pareja_screen.dart

```dart
class ParejaScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        label: Text('Enviar mensaje'),
        icon: Icon(Icons.send),
        onPressed: () => _showSendMessageDialog(context, ref),
      ),
      body: ListView(
        children: [
          // Partner info, preferences, etc.
        ],
      ),
    );
  }

  void _showSendMessageDialog(BuildContext context, WidgetRef ref) {
    // Modal with TextField
    // On send: ref.read(messageNotifier.notifier).sendMessage(text)
  }
}
```

## Database Schema Changes

### SQL Migrations

```sql
-- 1. Extend couple_rooms
ALTER TABLE couple_rooms
  ADD COLUMN custom_message TEXT DEFAULT 'Tu espacio de pareja',
  ADD COLUMN custom_message_updated_at TIMESTAMP DEFAULT now();

-- 2. New couple_messages table
CREATE TABLE couple_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES couple_rooms(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL CHECK (char_length(content) <= 500),
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now()
);

CREATE INDEX idx_couple_messages_room_id ON couple_messages(room_id);
CREATE INDEX idx_couple_messages_sender_id ON couple_messages(sender_id);

-- 3. RLS Policies
ALTER TABLE couple_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY couple_messages_allow_insert ON couple_messages
  FOR INSERT WITH CHECK (auth.uid() = sender_id);

CREATE POLICY couple_messages_allow_select ON couple_messages
  FOR SELECT USING (
    room_id IN (
      SELECT id FROM couple_rooms
      WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
  );

ALTER TABLE couple_rooms ENABLE ROW LEVEL SECURITY;

CREATE POLICY couple_rooms_allow_update_custom_message ON couple_rooms
  FOR UPDATE SET (custom_message, custom_message_updated_at)
  USING (user1_id = auth.uid() OR user2_id = auth.uid())
  WITH CHECK (user1_id = auth.uid() OR user2_id = auth.uid());

CREATE POLICY couple_rooms_allow_select ON couple_rooms
  FOR SELECT USING (user1_id = auth.uid() OR user2_id = auth.uid());
```

## Offline Queue Management

### SharedPreferences Keys

- `pending_messages` → JSON-encoded list of {content, timestamp}
- `couple_message` → last cached custom_message

### Sync Logic (in MessageNotifier.build)

```dart
// On init and reconnect:
_syncPendingMessages() {
  final queue = await _storage.getPendingMessages();
  for (final msg in queue) {
    await _supabase.from('couple_messages').insert({
      'room_id': room.id,
      'sender_id': currentUserId,
      'content': msg['content'],
    });
    await _storage.removePendingMessage(msg['id']);
  }
}

// If offline during send:
sendMessage(content) async {
  try {
    await _supabase...insert(...);
  } catch (e) {
    // Queue locally
    await _storage.queuePendingMessage({
      'id': uuid(),
      'content': content,
      'timestamp': now(),
    });
    // Schedule sync on reconnect (via Connectivity plugin or polling)
  }
}
```

## Animation & Transitions

- **Title update**: FadeTransition (300ms) when customMessage changes
- **Incoming message**: FadeTransition + SlideTransition (500ms) when new message arrives
- **Edit button hover**: ScaleTransition (150ms) on tap down
- **Card appearance**: SlideTransition from bottom (300ms) for first incoming message

## Error Handling

| Scenario        | Behavior                                                          |
| --------------- | ----------------------------------------------------------------- |
| Edit save fails | Toast "No se pudo guardar. Reintentando..." + retry queue         |
| Send fails      | Toast "Mensaje no enviado" + queue for retry                      |
| Offline edit    | Save immediately locally, sync on reconnect                       |
| Stale data      | Fetch latest from Supabase on resume (didChangeAppLifecycleState) |
| Network error   | Show SnackBar, retry on reconnect                                 |

## Testing Strategy

- **Unit**: MessageNotifier state transitions, offline queue logic
- **Widget**: Home screen message display, EditDialog interaction, Pareja send flow
- **Integration**: Full flow (edit message → sync → appear on partner device)

---

## Implementation Files to Create/Modify

### New Files

- `lib/data/models/message.dart` — Message model
- `lib/features/pareja/screens/pareja_screen.dart` — Partner communication screen
- `lib/features/home/widgets/edit_dialog.dart` — EditDialog component

### Modified Files

- `lib/data/services/supabase_service.dart` — Add message stream methods
- `lib/data/providers.dart` — Add MessageNotifier, messageQueueProvider, incomingMessageProvider
- `lib/features/home/screens/home_screen.dart` — Watch custom message + incoming message
- `lib/config/router.dart` — Add /pareja route
- `lib/config/theme.dart` — (optional) Add dialog styling

### Database

- Supabase: Run migrations above

### Local Storage

- Extend LocalStorageService with pending message queue methods
