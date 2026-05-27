# Tasks: home-couple-sync

## Current Status

This OpenSpec record has been reconciled with the implemented room-column architecture. The original `couple_messages` table approach was superseded by storing latest recipient messages directly in `couple_rooms`.

## Completed Tasks

- [x] Extend `couple_rooms` with `custom_message` and `custom_message_updated_at`.
- [x] Extend `couple_rooms` with `message_for_user1`, `message_for_user2`, and `message_updated_at`.
- [x] Add/update RLS policies for authenticated room members.
- [x] Add realtime publication support for `couple_rooms`.
- [x] Create `Message` model for app-level message mapping.
- [x] Extend `Room` model with custom message, user assignment, message, and tracker fields.
- [x] Extend `SupabaseService` with custom-message and room-column message methods.
- [x] Extend `LocalStorageService` with cached custom message and pending message queue methods.
- [x] Add `currentUserIdProvider`, `MessageNotifier`, `messageProvider`, and `messageQueueProvider`.
- [x] Integrate custom message and incoming partner message on Home.
- [x] Integrate send message action on Pareja while preserving task creation.
- [x] Add routing/navigation for Pareja in the shell.
- [x] Add Message model tests.
- [x] Prepare root `MIGRATIONS.sql` and `DEPLOYMENT_GUIDE.md` for Supabase deployment.
- [x] Validate current Windows baseline with `flutter test`.
- [x] Validate current Windows baseline with `flutter analyze` after baseline stabilization.

## Not Completed / Requires External Confirmation

- [ ] Confirm `MIGRATIONS.sql` has been executed in the target Supabase project.
- [ ] Manual two-device QA for realtime sync and offline queue behavior.

## Superseded Tasks

- [x] Original `couple_messages` table task superseded by room-column architecture.
- [x] Original `couple_messages` stream task superseded by `couple_rooms` row stream.

## Verification Commands

```bash
flutter pub get
flutter analyze
flutter test
```