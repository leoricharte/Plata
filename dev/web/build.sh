#!/bin/sh
# Compila la app para web.plataapp.net (Cloudflare Pages).
# Cloudflare Pages → Build command: sh dev/web/build.sh   ·   Build output directory: dist-web
set -e
cd "$(dirname "$0")/../.."
python3 dev/app/build.py
rm -rf dist-web && mkdir -p dist-web
cp dev/app/out/finanzas.html dist-web/index.html
cp dev/web/sw.js dev/web/_headers app/manifest.webmanifest app/icon-180.png app/icon-192.png app/icon-512.png dist-web/
echo "dist-web listo"
