# Content Workflow: Prompt Directory

This document provides a comprehensive overview of all AI prompts used in the Content Workflow system. Most prompts are stored in the PostgreSQL `prompt_templates` table for easy management, while a few technical prompts are hardcoded within specific subworkflows.

## 🗄️ Database-Driven Prompts (Managed)
These prompts are stored in the database and can be hot-swapped or edited via the **Telegram Prompt Editor**.

| Key | Stage | Platform | Model | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `research.v1` | Research | - | `grok-4-1-fast-non-reasoning` | Deep dive into a topic using live search. |
| `draft.linkedin.v1` | Draft | LinkedIn | `grok-4-1-fast-non-reasoning` | Professional ghostwriting for LinkedIn posts. |
| `draft.x_thread.v1` | Draft | X | `grok-4-1-fast-non-reasoning` | Punchy, engaging threads for X (Twitter). |
| `critic.linkedin.v1` | Critic | LinkedIn | `grok-4-1-fast-reasoning` | Harsh but constructive review of LinkedIn drafts. |
| `critic.x_thread.v1` | Critic | X | `grok-4-1-fast-reasoning` | Narrative and hook analysis for X threads. |


---

## 🛠️ Individual Prompt Details

### 1. Research (`research.v1`) - **"Insight Mining"**
*   **Framework:** Shifts from passive info gathering to finding "Insight Gaps"—counter-intuitive truths that challenge the status quo.
*   **System Prompt:** Lead Researcher for a viral media empire. Finds where popular advice contradicts data, identifies bleeding-neck problems, and gathers proof via hard data points.
*   **User Prompt:** Requests JSON with `summary`, `trending_angle` (vanilla view), `contrarian_angle` (spicy view), `pain_points`, `claims`, and `citations`.
*   **Output Changes:** ⚠️ Adds `contrarian_angle` and `pain_points` fields.

### 2. LinkedIn Draft (`draft.linkedin.v1`) - **"Justin Welsh Framework"**
*   **Framework:** Maximum dwell time via visual anchors and scroll stoppers. Enforces "Hook-Retain-Reward" structure.
*   **System Prompt:** Ghostwriter for Top 1% LinkedIn Creator. Rules: Never >2 lines per paragraph, hook must be ≤10 words, kills jargon (synergy, landscape, delving, unlocking).
*   **User Prompt:** Generates JSON with `hook` (scroll-stopper), `body` (double line breaks for whitespace), and `cta` (debate trigger, NOT "thoughts?").
*   **Output Changes:** ✅ No schema changes, style upgraded.

### 3. X Thread Draft (`draft.x_thread.v1`) - **"Dickie Bush / Sahil Bloom Framework"**
*   **Framework:** "Slippery Slope" writing—Tweet 1 makes it impossible not to read Tweet 2. "Masterclass Threads" that get bookmarked.
*   **System Prompt:** Elite Twitter Thread Ghostwriter. Specific formulas for Tweet 1 (transformation promise) and Tweet 2 (establish stakes). Uses "→" for flow, lowercase aesthetic for authenticity.
*   **User Prompt:** Generates JSON array of `tweets` following the hook-bridge-value-CTA structure.
*   **Output Changes:** ✅ No schema changes, style upgraded.

### 4. LinkedIn Critic (`critic.linkedin.v1`) - **"Algorithm Auditor"**
*   **Framework:** Predicts viral potential using skimmability and hook strength scoring rubric.
*   **System Prompt:** Ruthless reviewer with specific failure criteria. Hook must be <12 words and break patterns. Fails if >3 lines in text block. Must rewrite hook if score <9.
*   **User Prompt:** Returns JSON with `score`, `fatal_flaws`, `better_hook`, and `improved_version`.
*   **Output Changes:** ⚠️ Adds `fatal_flaws` and `better_hook` fields.

### 5. X Thread Critic (`critic.x_thread.v1`) - **"Narrative Engineer"**
*   **Framework:** Hunts for the "Saggy Middle" where threads die. Analyzes "Flow State" and open loops.
*   **System Prompt:** Reviews for Open Loop (Tweet 1 question), Saggy Middle (redundant tweets), and Payoff. Detects AI-generated patterns and makes content rawer.
*   **User Prompt:** Returns JSON with `score`, `drop_off_point`, `fix_suggestions`, and `improved_thread`.
*   **Output Changes:** ⚠️ Adds `drop_off_point` and `fix_suggestions` fields.

---

## 🏗️ Hardcoded Technical Prompts
These prompts are embedded directly in the workflow files and are generally used for structured data extraction or internal routing.

### Research Subworkflow (`subworkflow-xai-research.json`)
*   **Node:** `xAI Research API`
*   **Model:** `grok-4-1-fast-non-reasoning`
*   **System Prompt:** Same as `research.v1` (System fallback).
*   **User Prompt:** Structured request for JSON output with research schema.


---

## ⌨️ How to Manage Prompts
You can manage these prompts directly from Telegram using **Workflow D (Prompt Editor)**:

*   **List all prompts:** Send `/prompt`
*   **View/Edit a prompt:** Send `/prompt <key>` (e.g., `/prompt draft.linkedin.v1`)
*   **Apply Updates:** Reply to the prompt display message with:
    *   `SYSTEM: <new text>`
    *   `USER: <new text>`
    *   `MODEL: <model_name>`
    *   `TEMP: <number>`
