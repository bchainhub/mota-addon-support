#!/usr/bin/env bash
set -euo pipefail

# Remove support route files added by support install (paths relative to project root)
SUPPORT_BASE="src/lib/components/support"
rm -f "${SUPPORT_BASE}/+page.svelte"
rm -f "${SUPPORT_BASE}/support.data.ts"

# Remove empty dirs (optional; rmdir no-ops if not empty)
rmdir "${SUPPORT_BASE}" 2>/dev/null || true

# Remove API routes
rm -f "src/routes/api/[version]/support/ai/+server.ts"

# Remove empty dirs for API routes
rmdir "src/routes/api/[version]/support/ai" 2>/dev/null || true
