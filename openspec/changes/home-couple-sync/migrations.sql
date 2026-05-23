# Database Migrations

## Migration 1.1: Create couple_messages table

Execute in Supabase SQL Editor:

```sql
-- Create couple_messages table
CREATE TABLE couple_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES couple_rooms(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL CHECK (char_length(content) <= 500),
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now()
);

-- Create indexes for performance
CREATE INDEX idx_couple_messages_room_id ON couple_messages(room_id);
CREATE INDEX idx_couple_messages_sender_id ON couple_messages(sender_id);

-- Enable RLS
ALTER TABLE couple_messages ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Allow insert for authenticated users (sender validation)
CREATE POLICY couple_messages_allow_insert ON couple_messages 
  FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- RLS Policy: Allow select for room members
CREATE POLICY couple_messages_allow_select ON couple_messages 
  FOR SELECT USING (
    room_id IN (
      SELECT id FROM couple_rooms 
      WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
  );

-- Auto-update trigger for updated_at
CREATE TRIGGER update_couple_messages_updated_at
  BEFORE UPDATE ON couple_messages
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
```

## Migration 1.2: Extend couple_rooms with custom_message

Execute in Supabase SQL Editor:

```sql
-- Add custom_message column to couple_rooms
ALTER TABLE couple_rooms 
  ADD COLUMN IF NOT EXISTS custom_message TEXT DEFAULT 'Tu espacio de pareja',
  ADD COLUMN IF NOT EXISTS custom_message_updated_at TIMESTAMP DEFAULT now();

-- Enable RLS (if not already enabled)
ALTER TABLE couple_rooms ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Allow update custom_message for room members
CREATE POLICY couple_rooms_allow_update_custom_message ON couple_rooms
  FOR UPDATE 
  USING (user1_id = auth.uid() OR user2_id = auth.uid())
  WITH CHECK (user1_id = auth.uid() OR user2_id = auth.uid());

-- RLS Policy: Allow select for room members (if not exists)
CREATE POLICY couple_rooms_allow_select ON couple_rooms
  FOR SELECT USING (user1_id = auth.uid() OR user2_id = auth.uid());

-- Auto-update trigger for updated_at
CREATE TRIGGER update_couple_rooms_custom_message_updated_at
  BEFORE UPDATE OF custom_message ON couple_rooms
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
```

✅ **Status**: Ready to execute in Supabase Dashboard
