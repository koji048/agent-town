# Work queue

Agent Town is fully ambient: it watches `queue/pending/` while running.
Drop a `.json` file here and the Director picks it up within a few
seconds, cascades it through the crew, and writes the finished package
to `output/`.

Lifecycle: `pending/` → `processing/` → `done/`

## Request schema

```json
{
  "topic": "3 AI tools ที่ช่วยให้ตัดต่อวิดีโอเร็วขึ้น 2 เท่า",
  "audience": "Thai creators who edit on their phone",
  "duration_sec": 45,
  "platform": "Instagram Reels",
  "notes": "Anything else the crew should know",
  "language": "(optional) overrides the configured language",
  "niche": "(optional) overrides the configured niche"
}
```

Only `topic` is required — everything else has sensible defaults from
`user_config.cfg`.

## Output

Each request produces `output/<timestamp>_<slug>/` containing:

| File | Author |
|---|---|
| `00_plan.md` | Director — production brief |
| `01_research.md` | Researcher — hooks, facts, angles |
| `02_script.md` | Scriptwriter — timecoded VO script |
| `03_captions.srt` | Editor — caption-capped subtitles |
| `04_publish.md` | Publisher — titles, hashtags, posting plan |
| `05_review.md` | Director — final QC verdict |
| `reel_package.md` | Everything combined |
| `request.json` | The original request |
