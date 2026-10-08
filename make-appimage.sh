#!/bin/sh

set -eu

ARCH=$(uname -m)
#VERSION=$(pacman -Q PACKAGENAME | awk '{print $2; exit}') # example command to get version of application here
#export VERSION
export ARCH
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook 60-get-zenity.hook"
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
PATCHED=0
for _f in ./AppDir/bin/winezgui ./AppDir/usr/bin/winezgui; do
  if [ -f "$_f" ]; then
    sed -i 's|^export DATADIR=.*|export DATADIR="${DATADIR:-\/usr\/share\/winezgui}"|' "$_f"
    if ! grep -q 'AppImage-DATADIR-fallback' "$_f"; then
      # Insert fallback block right after the DATADIR line.
      _tmp="$(mktemp)"
      awk '
        { print }
        /^export DATADIR=/ && !done {
          print "# AppImage-DATADIR-fallback: relocatable lookup when /usr/share is missing";
          print "if [ ! -f \"${DATADIR}/winezgui-source\" ]; then";
          print "  _appdir=\"${APPDIR:-${APPIMAGE_MOUNT:-}}\"";
          print "  if [ -z \"$_appdir\" ]; then";
          print "    _here=\"$(dirname \"$(readlink -f \"$0\")\")\"";
          print "    case \"$_here\" in";
          print "      */usr/bin) _appdir=\"$(dirname \"$(dirname \"$_here\")\")\" ;;";
          print "      */bin) _appdir=\"$(dirname \"$_here\")\" ;;";
          print "      *) _appdir=\"$_here\" ;;";
          print "    esac";
          print "  fi";
          print "  for _d in \"$_appdir/usr/share/winezgui\" \"$_appdir/share/winezgui\"; do";
          print "    if [ -f \"$_d/winezgui-source\" ]; then";
          print "      DATADIR=\"$_d\"";
          print "      break";
          print "    fi";
          print "  done";
          print "  unset _appdir _d _here";
          print "fi";
          done=1
        }
      ' "$_f" > "$_tmp" && mv "$_tmp" "$_f"
      chmod +x "$_f"
    fi
    PATCHED=$((PATCHED + 1))
  fi
done
if [ "$PATCHED" -eq 0 ]; then
  echo "No winezgui binary found to patch!"
  ls -R ./AppDir || true
  exit 1
fi
chmod +x ./AppDir/bin/winezgui-wrapper 2>/dev/null || true

# Install latest winetricks
wget --retry-connrefused --tries=30 https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks -O ./AppDir/bin/winetricks
chmod +x ./AppDir/bin/winetricks

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds, if the test fails due to the app
# having issues running in the CI use --simple-test instead
quick-sharun --simple-test ./dist/*.AppImage
