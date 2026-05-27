-- Couple App Database Migrations
-- Execute in the Supabase SQL Editor.
-- Current schema target: room-based couple sync.
-- Date: 2026-05-12

-- ============================================================================
-- Extensions
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================================
-- Timestamp helper functions
-- ============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_last_activity_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.last_activity_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_custom_message_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.custom_message_updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_private_message_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.message_updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Migration 1: couple_rooms
-- ============================================================================

CREATE TABLE IF NOT EXISTS couple_rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invite_code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL DEFAULT 'Nuestro espacio',
  user1_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  user2_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  custom_message TEXT NOT NULL DEFAULT 'Tu espacio de pareja',
  custom_message_updated_at TIMESTAMPTZ DEFAULT now(),
  message_for_user1 TEXT CHECK (char_length(message_for_user1) <= 500),
  message_for_user2 TEXT CHECK (char_length(message_for_user2) <= 500),
  message_updated_at TIMESTAMPTZ,
  relationship_start_date TIMESTAMPTZ,
  period_started_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  last_activity_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE couple_rooms
  ADD COLUMN IF NOT EXISTS invite_code TEXT,
  ADD COLUMN IF NOT EXISTS name TEXT NOT NULL DEFAULT 'Nuestro espacio',
  ADD COLUMN IF NOT EXISTS user1_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS user2_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS custom_message TEXT NOT NULL DEFAULT 'Tu espacio de pareja',
  ADD COLUMN IF NOT EXISTS custom_message_updated_at TIMESTAMPTZ DEFAULT now(),
  ADD COLUMN IF NOT EXISTS message_for_user1 TEXT CHECK (char_length(message_for_user1) <= 500),
  ADD COLUMN IF NOT EXISTS message_for_user2 TEXT CHECK (char_length(message_for_user2) <= 500),
  ADD COLUMN IF NOT EXISTS message_updated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS relationship_start_date TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS period_started_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now(),
  ADD COLUMN IF NOT EXISTS last_activity_at TIMESTAMPTZ DEFAULT now();

CREATE UNIQUE INDEX IF NOT EXISTS idx_couple_rooms_invite_code
  ON couple_rooms(invite_code);

CREATE INDEX IF NOT EXISTS idx_couple_rooms_user1_id
  ON couple_rooms(user1_id);

CREATE INDEX IF NOT EXISTS idx_couple_rooms_user2_id
  ON couple_rooms(user2_id);

DROP TRIGGER IF EXISTS update_couple_rooms_last_activity_at ON couple_rooms;
CREATE TRIGGER update_couple_rooms_last_activity_at
  BEFORE UPDATE ON couple_rooms
  FOR EACH ROW
  EXECUTE FUNCTION update_last_activity_at_column();

DROP TRIGGER IF EXISTS update_couple_rooms_custom_message_updated_at ON couple_rooms;
CREATE TRIGGER update_couple_rooms_custom_message_updated_at
  BEFORE UPDATE OF custom_message ON couple_rooms
  FOR EACH ROW
  EXECUTE FUNCTION update_custom_message_timestamp();

DROP TRIGGER IF EXISTS update_couple_rooms_message_updated_at ON couple_rooms;
CREATE TRIGGER update_couple_rooms_message_updated_at
  BEFORE UPDATE OF message_for_user1, message_for_user2 ON couple_rooms
  FOR EACH ROW
  EXECUTE FUNCTION update_private_message_timestamp();

ALTER TABLE couple_rooms ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS couple_rooms_allow_insert ON couple_rooms;
DROP POLICY IF EXISTS couple_rooms_allow_select ON couple_rooms;
DROP POLICY IF EXISTS couple_rooms_allow_claim_user1 ON couple_rooms;
DROP POLICY IF EXISTS couple_rooms_allow_claim_user2 ON couple_rooms;
DROP POLICY IF EXISTS couple_rooms_allow_member_update ON couple_rooms;

-- Anonymous auth still creates an authenticated Supabase user, so the app has
-- auth.uid() without showing login UI.
CREATE POLICY couple_rooms_allow_insert ON couple_rooms
  FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- Needed for joining by invite_code before user2_id is assigned.
CREATE POLICY couple_rooms_allow_select ON couple_rooms
  FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- First app/device to create or enter an unclaimed room becomes user1.
CREATE POLICY couple_rooms_allow_claim_user1 ON couple_rooms
  FOR UPDATE
  USING (auth.uid() IS NOT NULL AND user1_id IS NULL)
  WITH CHECK (user1_id = auth.uid());

-- Second distinct user to join becomes user2. Existing users are not overwritten.
CREATE POLICY couple_rooms_allow_claim_user2 ON couple_rooms
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL
    AND user1_id IS NOT NULL
    AND user1_id <> auth.uid()
    AND user2_id IS NULL
  )
  WITH CHECK (
    user1_id IS NOT NULL
    AND user1_id <> auth.uid()
    AND user2_id = auth.uid()
  );

-- Room members can update custom_message and the one-to-one message columns.
CREATE POLICY couple_rooms_allow_member_update ON couple_rooms
  FOR UPDATE
  USING (user1_id = auth.uid() OR user2_id = auth.uid())
  WITH CHECK (user1_id = auth.uid() OR user2_id = auth.uid());

-- ============================================================================
-- Migration 2: shared_items
-- ============================================================================

CREATE TABLE IF NOT EXISTS shared_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES couple_rooms(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('todo', 'shopping')),
  title TEXT NOT NULL,
  details TEXT,
  price NUMERIC,
  category TEXT,
  completed BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE shared_items
  ADD COLUMN IF NOT EXISTS room_id UUID REFERENCES couple_rooms(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS type TEXT,
  ADD COLUMN IF NOT EXISTS title TEXT,
  ADD COLUMN IF NOT EXISTS details TEXT,
  ADD COLUMN IF NOT EXISTS price NUMERIC,
  ADD COLUMN IF NOT EXISTS category TEXT,
  ADD COLUMN IF NOT EXISTS completed BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_shared_items_room_id
  ON shared_items(room_id);

CREATE INDEX IF NOT EXISTS idx_shared_items_room_type
  ON shared_items(room_id, type);

CREATE INDEX IF NOT EXISTS idx_shared_items_updated_at
  ON shared_items(updated_at DESC);

DROP TRIGGER IF EXISTS update_shared_items_updated_at ON shared_items;
CREATE TRIGGER update_shared_items_updated_at
  BEFORE UPDATE ON shared_items
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

ALTER TABLE shared_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS shared_items_allow_select ON shared_items;
DROP POLICY IF EXISTS shared_items_allow_insert ON shared_items;
DROP POLICY IF EXISTS shared_items_allow_update ON shared_items;
DROP POLICY IF EXISTS shared_items_allow_delete ON shared_items;

CREATE POLICY shared_items_allow_select ON shared_items
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM couple_rooms
      WHERE couple_rooms.id = shared_items.room_id
        AND (couple_rooms.user1_id = auth.uid() OR couple_rooms.user2_id = auth.uid())
    )
  );

CREATE POLICY shared_items_allow_insert ON shared_items
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM couple_rooms
      WHERE couple_rooms.id = shared_items.room_id
        AND (couple_rooms.user1_id = auth.uid() OR couple_rooms.user2_id = auth.uid())
    )
  );

CREATE POLICY shared_items_allow_update ON shared_items
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM couple_rooms
      WHERE couple_rooms.id = shared_items.room_id
        AND (couple_rooms.user1_id = auth.uid() OR couple_rooms.user2_id = auth.uid())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM couple_rooms
      WHERE couple_rooms.id = shared_items.room_id
        AND (couple_rooms.user1_id = auth.uid() OR couple_rooms.user2_id = auth.uid())
    )
  );

CREATE POLICY shared_items_allow_delete ON shared_items
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM couple_rooms
      WHERE couple_rooms.id = shared_items.room_id
        AND (couple_rooms.user1_id = auth.uid() OR couple_rooms.user2_id = auth.uid())
    )
  );

-- ============================================================================
-- Realtime
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'couple_rooms'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE couple_rooms;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'shared_items'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE shared_items;
  END IF;
END $$;

-- ============================================================================
-- Verification Queries
-- ============================================================================

-- couple_rooms columns expected by lib/data/models/room.dart:
-- SELECT column_name, data_type
-- FROM information_schema.columns
-- WHERE table_schema = 'public'
--   AND table_name = 'couple_rooms'
-- ORDER BY ordinal_position;

-- shared_items columns expected by lib/data/models/shared_item.dart:
-- SELECT column_name, data_type
-- FROM information_schema.columns
-- WHERE table_schema = 'public'
--   AND table_name = 'shared_items'
-- ORDER BY ordinal_position;

-- Check RLS policies:
-- SELECT tablename, policyname, cmd
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND tablename IN ('couple_rooms', 'shared_items')
-- ORDER BY tablename, policyname;

-- Check realtime publication:
-- SELECT tablename
-- FROM pg_publication_tables
-- WHERE pubname = 'supabase_realtime'
--   AND schemaname = 'public'
--   AND tablename IN ('couple_rooms', 'shared_items')
-- ORDER BY tablename;

-- ============================================================================
-- Status: Ready to execute
-- ============================================================================
