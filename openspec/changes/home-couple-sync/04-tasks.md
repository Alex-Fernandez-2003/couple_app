# Tasks: home-couple-sync

## Task Breakdown

All tasks are ordered for dependency flow. Each task is designed to be completable in ~30 minutes.

---

### Phase 1: Database & Backend

#### Task 1.1: Create Supabase couple_messages table

**Acceptance Criteria**:

- [ ] couple_messages table exists in Supabase with all columns (id, room_id, sender_id, content, created_at, updated_at)
- [ ] Foreign key constraints verified
- [ ] Indexes created on room_id and sender_id
- [ ] RLS policies enabled (allow insert for self, select for room members)

**Implementation Details**:

- Run SQL migration (provided in design.md)
- Test via Supabase dashboard or CLI

---

#### Task 1.2: Extend couple_rooms with custom_message

**Acceptance Criteria**:

- [ ] couple_rooms.custom_message field added (TEXT, default 'Tu espacio de pareja')
- [ ] couple_rooms.custom_message_updated_at field added (TIMESTAMP, default now())
- [ ] No data loss on existing rows
- [ ] RLS policy allows authenticated users to update custom_message

**Implementation Details**:

- Run migration via Supabase SQL editor
- Verify via SELECT in dashboard

---

### Phase 2: Models & Services

#### Task 2.1: Create Message model (lib/data/models/message.dart)

**Acceptance Criteria**:

- [ ] Message class with fields: id, roomId, senderId, content, createdAt, updatedAt
- [ ] fromMap() constructor from Supabase JSON
- [ ] toMap() method for serialization
- [ ] copyWith() for updates
- [ ] Equality override (== and hashCode) if needed

**Implementation Details**:

- Follow pattern of existing models (Note, Box)
- No validation needed (backend RLS enforces)

---

#### Task 2.2: Extend SupabaseService with message methods

**Acceptance Criteria**:

- [ ] messageStream(roomId, excludeUserId) method → Stream<Message>
- [ ] sendMessage(roomId, senderId, content) → Future<Message>
- [ ] getLatestMessage(roomId, excludeUserId) → Future<Message?>
- [ ] deleteMessage(messageId) → Future<void> (optional, for cleanup)

**Implementation Details**:

- Use supabase.from('couple_messages').stream(...)
- Apply filters: room_id = roomId AND sender_id != excludeUserId
- Error handling: log and rethrow for UI to catch

---

#### Task 2.3: Extend SupabaseService with custom_message methods

**Acceptance Criteria**:

- [ ] updateCustomMessage(roomId, message) → Future<void>
- [ ] watchRoomCustomMessage(roomId) → Stream<String> (streams custom_message from couple_rooms)

**Implementation Details**:

- Use supabase.from('couple_rooms').update(...).eq('id', roomId)
- Stream via supabase.from('couple_rooms').stream(...).map(...)

---

#### Task 2.4: Extend LocalStorageService with offline queue

**Acceptance Criteria**:

- [ ] getPendingMessages() → Future<List<Map<String, dynamic>>>
- [ ] addPendingMessage(Map) → Future<void> (queues message locally)
- [ ] removePendingMessage(messageId) → Future<void>
- [ ] getCachedCustomMessage() → Future<String?>
- [ ] setCachedCustomMessage(message) → Future<void>

**Implementation Details**:

- pending_messages key: JSON array of {id, content, timestamp, roomId}
- couple_message key: cached custom message
- Use shared_preferences for all

---

### Phase 3: State Management (Providers)

#### Task 3.1: Create MessageNotifier provider

**Acceptance Criteria**:

- [ ] MessageNotifier extends StateNotifier<AsyncValue<Message?>>
- [ ] Constructor receives room, currentUserId, supabaseService, storageService
- [ ] build() subscribes to messageStream (excludes self)
- [ ] sendMessage(content) method posts to Supabase + handles offline queue
- [ ] \_syncPendingMessages() called on app resume (via Riverpod lifecycle)
- [ ] Error handling logs to console (use debugPrint)

**Implementation Details**:

- Place in lib/data/providers.dart
- Use room?.id to ensure room is active
- If room is null, return AsyncValue.data(null)
- On send failure, add to queue

---

#### Task 3.2: Create incomingMessageProvider (computed)

**Acceptance Criteria**:

- [ ] incomingMessageProvider filters messageNotifier to exclude self
- [ ] Returns Message? (latest from partner only)
- [ ] Returns null if no room or no messages

**Implementation Details**:

- Provider<Message?> that watches messageNotifier + authProvider
- Simple filter: msg.senderId != currentUserId

---

#### Task 3.3: Create messageQueueProvider

**Acceptance Criteria**:

- [ ] StateNotifierProvider<List<Map<String, dynamic>>>
- [ ] Loads from LocalStorageService.getPendingMessages() on init
- [ ] addToPendingQueue(content) adds to list and persists
- [ ] clearQueue() empties list
- [ ] exposes list for UI polling (optional)

**Implementation Details**:

- Load on build()
- Persist on every change
- Simple list-based implementation

---

#### Task 3.4: Extend RoomNotifier with custom_message watch

**Acceptance Criteria**:

- [ ] Room model includes customMessage (String, default 'Tu espacio de pareja')
- [ ] RoomNotifier.build() now also subscribes to couple_rooms stream for custom_message updates
- [ ] When custom_message updates on partner device, RoomNotifier state updates
- [ ] Caches custom_message locally on every update

**Implementation Details**:

- Modify existing RoomNotifier build() to include stream subscription
- Use watchRoomCustomMessage(roomId) from SupabaseService
- Call storageService.setCachedCustomMessage(...) on update
- Merge with existing room state

---

### Phase 4: UI Components

#### Task 4.1: Create EditDialog widget (lib/features/home/widgets/edit_custom_message_dialog.dart)

**Acceptance Criteria**:

- [ ] Stateful widget with TextField for editing
- [ ] Prefilled with current customMessage
- [ ] Max 200 character validation with visual feedback
- [ ] Save button (disabled if text unchanged or empty)
- [ ] Cancel button
- [ ] Loading state during save
- [ ] Shows error SnackBar on failure
- [ ] Closes dialog on success

**Implementation Details**:

- Use showDialog + AlertDialog pattern
- onSave callback returns edited text to parent
- Debounce on character count for validation

---

#### Task 4.2: Modify Home screen (lib/features/home/screens/home_screen.dart)

**Acceptance Criteria**:

- [ ] Watch roomNotifier.select(customMessage) for title
- [ ] Watch incomingMessageProvider for incoming message
- [ ] Title row: [Custom Message] [Edit Icon]
- [ ] Edit icon tap opens EditDialog
- [ ] On save, show FadeTransition (300ms) for title update
- [ ] Below counts, show incoming message card or empty state
- [ ] Empty state text: "Tu pareja aún no te ha dejado un mensaje ❤️"
- [ ] Incoming message shows in FadeTransition (500ms)
- [ ] Loading state shown while message fetching

**Implementation Details**:

- Use \_titleAnimationController and \_messageAnimationController
- Call ref.read(messageNotifier.notifier).sendMessage(...) when needed (indirectly via dialog)
- Handle AsyncValue.loading, .error cases
- Keep existing count grid unchanged

---

#### Task 4.3: Create Pareja screen (lib/features/pareja/screens/pareja_screen.dart)

**Acceptance Criteria**:

- [ ] ConsumerWidget with basic layout (ListView placeholder content)
- [ ] FloatingActionButton.extended: "Enviar mensaje"
- [ ] Tap opens SendMessageDialog (below)
- [ ] Send button disabled if room is null or offline
- [ ] Loading state during send

**Implementation Details**:

- Route: /pareja (add to router in Task 4.5)
- Use ref.read(roomNotifier) to check room exists
- Place holder content: "Información de pareja..." (can be expanded later)

---

#### Task 4.4: Create SendMessageDialog widget (lib/features/pareja/widgets/send_message_dialog.dart)

**Acceptance Criteria**:

- [ ] Modal with TextField for message content
- [ ] Max 500 character validation
- [ ] Send button creates couple_messages entry
- [ ] Calls ref.read(messageNotifier.notifier).sendMessage(content)
- [ ] On success, shows toast: "Mensaje enviado ❤️"
- [ ] On error, shows toast: "No se pudo enviar"
- [ ] Closes dialog on success
- [ ] Handles offline queue gracefully

**Implementation Details**:

- Similar to EditDialog pattern
- Use ScaffoldMessenger.of(context).showSnackBar(...) for toast
- Non-blocking (fire and forget, but with feedback)

---

### Phase 5: Routing & Integration

#### Task 4.5: Add Pareja route to router

**Acceptance Criteria**:

- [ ] Route /pareja added to MainShell children
- [ ] Pareja screen appears in bottom navigation
- [ ] Navigation between Home, Pareja, and other tabs works
- [ ] Pareja destination icon in NavigationBar (e.g., Icons.favorite)

**Implementation Details**:

- Modify lib/config/router.dart
- Add destination to mainShellRoutes list
- Update NavigationBar destinations

---

### Phase 6: Testing & Validation

#### Task 5.1: Write MessageNotifier tests

**Acceptance Criteria**:

- [ ] Test sendMessage updates state
- [ ] Test sendMessage offline queues locally
- [ ] Test incoming message filtering (excludes self)
- [ ] Test \_syncPendingMessages flushes queue
- [ ] All tests pass (flutter test)

**Implementation Details**:

- Create test/providers/message_notifier_test.dart
- Mock SupabaseService, LocalStorageService
- Use Riverpod test utilities

---

#### Task 5.2: Write Home screen widget test

**Acceptance Criteria**:

- [ ] Test renders custom message title
- [ ] Test edit button opens dialog
- [ ] Test incoming message displays
- [ ] Test empty state shows when no message
- [ ] All tests pass

**Implementation Details**:

- Create test/features/home/home_screen_test.dart
- Mock roomNotifier, messageNotifier
- Use testWidgets + pumpWidget

---

#### Task 5.3: Run flutter analyze

**Acceptance Criteria**:

- [ ] No errors (exit code 0)
- [ ] Informational warnings acceptable (deprecations)
- [ ] No new analyzer issues introduced

**Implementation Details**:

- Run `flutter analyze`
- Log any new warnings

---

#### Task 5.4: Manual QA

**Acceptance Criteria**:

- [ ] Edit custom message on device A, verify appears on device B within 2s
- [ ] Send message from A, verify only appears on B (not A)
- [ ] Go offline, edit message locally, go online, verify syncs
- [ ] Send message offline, go online, verify message appears on partner's device
- [ ] Empty states display correctly
- [ ] Animations are smooth
- [ ] No console errors or crashes

**Implementation Details**:

- Use flutter run on 2 devices/simulators
- Use Supabase dashboard to monitor table
- Use logcat/xcode debugger for console output

---

## Dependency Graph

```
1.1, 1.2 (Database setup)
   ↓
2.1, 2.2, 2.3, 2.4 (Models + Services)
   ↓
3.1, 3.2, 3.3, 3.4 (Providers)
   ↓
4.1, 4.2, 4.3, 4.4 (UI)
   ↓
4.5 (Routing)
   ↓
5.1, 5.2, 5.3, 5.4 (Testing & QA)
```

## Task Checklist

- [ ] 1.1: Create couple_messages table
- [ ] 1.2: Extend couple_rooms with custom_message
- [ ] 2.1: Create Message model
- [ ] 2.2: Extend SupabaseService with message methods
- [ ] 2.3: Extend SupabaseService with custom_message methods
- [ ] 2.4: Extend LocalStorageService with offline queue
- [ ] 3.1: Create MessageNotifier provider
- [ ] 3.2: Create incomingMessageProvider
- [ ] 3.3: Create messageQueueProvider
- [ ] 3.4: Extend RoomNotifier with custom_message watch
- [ ] 4.1: Create EditDialog widget
- [ ] 4.2: Modify Home screen
- [ ] 4.3: Create Pareja screen
- [ ] 4.4: Create SendMessageDialog widget
- [ ] 4.5: Add Pareja route to router
- [ ] 5.1: Write MessageNotifier tests
- [ ] 5.2: Write Home screen widget test
- [ ] 5.3: Run flutter analyze
- [ ] 5.4: Manual QA
