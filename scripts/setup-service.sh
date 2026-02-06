#!/bin/bash
# CHAOS - Install systemd service
# Usage: ./setup-service.sh

set -e

CHAOS_HOME="${CHAOS_HOME:-$HOME/.chaos}"
USER_NAME="$(whoami)"

echo "🔧 Setting up CHAOS consolidator service..."

# Check if template exists
if [ ! -f "$CHAOS_HOME/config/chaos-consolidator.service.template" ]; then
    echo "❌ Service template not found at $CHAOS_HOME/config/chaos-consolidator.service.template"
    exit 1
fi

# Create service file from template
TEMP_SERVICE="/tmp/chaos-consolidator.service"
cat "$CHAOS_HOME/config/chaos-consolidator.service.template" \
    | sed "s|%USER%|$USER_NAME|g" \
    | sed "s|%CHAOS_HOME%|$CHAOS_HOME|g" \
    > "$TEMP_SERVICE"

echo "📋 Service file created"

# Install service
if command -v systemctl &> /dev/null; then
    echo "Installing systemd service..."
    sudo cp "$TEMP_SERVICE" /etc/systemd/system/chaos-consolidator.service
    sudo systemctl daemon-reload
    sudo systemctl enable chaos-consolidator.service
    echo "✅ Service installed and enabled"
    echo ""
    echo "Start with: sudo systemctl start chaos-consolidator"
    echo "Status: systemctl status chaos-consolidator"
    echo "Logs: sudo journalctl -u chaos-consolidator -f"
else
    echo "⚠️  systemd not available. Service file saved to: $TEMP_SERVICE"
    echo "You can run manually with:"
    echo "  $CHAOS_HOME/bin/chaos-consolidator --config $CHAOS_HOME/config/consolidator.yaml --auto-capture &"
fi

rm -f "$TEMP_SERVICE"
