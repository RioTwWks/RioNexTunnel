#!/usr/bin/env bash
# Agent B — full RU/EN localization bootstrap (run from repo root)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/secure_vpn_client"
cd "$APP"

# --- pubspec ---
python3 - <<'PY'
from pathlib import Path
p = Path('pubspec.yaml')
t = p.read_text()
if 'flutter_localizations' not in t:
    t = t.replace('  flutter:\n    sdk: flutter\n  flutter_riverpod:', '  flutter:\n    sdk: flutter\n  flutter_localizations:\n    sdk: flutter\n  flutter_riverpod:')
if 'generate: true' not in t:
    t = t.replace('flutter:\n\n  # The following line ensures', 'flutter:\n  generate: true\n\n  # The following line ensures')
p.write_text(t)
PY

cat > l10n.yaml <<'EOF'
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
nullable-getter: false
EOF

# --- ARB files (inline generator) ---
python3 "$ROOT/scripts/gen_l10n_arb.py"

flutter pub get
flutter gen-l10n

echo "✓ l10n infrastructure ready"
