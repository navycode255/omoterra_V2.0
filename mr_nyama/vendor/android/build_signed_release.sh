#!/usr/bin/env bash
set -euo pipefail

vendor_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
android_dir="$vendor_dir/android"
keystore="/home/navy/android-signing/mr-nyama/mr-nyama-release.jks"
key_properties="$android_dir/key.properties"
symbol_version_dir="/home/navy/android-signing/mr-nyama/symbols/mrnyama-0.1.0+1"

if [[ ! -f "$keystore" ]]; then
    printf 'Release keystore is missing at the configured path.\n' >&2
    exit 1
fi

if [[ ! -r /dev/tty ]]; then
    printf 'Run this task from a local VS Code terminal to enter passwords securely.\n' >&2
    exit 1
fi

read -r -s -p 'Keystore password (input hidden): ' store_password </dev/tty
printf '\n' >/dev/tty
read -r -s -p 'Key password (input hidden): ' key_password </dev/tty
printf '\n' >/dev/tty

if [[ -z "$store_password" || -z "$key_password" ]]; then
    unset store_password key_password
    printf 'Signing passwords cannot be empty.\n' >&2
    exit 1
fi

escape_property() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//:/\\:}"
    value="${value//=/\\=}"
    value="${value// /\\ }"
    value="${value//#/\\#}"
    value="${value//!/\\!}"
    printf '%s' "$value"
}

umask 077
temporary_properties="$(mktemp "$key_properties.tmp.XXXXXX")"
trap 'rm -f -- "$temporary_properties"; unset store_password key_password' EXIT
{
    printf 'storeFile=%s\n' "$keystore"
    printf 'storePassword=%s\n' "$(escape_property "$store_password")"
    printf 'keyAlias=mrnyama\n'
    printf 'keyPassword=%s\n' "$(escape_property "$key_password")"
} >"$temporary_properties"
chmod 600 "$temporary_properties"
mv -f -- "$temporary_properties" "$key_properties"
unset store_password key_password
trap - EXIT

cd "$vendor_dir"
python3 - "$android_dir/app/google-services.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as config_file:
    config = json.load(config_file)

if config.get("project_info", {}).get("project_id") != "mr-nyama":
    raise SystemExit("Firebase configuration does not target the approved mr-nyama project.")
packages = {
    client.get("client_info", {}).get("android_client_info", {}).get("package_name")
    for client in config.get("client", [])
}
if "com.transmark.mrnyama" not in packages:
    raise SystemExit("Firebase configuration has no client for com.transmark.mrnyama.")
PY
mkdir -p -- "$symbol_version_dir"
chmod 700 "$symbol_version_dir"
symbol_staging_dir="$(mktemp -d "$symbol_version_dir/.staging-XXXXXX")"
chmod 700 "$symbol_staging_dir"
flutter build apk --release \
    --obfuscate \
    --split-debug-info="$symbol_staging_dir" \
    --dart-define=MN_API_URL=https://mrnyama.jopex.co.tz

apk="$vendor_dir/build/app/outputs/flutter-apk/app-release.apk"
if [[ ! -s "$apk" ]]; then
    printf 'Flutter reported success but the release APK is missing or empty.\n' >&2
    exit 1
fi

sdk_dir="$(sed -n 's/^sdk\.dir=//p' "$android_dir/local.properties" | tail -n 1)"
if [[ -z "$sdk_dir" ]]; then
    printf 'Android SDK path is missing from android/local.properties.\n' >&2
    exit 1
fi

aapt="$(find "$sdk_dir/build-tools" -maxdepth 2 -type f -name aapt -print | sort -V | tail -n 1)"
apksigner="$(find "$sdk_dir/build-tools" -maxdepth 2 -type f -name apksigner -print | sort -V | tail -n 1)"
if [[ -z "$aapt" || -z "$apksigner" ]]; then
    printf 'Android aapt or apksigner tool is unavailable in the configured SDK.\n' >&2
    exit 1
fi

firebase_resources="$("$aapt" dump --values resources "$apk")"
if ! grep -Fq '"mr-nyama"' <<<"$firebase_resources" ||
    ! grep -Fq '"1:574531999246:android:773a38f1b0e64197004e5f"' <<<"$firebase_resources"; then
    printf 'Release APK Firebase resources do not match the approved Android client.\n' >&2
    exit 1
fi

badging="$("$aapt" dump badging "$apk")"
package_line="${badging%%$'\n'*}"
if [[ "$package_line" != *"name='com.transmark.mrnyama'"* ]]; then
    printf 'Release APK application ID does not match the configured Mr. Nyama ID.\n' >&2
    exit 1
fi
if [[ "$package_line" != *"versionCode='1'"* || "$package_line" != *"versionName='0.1.0'"* ]]; then
    printf 'Release APK version does not match pubspec.yaml (0.1.0+1).\n' >&2
    exit 1
fi

certificate_report="$("$apksigner" verify --verbose --print-certs "$apk")"
expected_sha256='c123a626647a694ca8db63d62c9a7ebe460f110beda556237afcf2fcde83d950'
# Older apksigner prints "Signer #1 certificate ...", newer prints "V2 Signer: certificate ...".
if ! grep -Eqi "^(Signer #1|V[0-9.]+ Signer:) certificate SHA-256 digest: $expected_sha256\$" <<<"$certificate_report"; then
    printf 'APK signature is invalid or does not match the approved release certificate.\n' >&2
    exit 1
fi

dart_symbols="$(find "$symbol_staging_dir" -maxdepth 1 -type f -name '*.symbols' -print -quit)"
if [[ -z "$dart_symbols" ]]; then
    printf 'Flutter obfuscation symbol files were not generated.\n' >&2
    exit 1
fi

mapping_file="$vendor_dir/build/app/outputs/mapping/release/mapping.txt"
if [[ ! -s "$mapping_file" ]]; then
    printf 'R8 mapping file is missing; the obfuscated release cannot be safely diagnosed.\n' >&2
    exit 1
fi
cp -- "$mapping_file" "$symbol_staging_dir/mapping.txt"
apk_sha256="$(sha256sum "$apk" | cut -d ' ' -f 1)"
printf 'apk_sha256=%s\nversion=0.1.0+1\napplication_id=com.transmark.mrnyama\n' \
    "$apk_sha256" >"$symbol_staging_dir/artifact.txt"
find "$symbol_staging_dir" -maxdepth 1 -type f -exec chmod 600 {} +
symbols_dir="$symbol_version_dir/$apk_sha256-$(date -u +%Y%m%dT%H%M%SZ)-$$"
mv -- "$symbol_staging_dir" "$symbols_dir"

printf '%s\n' "$certificate_report"
printf '\nRelease APK verified:\n%s\n' "$apk"
printf 'Application ID: com.transmark.mrnyama\n'
printf 'Version: 0.1.0 (version code 1)\n'
printf 'Keystore alias: mrnyama\n'
printf 'Obfuscation symbols and R8 mapping: %s\n' "$symbols_dir"
