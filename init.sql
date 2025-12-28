-- Drop existing tables if they exist
DROP TABLE IF EXISTS media_assets CASCADE;
DROP TABLE IF EXISTS publish_jobs CASCADE;
DROP TABLE IF EXISTS pending_edits CASCADE;
DROP TABLE IF EXISTS drafts CASCADE;
DROP TABLE IF EXISTS claims CASCADE;
DROP TABLE IF EXISTS ideas CASCADE;
DROP TABLE IF EXISTS app_settings CASCADE;

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

BEGIN;

-- ---------- Constrained "enums" via CHECKs (keeps TEXT, avoids enum migration friction) ----------

-- 1) Ideas
CREATE TABLE ideas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    raw_input TEXT NOT NULL,

    status TEXT NOT NULL DEFAULT 'ingested',
    requested_tone TEXT,
    research_summary TEXT,

    telegram_message_id BIGINT,
    chat_id BIGINT,           -- BIGINT for Telegram IDs
    user_id BIGINT,           -- BIGINT for Telegram IDs

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT ideas_status_chk CHECK (status IN (
      'ingested','researching','processing','drafting','review','approved','published','failed'
    ))
);

CREATE INDEX ideas_status_created_idx ON ideas (status, created_at);

-- 2) Claims (Truth table)
CREATE TABLE claims (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    idea_id UUID NOT NULL REFERENCES ideas(id) ON DELETE CASCADE,

    claim_key TEXT, -- deterministic key, e.g. "metric=rev_growth;year=2024;val=18%"
    claim_text TEXT NOT NULL,

    verdict TEXT NOT NULL DEFAULT 'unverified',
    source_url TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT claims_verdict_chk CHECK (verdict IN ('verified','unverified','conflicting','debunked','ambiguous'))
);

CREATE INDEX claims_text_trgm_idx ON claims USING GIN (claim_text gin_trgm_ops);
CREATE INDEX claims_idea_key_idx ON claims (idea_id, claim_key);

-- Optional strict dedupe (recommended once stable):
-- ALTER TABLE claims ADD CONSTRAINT claims_unique_key UNIQUE (idea_id, claim_key);

-- 3) Drafts (Versioning)
CREATE TABLE drafts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    idea_id UUID NOT NULL REFERENCES ideas(id) ON DELETE CASCADE,

    version_int INTEGER NOT NULL,
    platform TEXT NOT NULL,
    content_json JSONB NOT NULL,

    media_url TEXT,
    critique_score INTEGER,
    critique_notes TEXT,

    is_approved BOOLEAN NOT NULL DEFAULT FALSE,
    published_at TIMESTAMPTZ,
    post_url TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT drafts_platform_chk CHECK (platform IN ('linkedin','x_thread')),
    CONSTRAINT drafts_unique_version UNIQUE (idea_id, platform, version_int)
);

CREATE INDEX drafts_idea_platform_idx ON drafts (idea_id, platform);

-- 4) Publish Jobs (Durable Queue)
CREATE TABLE publish_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    draft_id UUID NOT NULL REFERENCES drafts(id) ON DELETE CASCADE,

    platform TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'queued',

    attempt_count INTEGER NOT NULL DEFAULT 0,
    next_run_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_error TEXT,

    worker_id TEXT,
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,

    external_id TEXT,
    external_url TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT publish_jobs_platform_chk CHECK (platform IN ('linkedin','x_thread')),
    CONSTRAINT publish_jobs_status_chk CHECK (status IN ('queued','posting','posted','failed','aborted')),
    CONSTRAINT publish_jobs_unique_draft_platform UNIQUE (draft_id, platform)
);

CREATE INDEX publish_jobs_queue_idx ON publish_jobs (status, next_run_at, created_at);

-- 5) Pending Edits (Telegram edit sessions)
CREATE TABLE pending_edits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chat_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,

    draft_id UUID NOT NULL REFERENCES drafts(id) ON DELETE CASCADE,
    platform TEXT NOT NULL,
    target TEXT NOT NULL,

    reply_message_id BIGINT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT pending_edits_platform_chk CHECK (platform IN ('linkedin','x_thread')),
    CONSTRAINT pending_edits_unique_reply UNIQUE (chat_id, reply_message_id)
);

CREATE INDEX pending_edits_expires_idx ON pending_edits (expires_at);

-- 6) App Settings (keep for global config, no voice seeding)
CREATE TABLE app_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    description TEXT
);

-- No voice seeding (text-only workflow)

-- 7) Prompt Templates (Hot-swappable AI prompts)
CREATE TABLE prompt_templates (
    key TEXT PRIMARY KEY,              -- e.g. 'draft.linkedin.v1'
    stage TEXT NOT NULL,               -- 'research' | 'draft' | 'critic' | 'refine'
    platform TEXT,                     -- NULL for research; 'linkedin' or 'x_thread' for others
    model TEXT NOT NULL DEFAULT 'grok-4-1-fast-non-reasoning',
    temperature NUMERIC NOT NULL DEFAULT 0.4,
    system_prompt TEXT NOT NULL,
    user_prompt TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT prompt_templates_stage_chk CHECK (stage IN ('research','draft','critic','refine')),
    CONSTRAINT prompt_templates_platform_chk CHECK (platform IS NULL OR platform IN ('linkedin','x_thread'))
);

CREATE INDEX prompt_templates_stage_platform_idx ON prompt_templates(stage, platform);

-- Seed initial prompt templates
INSERT INTO prompt_templates (key, stage, platform, model, temperature, system_prompt, user_prompt) VALUES
-- Research template
('research.v1', 'research', NULL, 'grok-4-1-fast-non-reasoning', 0.3,
'You are a deep researcher. Use live search to find current information. Return STRICT JSON only.',

'Research this topic: {{query}}

Return JSON:
{
  "summary": "2-3 paragraph research summary with key insights",
  "claims": [{"claim_text": "specific factual claim", "claim_key": "unique_identifier"}],
  "trending_angle": "current trend or hook angle",
  "citations": [{"url": "source url", "title": "source title"}]
}'),

-- LinkedIn Draft template
('draft.linkedin.v1', 'draft', 'linkedin', 'grok-4-1-fast-non-reasoning', 0.4,
'You are a professional ghostwriter specializing in LinkedIn content. Follow these style rules:
- No emojis
- Short paragraphs (2-3 sentences max)
- Use line breaks for readability
- Concrete examples over abstract claims
- Avoid hype words (revolutionary, game-changing, etc.)
- Use bullets sparingly for frameworks
- Return STRICT JSON only',
'Draft a LinkedIn post based on this research:

RESEARCH SUMMARY:
{{research_summary}}

TRENDING ANGLE:
{{trending_angle}}

REQUESTED TONE: {{requested_tone}}

Return JSON:
{
  "hook": "1-2 line attention-grabbing opener",
  "body": "800-1800 character main content with line breaks",
  "cta": "1 line call to action"
}'),

-- X Thread Draft template
('draft.x_thread.v1', 'draft', 'x_thread', 'grok-4-1-fast-non-reasoning', 0.5,
'You are a professional ghostwriter specializing in X (Twitter) threads. Follow these style rules:
- No emojis unless specifically requested
- Each tweet must be <= 280 characters
- Tweet 1 is a strong hook that creates curiosity
- Build narrative tension through the thread
- Last tweet is always a CTA
- Use thread-native voice (punchy, direct)
- Return STRICT JSON only',
'Draft an X thread based on this research:

RESEARCH SUMMARY:
{{research_summary}}

TRENDING ANGLE:
{{trending_angle}}

REQUESTED TONE: {{requested_tone}}

Return JSON:
{
  "tweets": [
    "Tweet 1: Hook that stops the scroll",
    "Tweet 2-N: Build the narrative",
    "Final Tweet: Clear CTA"
  ]
}

Target 5-9 tweets. Each tweet MUST be <= 280 characters.'),

-- LinkedIn Critic template
('critic.linkedin.v1', 'critic', 'linkedin', 'grok-4-1-fast-reasoning', 0.2,
'You are a harsh but constructive critic for LinkedIn content. Score 0-10 where:
- 0-3: Major issues, unclear value proposition
- 4-6: Decent but generic, needs stronger hook or examples
- 7-8: Good, minor polish needed
- 9-10: Excellent, ready to publish

Follow these style rules for improvements:
- No emojis
- Short paragraphs
- Concrete examples
- Avoid hype
- Return STRICT JSON only',
'Critique this LinkedIn post and provide an improved version:

CURRENT DRAFT:
Hook: {{hook}}
Body: {{body}}
CTA: {{cta}}

Return JSON:
{
  "score": 0-10,
  "critique_notes": "Specific feedback on what works and what needs improvement",
  "improved": {
    "hook": "improved hook",
    "body": "improved body",
    "cta": "improved cta"
  }
}'),

-- X Thread Critic template
('critic.x_thread.v1', 'critic', 'x_thread', 'grok-4-1-fast-reasoning', 0.2,
'You are a harsh but constructive critic for X (Twitter) threads. Score 0-10 where:
- 0-3: Weak hook, no narrative arc, tweets too long
- 4-6: Decent but forgettable, needs sharper hooks
- 7-8: Good thread, minor polish needed
- 9-10: Viral-worthy, strong hook and payoff

Check each tweet is <= 280 characters. Return STRICT JSON only.',
'Critique this X thread and provide an improved version:

CURRENT THREAD:
{{tweets_json}}

Return JSON:
{
  "score": 0-10,
  "critique_notes": "Specific feedback on hook strength, narrative flow, tweet lengths",
  "improved": {
    "tweets": ["improved tweet 1", "improved tweet 2", "..."]
  }
}

Ensure ALL tweets in improved version are <= 280 characters.');

COMMIT;
