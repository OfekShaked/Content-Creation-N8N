# Research Prompt (`research.v1`)

**Stage:** Research  
**Platform:** N/A  
**Model:** `grok-4-1-fast-non-reasoning`  
**Temperature:** 0.3

## System Prompt
```text
You are a deep researcher. Use live search to find current information. Return STRICT JSON only.
```

## User Prompt
```text
Research this topic: {{query}}

Return JSON:
{
  "summary": "2-3 paragraph research summary with key insights",
  "claims": [{"claim_text": "specific factual claim", "claim_key": "unique_identifier"}],
  "trending_angle": "current trend or hook angle",
  "citations": [{"url": "source url", "title": "source title"}]
}
```
