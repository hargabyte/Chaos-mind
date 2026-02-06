#!/bin/bash
# CHAOS Memory - ClawdHub Install Script
# Downloads pre-built binaries and sets up the system

set -e

echo "🧠 Installing CHAOS Memory System..."
echo ""

CHAOS_HOME="${CHAOS_HOME:-$HOME/.chaos}"
CHAOS_VERSION="${CHAOS_VERSION:-v1.0.0}"
GITHUB_REPO="hargabyte/Chaos-mind"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

success() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; exit 1; }

# Detect platform
detect_platform() {
    OS="$(uname -s)"
    ARCH="$(uname -m)"
    
    case "$OS" in
        Linux)
            case "$ARCH" in
                x86_64) PLATFORM="linux" ;;
                aarch64|arm64) PLATFORM="linux-arm64" ;;
                *) error "Unsupported architecture: $ARCH" ;;
            esac
            ;;
        Darwin)
            case "$ARCH" in
                x86_64) PLATFORM="macos" ;;
                arm64) PLATFORM="macos-arm64" ;;
                *) error "Unsupported architecture: $ARCH" ;;
            esac
            ;;
        MINGW*|MSYS*|CYGWIN*)
            PLATFORM="windows"
            ;;
        *)
            error "Unsupported OS: $OS"
            ;;
    esac
    
    echo "$PLATFORM"
}

# 1. Check/install Dolt
echo "Checking dependencies..."
if command -v dolt &> /dev/null; then
    success "Dolt installed ($(dolt version 2>/dev/null | head -1 || echo 'unknown'))"
else
    warn "Dolt not found. Installing..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install dolt 2>/dev/null || {
            curl -L https://github.com/dolthub/dolt/releases/latest/download/install.sh | bash
        }
    else
        curl -L https://github.com/dolthub/dolt/releases/latest/download/install.sh | bash
    fi
    success "Dolt installed"
fi

# 2. Check/install Ollama (optional, for auto-capture)
if command -v ollama &> /dev/null; then
    success "Ollama installed"
else
    warn "Ollama not found. Auto-capture requires Ollama."
    echo "  Install with: curl -fsSL https://ollama.com/install.sh | sh"
fi

# 3. Create directories
mkdir -p "$CHAOS_HOME/bin" "$CHAOS_HOME/db" "$CHAOS_HOME/config"
success "Created $CHAOS_HOME"

# 4. Download pre-built binaries
PLATFORM=$(detect_platform)
DOWNLOAD_URL="https://github.com/$GITHUB_REPO/releases/download/$CHAOS_VERSION/chaos-memory-$PLATFORM.tar.gz"

echo "Downloading binaries for $PLATFORM..."
if curl -fsSL "$DOWNLOAD_URL" -o "/tmp/chaos-memory.tar.gz" 2>/dev/null; then
    tar -xzf /tmp/chaos-memory.tar.gz -C "$CHAOS_HOME/bin/"
    rm /tmp/chaos-memory.tar.gz
    success "Binaries downloaded"
else
    warn "Could not download pre-built binaries from release"
    warn "Attempting to build from source..."
    
    # Fallback: build from source if Go is available
    if command -v go &> /dev/null; then
        TEMP_DIR=$(mktemp -d)
        git clone "https://github.com/$GITHUB_REPO.git" "$TEMP_DIR/chaos-memory" 2>/dev/null || {
            error "Cannot clone repo. Ensure you have access to the private repository."
        }
        cd "$TEMP_DIR/chaos-memory"
        go build -o "$CHAOS_HOME/bin/chaos-mcp" ./cmd/chaos/
        go build -o "$CHAOS_HOME/bin/chaos-consolidator" ./cmd/consolidator/
        rm -rf "$TEMP_DIR"
        success "Built from source"
    else
        error "Cannot download binaries and Go is not installed. Please install Go or download binaries manually."
    fi
fi

# 5. Download chaos-cli script
SKILL_URL="https://github.com/$GITHUB_REPO/releases/download/$CHAOS_VERSION/chaos-memory-skill.tar.gz"
if curl -fsSL "$SKILL_URL" -o "/tmp/chaos-skill.tar.gz" 2>/dev/null; then
    tar -xzf /tmp/chaos-skill.tar.gz -C "/tmp/"
    cp /tmp/chaos-memory-skill/scripts/chaos-cli "$CHAOS_HOME/bin/" 2>/dev/null || true
    rm -rf /tmp/chaos-skill.tar.gz /tmp/chaos-memory-skill
fi

# Make sure chaos-cli exists (create if not downloaded)
if [ ! -f "$CHAOS_HOME/bin/chaos-cli" ]; then
    # Download from raw GitHub or create minimal version
    cat > "$CHAOS_HOME/bin/chaos-cli" << 'EOFCLI'
#!/bin/bash
# CHAOS CLI - Minimal wrapper
CHAOS_HOME="${CHAOS_HOME:-$HOME/.chaos}"
DB_PATH="$CHAOS_HOME/db"
cd "$DB_PATH" 2>/dev/null || { echo "Database not found at $DB_PATH"; exit 1; }

case "$1" in
    search) shift; dolt sql -q "SELECT id, SUBSTRING(content,1,100) as preview, category, priority FROM memories WHERE content LIKE '%$1%' LIMIT ${2:-10};" ;;
    list) dolt sql -q "SELECT id, SUBSTRING(content,1,80), category, priority FROM memories ORDER BY created_at DESC LIMIT ${2:-10};" ;;
    *) echo "Usage: chaos-cli search \"query\" | list [N]" ;;
esac
EOFCLI
fi

chmod +x "$CHAOS_HOME/bin/"*
success "CLI tools installed"

# 6. Initialize database
if [ ! -d "$CHAOS_HOME/db/.dolt" ]; then
    echo "Initializing database..."
    cd "$CHAOS_HOME/db"
    dolt init --name "chaos" --email "chaos@local"
    dolt sql -q "CREATE TABLE IF NOT EXISTS memories (
        id VARCHAR(36) PRIMARY KEY,
        content TEXT NOT NULL,
        owner_id VARCHAR(64) NOT NULL DEFAULT 'system',
        category VARCHAR(50) DEFAULT 'semantic',  -- Flexible categories (NOT enum)
        priority FLOAT DEFAULT 0.5,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        accessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        access_count INT DEFAULT 0,
        source VARCHAR(255) DEFAULT '',
        tags JSON,
        embedding BLOB,
        team_id VARCHAR(64) DEFAULT 'system'
    ) COMMENT='Local development database with flexible categories';"
    dolt sql -q "CREATE TABLE IF NOT EXISTS edges (
        id VARCHAR(36) PRIMARY KEY,
        source_id VARCHAR(36),
        target_id VARCHAR(36),
        relation VARCHAR(50),
        weight FLOAT DEFAULT 1.0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );"
    dolt add .
    dolt commit -m "Initialize CHAOS database"
    success "Database initialized"
else
    success "Database exists"
fi

# 7. Copy config templates
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/config/consolidator.template.yaml" ]; then
    cp "$SCRIPT_DIR/config/consolidator.template.yaml" "$CHAOS_HOME/config/"
    # Create active config from template
    sed "s|~/.chaos|$CHAOS_HOME|g" "$SCRIPT_DIR/config/consolidator.template.yaml" > "$CHAOS_HOME/config/consolidator.yaml"
    success "Config templates copied"
else
    warn "Config templates not found, creating basic config"
    cat > "$CHAOS_HOME/config/consolidator.yaml" << 'EOF'
polling:
  interval: 10m
  batch_size: 50
  state_file: ~/.chaos/consolidator-state.json

qwen:
  provider: ollama
  model: qwen3:1.7b
  ollama:
    host: http://localhost:11434
    num_threads: 0
    num_ctx: 8192
    keep_alive: 24h

chaos:
  mode: mcp
  mcp:
    command: chaos-mcp
    env:
      CHAOS_DB_PORT: "3307"

auto_capture:
  enabled: true
  mode: transcript
  sources:
    - ~/.openclaw-*/agents/*/sessions/*.jsonl
    - ~/.clawdbot-*/agents/*/sessions/*.jsonl

extraction:
  min_confidence: 0.7
  categories:
    - core
    - semantic
    - working
    - episodic

logging:
  level: info
  file: ~/.chaos/consolidator.log
EOF
fi

# Copy service template
if [ -f "$SCRIPT_DIR/config/chaos-consolidator.service.template" ]; then
    cp "$SCRIPT_DIR/config/chaos-consolidator.service.template" "$CHAOS_HOME/config/"
    success "Service template copied"
fi

# Copy setup scripts
if [ -f "$SCRIPT_DIR/scripts/setup-service.sh" ]; then
    cp "$SCRIPT_DIR/scripts/setup-service.sh" "$CHAOS_HOME/bin/"
    chmod +x "$CHAOS_HOME/bin/setup-service.sh"
    success "Setup scripts copied"
fi

# 8. Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✓ CHAOS Memory installed successfully!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Add to your shell profile (.bashrc, .zshrc):"
echo ""
echo "  export CHAOS_HOME=\"$CHAOS_HOME\""
echo "  export PATH=\"\$CHAOS_HOME/bin:\$PATH\""
echo ""
echo "Start the database:"
echo "  cd $CHAOS_HOME/db && dolt sql-server --port 3307 &"
echo ""
echo "Test installation:"
echo "  chaos-cli list"
echo ""
echo "Pull AI model (for auto-capture):"
echo "  ollama pull qwen3:1.7b"
echo ""
echo "Start consolidator (daemon mode - continuous):"
echo "  chaos-consolidator --config \$CHAOS_HOME/config/config.yaml &"
echo ""
echo "Start consolidator (one-shot - process once):"
echo "  chaos-consolidator --auto-capture --config \$CHAOS_HOME/config/consolidator.yaml --once"
echo ""
echo "Set up systemd service (auto-restart):"
echo "  \$CHAOS_HOME/bin/setup-service.sh"
echo "  sudo systemctl start chaos-consolidator"
echo ""
echo "Check logs:"
echo "  tail -f ~/.chaos/consolidator.log"
echo "  sudo journalctl -u chaos-consolidator -f"
echo ""
echo "Documentation:"
echo "  cat \$CHAOS_HOME/skill/INSTALL_NOTES.md"
echo ""
