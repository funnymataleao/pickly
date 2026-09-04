#!/bin/sh

set -eu

if [ "${CONFIGURATION:-}" != "Release" ]; then
    exit 0
fi

missing_settings=""

for setting in \
    GOOGLE_IOS_CLIENT_ID \
    GOOGLE_REVERSED_CLIENT_ID \
    FIREBASE_API_KEY \
    FIREBASE_APP_ID \
    FIREBASE_GCM_SENDER_ID \
    FIREBASE_PROJECT_ID \
    PICKLY_API_BASE_URL
do
    value="$(printenv "$setting" 2>/dev/null || true)"
    case "$value" in
        ""|PASTE_*|'$('*')')
            missing_settings="${missing_settings} ${setting}"
            ;;
    esac
done

api_base_url="$(printenv PICKLY_API_BASE_URL 2>/dev/null || true)"
case "$api_base_url" in
    https://*.*) ;;
    *)
        missing_settings="${missing_settings} PICKLY_API_BASE_URL(HTTPS URL with host)"
        ;;
esac

if [ -n "$missing_settings" ]; then
    echo "error: Release configuration is missing:${missing_settings}. Configure CI build settings or Config/Local.xcconfig before archiving." >&2
    exit 1
fi

firebase_sender_id="$(printenv FIREBASE_GCM_SENDER_ID)"
google_ios_client_id="$(printenv GOOGLE_IOS_CLIENT_ID)"
google_reversed_client_id="$(printenv GOOGLE_REVERSED_CLIENT_ID)"

case "$google_ios_client_id" in
    "$firebase_sender_id"-*.apps.googleusercontent.com)
        google_ios_client_key="${google_ios_client_id%.apps.googleusercontent.com}"
        ;;
    *)
        echo "error: GOOGLE_IOS_CLIENT_ID does not belong to FIREBASE_GCM_SENDER_ID." >&2
        exit 1
        ;;
esac

if [ "$google_reversed_client_id" != "com.googleusercontent.apps.$google_ios_client_key" ]; then
    echo "error: GOOGLE_REVERSED_CLIENT_ID does not match GOOGLE_IOS_CLIENT_ID." >&2
    exit 1
fi
