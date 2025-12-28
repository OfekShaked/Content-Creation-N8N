# Content Creation N8N Workflows

This repository contains the n8n workflows for an automated content creation and management factory.

## Project Overview

This project automates the lifecycle of content creation, from initial research to multi-platform publishing (LinkedIn and X). It uses a sophisticated "Critic-Draft" loop to ensure high-quality output and leverages xAI for deep research and creative drafting.

### Core Architecture

- **Workflow A (Content Factory)**: The main engine that orchestrated research, drafting, and the quality gate loop.
- **Workflow B (Telegram Router)**: A management interface via Telegram for approving, editing, and triggering content generation.
- **Workflow C (Publish Worker)**: Handles the final publishing to LinkedIn and X (via HTTP API).
- **Workflow D (Prompt Editor)**: A dedicated utility for managing and versioning AI prompt templates stored in PostgreSQL.
- **Subworkflows**: Specialized components for research tasks.

## AI Prompts & Strategies

The default prompts for each stage of the content factory are located in the `prompts/` directory. These include:
- **Research**: `research.v1.md`
- **LinkedIn Draft**: `draft.linkedin.v1.md`
- **X Thread Draft**: `draft.x_thread.v1.md`
- **LinkedIn Critic**: `critic.linkedin.v1.md`
- **X Thread Critic**: `critic.x_thread.v1.md`

## Database Schema

The full database schema is provided in `init.sql`. It includes the definitions for:
- `ideas`: Content ideas and research summaries.
- `claims`: Factual claims extracted during research.
- `drafts`: Multi-platform content versions.
- `publish_jobs`: Queue for social platform publishing.
- `prompt_templates`: Storage for hot-swappable AI prompts.

## Setup Instructions

### Prerequisites

- [n8n](https://n8n.io/) (Docker or desktop installation)
- [PostgreSQL](https://www.postgresql.org/) (To store ideas, drafts, and prompt templates)
- [xAI API Key](https://x.ai/api)
- Telegram Bot Token (For interaction)

### Environment Configuration

1.  **Database**: Run the provided `init.sql` (if available in the core repo) to set up the necessary tables: `ideas`, `claims`, `drafts`, `publish_jobs`, and `prompt_templates`.
2.  **n8n Credentials**: Configure the following credentials in your n8n instance:
    - **Postgres**: Connection details for your content database.
    - **xAiApi**: Your xAI API key.
    - **Telegram Bot**: Your bot token.
    - **Custom HTTP**: For Twitter/LinkedIn API calls if using Workflow C.

### Importing Workflows

1.  Clone this repository.
2.  In n8n, go to "Workflows" -> "Import from File".
3.  Import the JSON files from the `workflows/` folder.
4.  **Note**: Ensure you update any hardcoded IDs or URLs (e.g., Telegram Chat ID, Subworkflow IDs) within the nodes.

## Workflow Details

| Workflow | Name | Purpose |
| :--- | :--- | :--- |
| **A** | `workflow-a-content-factory.json` | Orchestrates research, drafting, and critique loops. |
| **B** | `workflow-b-telegram-router.json` | Telegram bot for management and manual approvals. |
| **C** | `workflow-c-publish-worker.json` | Publishes content to social platforms. |
| **D** | `workflow-d-prompt-editor.json` | Interface for updating system and user prompts. |
| **Sub** | `subworkflow-xai-research.json` | Dedicated research module using xAI. |

## Important Notes

- **No Secrets**: This repository only contains the workflow logic. API keys and database credentials must be configured securely within n8n.
- **Dynamic Prompts**: Workflows are designed to fetch prompts from the database, allowing for hot-swapping strategies without reloading the workflows.
