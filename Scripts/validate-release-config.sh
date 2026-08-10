#!/bin/sh

set -eu

if [ "${CONFIGURATION:-}" != "Release" ]; then
    exit 0
fi

missing_settings=""

for setting in \
    SUPABASE_URL \
    SUPABASE_PUBLISHABLE_KEY \
    GOOGLE_IOS_CLIENT_ID \
    GOOGLE_SERVER_CLIENT_ID \
    GOOGLE_REVERSED_CLIENT_ID
do
    value="$(printenv "$setting" 2>/dev/null || true)"
    case "$value" in
        ""|PASTE_*|'$('*')')
            missing_settings="${missing_settings} ${setting}"
            ;;
    esac
done

if [ -n "$missing_settings" ]; then
    echo "error: Release configuration is missing:${missing_settings}. Configure CI build settings or Config/Local.xcconfig before archiving." >&2
    exit 1
fi
