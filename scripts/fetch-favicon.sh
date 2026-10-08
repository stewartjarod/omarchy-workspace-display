#!/usr/bin/env bash
# Fetch a web app's icon from its own site into the bar's icon cache.
#
# Usage: fetch-favicon.sh <host> <out.png>   (no-op if <out.png> exists)
#
# Tries, in order: the page's apple-touch-icon / icon <link> tags (largest
# first), then /apple-touch-icon.png, then /favicon.ico. Only the site itself is
# contacted first. Writes a 64px PNG, atomically; exits non-zero if nothing usable was
# found, leaving no file behind. If the site yields nothing, falls back to
# Google's favicon service (https://www.google.com/s2/favicons).
set -uo pipefail

host=${1:?host}
out=${2:?output path}

[[ $host =~ ^[A-Za-z0-9.-]+$ ]] || { echo "bad host: $host" >&2; exit 2; }

# Already cached: nothing to do.
[[ -s $out ]] && exit 0

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$(dirname "$out")"

curl_() { curl -fsSL --max-time 10 --proto '=https' --proto-redir '=https' -A "Mozilla/5.0" "$@"; }

# Candidate icon URLs from the page, apple-touch-icon first, larger sizes first.
candidates() {
  local base="https://$host/"
  curl_ "$base" 2>/dev/null | tr '\n' ' ' | grep -oiE '<link[^>]+>' | while read -r tag; do
    rel=$(grep -oiE 'rel="[^"]*"' <<<"$tag" | head -1 | cut -d'"' -f2)
    href=$(grep -oiE 'href="[^"]*"' <<<"$tag" | head -1 | cut -d'"' -f2)
    [[ -n $href && $rel =~ icon ]] || continue
    size=$(grep -oiE 'sizes="[0-9]+' <<<"$tag" | grep -oE '[0-9]+' | head -1)
    [[ $rel =~ apple ]] && rank=1000 || rank=0
    echo "$((rank + ${size:-0})) $href"
  done | sort -rn | cut -d' ' -f2- | while read -r href; do
    case $href in
      https://*) echo "$href" ;;
      //*) echo "https:$href" ;;
      /*) echo "https://$host$href" ;;
      http://*) ;;
      *) echo "${base}${href}" ;;
    esac
  done
  echo "https://$host/apple-touch-icon.png"
  echo "https://$host/favicon.ico"
  # Last resort: Google's favicon service, for sites that block scraping or
  # publish no icon. This tells Google which host we looked up.
  echo "https://www.google.com/s2/favicons?domain=$host&sz=64"
}

while read -r url; do
  curl_ -o "$tmp/raw" "$url" 2>/dev/null || continue
  # [0] picks the first frame of an .ico or animated image.
  magick "$tmp/raw[0]" -background none -resize 64x64 -gravity center -extent 64x64 "$tmp/icon.png" 2>/dev/null || continue
  mv "$tmp/icon.png" "$out"
  exit 0
done < <(candidates)

echo "no icon found for $host" >&2
exit 1
