#!/usr/bin/env bash
# Installs the shared libraries Playwright's headless Chromium needs.
#
# Tries the normal root path first (`playwright install --with-deps`).
# If that fails because there's no root/sudo in this container (common
# in restricted devcontainers), falls back to downloading the .deb
# packages with `apt-get download` (works unprivileged) and extracting
# them with `dpkg -x` into $DEPS_DIR, no root required. driver.mjs
# detects $DEPS_DIR and points LD_LIBRARY_PATH / FONTCONFIG_FILE at it.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPS_DIR="${CHROME_DEPS_DIR:-$HOME/.cache/phpcalculator-chrome-deps}"

echo "Installing Playwright's chromium browser binary..."
(cd "$SCRIPT_DIR" && npx playwright install chromium)

if (cd "$SCRIPT_DIR" && npx playwright install-deps chromium) 2>/tmp/pw-deps-err.$$; then
  echo "System deps installed via root/sudo. No fallback needed."
  rm -f /tmp/pw-deps-err.$$
  exit 0
fi
echo "Root install-deps failed (expected in a no-root container):"
cat /tmp/pw-deps-err.$$ | tail -5
rm -f /tmp/pw-deps-err.$$

echo "Falling back to unprivileged extraction into $DEPS_DIR ..."
PKGS="at-spi2-common fontconfig fontconfig-config fonts-freefont-ttf fonts-ipafont-gothic fonts-liberation fonts-noto-color-emoji fonts-tlwg-loma-otf fonts-unifont fonts-wqy-zenhei libasound2-data libasound2t64 libatk-bridge2.0-0t64 libatk1.0-0t64 libatspi2.0-0t64 libavahi-client3 libavahi-common-data libavahi-common3 libcairo2 libcups2t64 libdatrie1 libdbus-1-3 libdrm-amdgpu1 libdrm-common libdrm-intel1 libdrm2 libfontconfig1 libfontenc1 libfreetype6 libfribidi0 libgbm1 libgl1 libgl1-mesa-dri libglib2.0-0t64 libglvnd0 libglx-mesa0 libglx0 libgraphite2-3 libharfbuzz0b libice6 libllvm19 libnspr4 libnss3 libpango-1.0-0 libpciaccess0 libpixman-1-0 libpng16-16t64 libsensors-config libsensors5 libsm6 libthai-data libthai0 libvulkan1 libwayland-server0 libx11-6 libx11-data libx11-xcb1 libxau6 libxaw7 libxcb-dri3-0 libxcb-glx0 libxcb-present0 libxcb-randr0 libxcb-render0 libxcb-shm0 libxcb-sync1 libxcb-xfixes0 libxcb1 libxcomposite1 libxdamage1 libxdmcp6 libxext6 libxfixes3 libxfont2 libxi6 libxkbcommon0 libxkbfile1 libxmu6 libxpm4 libxrandr2 libxrender1 libxshmfence1 libxt6t64 libxxf86vm1 libz3-4 mesa-libgallium x11-common x11-xkb-utils xfonts-encodings xfonts-scalable xfonts-utils xkb-data xserver-common xvfb"

DEB_DIR="$(mktemp -d)"
(cd "$DEB_DIR" && apt-get download $PKGS)

mkdir -p "$DEPS_DIR"
for f in "$DEB_DIR"/*.deb; do
  dpkg -x "$f" "$DEPS_DIR"
done
rm -rf "$DEB_DIR"

# fonts.conf's <dir> entries point at /usr/share/fonts, which fc-cache
# won't follow from our relocated prefix — write one that points at
# $DEPS_DIR directly, with a cache dir we can actually write to.
mkdir -p "$DEPS_DIR/fontconfig-cache"
cat > "$DEPS_DIR/fonts.conf" <<EOF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
	<dir>$DEPS_DIR/usr/share/fonts</dir>
	<cachedir>$DEPS_DIR/fontconfig-cache</cachedir>
</fontconfig>
EOF

LD_LIBRARY_PATH="$DEPS_DIR/usr/lib/x86_64-linux-gnu:$DEPS_DIR/usr/lib/x86_64-linux-gnu/dri" \
FONTCONFIG_FILE="$DEPS_DIR/fonts.conf" \
  "$DEPS_DIR/usr/bin/fc-cache" -f

echo "Done. Extracted to $DEPS_DIR ($(du -sh "$DEPS_DIR" | cut -f1))."
echo "driver.mjs auto-detects this directory - no further setup needed."
