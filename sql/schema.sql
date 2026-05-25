-- WhatsApp Bot v6.0 — Bot tables (distinct from n8n internal tables)

CREATE TABLE IF NOT EXISTS bot_messages (
  id                 TEXT        PRIMARY KEY,
  owner              TEXT        NOT NULL,
  destinataire       TEXT        NOT NULL,
  timezone           TEXT        NOT NULL DEFAULT 'UTC',
  scheduled_at       TIMESTAMPTZ NOT NULL,
  scheduled_local    TEXT        NOT NULL,
  message            TEXT        NOT NULL,
  premessage_type    TEXT        NOT NULL DEFAULT 'default',
  custom_premessage  TEXT,
  status             TEXT        NOT NULL DEFAULT 'pending',
  retry_count        INT         NOT NULL DEFAULT 0,
  next_retry_at      TIMESTAMPTZ,
  sending_started_at TIMESTAMPTZ,
  send_attempt_id    TEXT,
  waha_message_id    TEXT,
  last_error         TEXT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  sent_at            TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS bot_messages_dispatch
  ON bot_messages (status, scheduled_at, next_retry_at)
  WHERE status IN ('pending', 'sending');

CREATE TABLE IF NOT EXISTS bot_user_state (
  phone         TEXT        PRIMARY KEY,
  step          INT         NOT NULL DEFAULT 0,
  draft         JSONB       NOT NULL DEFAULT '{}',
  flags         JSONB       NOT NULL DEFAULT '{}',
  last_activity TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
