---
name: chaos-memory
description: Hybrid search memory system for AI agents. Search, store, and auto-capture team knowledge with BM25 + Vector + Graph + Heat signals.
homepage: https://github.com/hargabyte/Chaos-mind
metadata:
  clawdbot:
    emoji: 🧠
    requires:
      bins: ["chaos-cli"]
    install:
      - id: chaos-install
        kind: shell
        command: "./install.sh"
        label: "Install CHAOS Memory System"
---

# CHAOS Memory

**C**ontext-aware **H**ierarchical **A**utonomous **O**bservation **S**ystem

Hybrid search memory for AI agents with 4 retrieval signals:
- **BM25** - Keyword matching
- **Vector** - Semantic similarity  
- **Graph** - Relationship bonuses
- **Heat** - Access patterns + priority

---

## 🤖 For AI Agents: How to Use This Tool

**First time?** Run this to see the complete reference:
```bash
chaos-cli --help
```

**Quick workflow:**
1. **Before a task:** `chaos-cli search "keywords" --mode index --limit 10`
2. **During a task:** `chaos-cli store "important fact" --category decision --priority 0.9`
3. **After a task:** `chaos-cli list 10`

**Token savings:** Use `--mode index` for 90% token savings (~75 tokens/result)

**More help:** Run `chaos help-agents` for the AI-optimized reference guide.

---

## Quick Start

After installation, use `chaos-cli`:

```bash
# Search memories
chaos-cli search "pricing decisions" --limit 5

# Store a memory
chaos-cli store "Enterprise tier: $99/month" --category decision

# List recent
chaos-cli list 10
```

---

## Search Memories

**Quick search** (summary mode):
```bash
chaos-cli search "architecture patterns" --mode summary --limit 5
```

**Fast scan** (index mode, 90% token savings):
```bash
chaos-cli search "team decisions" --mode index --limit 10
```

**Full detail**:
```bash
chaos-cli search "model selection" --mode full --limit 3
```

**Modes:**
| Mode | Tokens/Result | Use Case |
|------|---------------|----------|
| index | ~75 | Quick scan, many results |
| summary | ~250 | Balanced (default) |
| full | ~750 | Deep dive |

---

## Store Memory

```bash
# Decision
chaos-cli store "Qwen3-1.7B is default model" --category decision --priority 0.9

# Core fact
chaos-cli store "Database runs on port 3307" --category core --priority 0.7

# Research finding
chaos-cli store "43x speedup with think=false" --category research --priority 0.8
```

**Categories:** decision, core, semantic, research

**Priority:** 0.0-1.0 (higher = more important)

---

## Get by ID

```bash
chaos-cli get <memory-id>
```

---

## List Recent

```bash
chaos-cli list        # Default 10
chaos-cli list 20     # Show 20
```

---

## Auto-Capture (Optional)

Start the background daemon to auto-extract from sessions:

```bash
chaos-consolidator --auto-capture --config ~/.chaos/config.yaml &
```

**What it extracts:** Decisions, facts, insights
**What it skips:** Greetings, filler, acknowledgments
**Speed:** 2.6s per message (~42s per 16-message session)

---

## Configuration

Default config location: `~/.chaos/config.yaml`

```yaml
database:
  host: 127.0.0.1
  port: 3307

qwen:
  model: qwen3:1.7b
  think: false

auto_capture:
  enabled: true
  interval: 15m
```

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CHAOS_HOME` | `~/.chaos` | Installation directory |
| `CHAOS_DB_PORT` | `3307` | Database port |
| `CHAOS_MODEL` | `qwen3:1.7b` | Extraction model |

---

## Requirements

- **Dolt** - Version-controlled database
- **Ollama** - Local LLM inference (for auto-capture)
- **Go 1.21+** - To build from source (optional)

The install script handles dependencies automatically.

---

## Troubleshooting

**Command not found:**
```bash
export PATH="$HOME/.chaos/bin:$PATH"
```

**Database error:**
```bash
cd ~/.chaos/db && dolt sql-server --port 3307 &
```

**No results:**
```bash
chaos-cli list  # Check if memories exist
```

---

## Links

- **GitHub:** https://github.com/hargabyte/Chaos-mind
- **Docs:** https://github.com/hargabyte/Chaos-mind/blob/main/README.md
- **Issues:** https://github.com/hargabyte/Chaos-mind/issues

---

*Version 1.0.0 | Created by HSA Team*
