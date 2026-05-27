# Database Migrations - Deployment Guide

## Status: Ready to Deploy

**Date**: May 12, 2026  
**Feature**: home-couple-sync  
**Database**: Supabase PostgreSQL

---

## What The Current Schema Uses

> Baseline note: this project does not use a separate `couple_messages`
> table. The current MVP stores the latest one-to-one message for each partner
> directly in `couple_rooms`.

1. **couple_rooms** - Room identity, shared message, and one-to-one messages
   - Room fields: `id`, `invite_code`, `name`, `created_at`, `last_activity_at`
   - User assignment: `user1_id`, `user2_id`
   - Shared Home title: `custom_message`, `custom_message_updated_at`
   - Individual messages: `message_for_user1`, `message_for_user2`, `message_updated_at`
   - Relationship tracker: `relationship_start_date`, `period_started_at`

2. **shared_items** - Shared tasks and shopping rows
   - Common fields: `room_id`, `type`, `title`, `details`, `price`, `category`, `completed`
   - `type = 'todo'` powers ParejaScreen tasks
   - `type = 'shopping'` powers ShoppingScreen

## How To Deploy

### Option A: Supabase Dashboard

1. Open the Supabase Dashboard.
2. Select your project.
3. Go to **SQL Editor**.
4. Copy the full contents of `MIGRATIONS.sql`.
5. Paste it into the SQL Editor and run it.

### Option B: psql

```bash
psql postgresql://postgres:YOUR_PASSWORD@YOUR_PROJECT.supabase.co:5432/postgres \
  -f MIGRATIONS.sql
```

---

## Verification

After running `MIGRATIONS.sql`, these checks should match the current app.

### couple_rooms columns

```sql
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'couple_rooms'
ORDER BY ordinal_position;
```

Expected important columns:

```text
id
invite_code
name
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

### shared_items columns

```sql
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'shared_items'
ORDER BY ordinal_position;
```

Expected important columns:

```text
id
room_id
type
title
details
price
category
completed
created_at
updated_at
```

### RLS policies

```sql
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('couple_rooms', 'shared_items')
ORDER BY tablename, policyname;
```

Expected coverage:

- `couple_rooms`: insert, select, claim `user1_id`, claim `user2_id`, member update.
- `shared_items`: select, insert, update, delete for room members.

### Realtime

```sql
SELECT tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
  AND schemaname = 'public'
  AND tablename IN ('couple_rooms', 'shared_items')
ORDER BY tablename;
```

Expected rows:

```text
couple_rooms
shared_items
```

## App Flows Covered

1. Anonymous auth creates an authenticated Supabase user invisibly at startup.
2. Creating a room inserts `couple_rooms`, then assigns the creator as `user1_id`.
3. Joining by invite code assigns the second distinct user as `user2_id`.
4. Home shared title updates `custom_message` and streams from `couple_rooms`.
5. One-to-one messages update:
   - `user1` sends to `message_for_user2`
   - `user2` sends to `message_for_user1`
6. ParejaScreen tasks read/write `shared_items` with `type = 'todo'`.
7. Relationship tracker stores shared dates in `couple_rooms`, with local cache fallback.

---

## Rollback Notes

For development reset only:

```sql
DROP TABLE IF EXISTS shared_items CASCADE;
DROP TABLE IF EXISTS couple_rooms CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS update_last_activity_at_column() CASCADE;
DROP FUNCTION IF EXISTS update_custom_message_timestamp() CASCADE;
DROP FUNCTION IF EXISTS update_private_message_timestamp() CASCADE;
```

Do not run this against production data unless you intend to delete rooms,
messages, tasks, and shopping rows.
