#!/bin/sh

set -eu

ARCH=$(uname -m)
#VERSION=$(pacman -Q PACKAGENAME | awk '{print $2; exit}') # example command to get version of application here
#export VERSION
export ARCH
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export ICON=/usr/share/icons/hicolor/scalable/apps/io.github.fastrizwaan.WineZGUI.svg
export DESKTOP=/usr/share/applications/io.github.fastrizwaan.WineZGUI.desktop
export STARTUPWMCLASS=io.github.fastrizwaan.WineZGUI
export STRACE_BINARY=winezgui
export MAIN_BIN=winezgui-wrapper

# Deploy dependencies
quick-sharun \
  /usr/bin/winezgui  \
  /usr/share/winezgui \
  /usr/bin/vendor_perl/exiftool

# Additional changes can be done in between here

# fail-fast: prove modules were deployed (layout-independent)
if ! find ./AppDir -name winezgui-source -print | grep -q .; then
  echo "winezgui-source missing!"
  ls -R ./AppDir || true
  exit 1
fi
find ./AppDir -name winezgui-source -print

# make DATADIR relocatable: respect wrapper's $DATADIR if valid,
# and self-locate under $APPDIR when run without the wrapper
# (covers MAIN_BIN being ignored and direct winezgui exec).
# No awk: build a snippet file once, then `sed r` it in after DATADIR.
SNIPPET="$(mktemp)"
cat > "$SNIPPET" <<'SNIPPET_EOF'
# AppImage-DATADIR-fallback: relocatable lookup when /usr/share is missing
if [ ! -f "${DATADIR}/winezgui-source" ]; then
  _appdir="${APPDIR:-${APPIMAGE_MOUNT:-}}"
  if [ -z "$_appdir" ]; then
    _here="$(dirname "$(readlink -f "$0")")"
    case "$_here" in
      */usr/bin) _appdir="$(dirname "$(dirname "$_here")")" ;;
      */bin) _appdir="$(dirname "$_here")" ;;
      *) _appdir="$_here" ;;
    esac
  fi
  for _d in "$_appdir/usr/share/winezgui" "$_appdir/share/winezgui"; do
    if [ -f "$_d/winezgui-source" ]; then
      DATADIR="$_d"
      break
    fi
  done
  unset _appdir _d _here
fi
SNIPPET_EOF
PATCHED=0
# Patch every shipped script with a hardcoded DATADIR, notably:
# bin/winezgui and share/winezgui/winezgui-create-prefix (the prefix
# script generator — without this, new prefixes copy zero modules and
# their launch scripts fail with dbug/SOURCE not found).
for _f in $(grep -rl '^export DATADIR=' ./AppDir 2>/dev/null || true); do
  case "$_f" in
    "$SNIPPET"|./AppDir/.datadir-fallback.snippet) continue ;;
  esac
  sed -i 's|^export DATADIR=.*|export DATADIR="${DATADIR:-/usr/share/winezgui}"|' "$_f"
  if ! grep -q 'AppImage-DATADIR-fallback' "$_f"; then
    # `r` preserves the executable bit (unlike awk > tmp && mv).
    sed -i "/^export DATADIR=/r $SNIPPET" "$_f"
  fi
  PATCHED=$((PATCHED + 1))
done
rm -f "$SNIPPET"
if [ "$PATCHED" -eq 0 ]; then
  echo "No winezgui binary found to patch!"
  ls -R ./AppDir || true
  exit 1
fi
echo "Patched DATADIR in $PATCHED file(s)."
chmod +x ./AppDir/bin/winezgui-wrapper 2>/dev/null || true

# Install latest winetricks
wget --retry-connrefused --tries=30 https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks -O ./AppDir/bin/winetricks
chmod +x ./AppDir/bin/winetricks

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds, if the test fails due to the app
# having issues running in the CI use --simple-test instead
quick-sharun --simple-test ./dist/*.AppImage
