#!/usr/bin/env bash
set -euo pipefail

VERSION="1.1.1"
BUILD_DIR="build"
DIST_DIR="dist"
ARCH="x64"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--version)
      VERSION="$2"
      shift 2
      ;;
    -b|--build-dir)
      BUILD_DIR="$2"
      shift 2
      ;;
    -d|--dist-dir)
      DIST_DIR="$2"
      shift 2
      ;;
    -a|--arch)
      ARCH="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Packaging 0rhxPlayer AppImage v${VERSION} for Linux (${ARCH}) ==="

BUILD_FULL_PATH="${ROOT_DIR}/${BUILD_DIR}"
DIST_FULL_PATH="${ROOT_DIR}/${DIST_DIR}"
APP_DIR="${DIST_FULL_PATH}/0rhxPlayer.AppDir"

# 1. Locate executable binary
EXE_SRC="${BUILD_FULL_PATH}/0rhxPlayer"
if [[ ! -f "${EXE_SRC}" ]]; then
  echo "Error: Binary not found at ${EXE_SRC}! Please build target first." >&2
  exit 1
fi

rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/usr/bin"
mkdir -p "${APP_DIR}/usr/lib"
mkdir -p "${APP_DIR}/usr/plugins"
mkdir -p "${APP_DIR}/usr/qml"
mkdir -p "${APP_DIR}/usr/share/applications"
mkdir -p "${APP_DIR}/usr/share/icons/hicolor/scalable/apps"
mkdir -p "${DIST_FULL_PATH}"

# 2. Copy binary
cp "${EXE_SRC}" "${APP_DIR}/usr/bin/0rhxPlayer"
chmod +x "${APP_DIR}/usr/bin/0rhxPlayer"

# 3. Copy BASS shared libraries
BASS_DIR="${ROOT_DIR}/libs/bass/linux-${ARCH}/lib"
if [[ -d "${BASS_DIR}" ]]; then
  cp "${BASS_DIR}"/*.so "${APP_DIR}/usr/lib/"
  cp "${BASS_DIR}"/*.so "${APP_DIR}/usr/bin/"
  echo "Copied BASS runtime libraries from ${BASS_DIR}."
else
  echo "Warning: BASS directory not found at ${BASS_DIR}." >&2
fi

# 4. Copy Assets and Translations
if [[ -d "${ROOT_DIR}/assets" ]]; then
  cp -r "${ROOT_DIR}/assets" "${APP_DIR}/usr/bin/"
  cp -r "${ROOT_DIR}/assets" "${APP_DIR}/"
fi
mkdir -p "${APP_DIR}/usr/bin/translations" "${APP_DIR}/translations"
if compgen -G "${ROOT_DIR}/translations/*.qm" > /dev/null; then
  cp "${ROOT_DIR}/translations"/*.qm "${APP_DIR}/usr/bin/translations/"
  cp "${ROOT_DIR}/translations"/*.qm "${APP_DIR}/translations/"
fi

# 5. Linux Desktop Integration in AppDir
DESKTOP_SRC="${ROOT_DIR}/installer/linux/0rhxplayer.desktop"
ICON_SRC="${ROOT_DIR}/installer/linux/0rhxplayer.svg"
if [[ ! -f "${ICON_SRC}" && -f "${ROOT_DIR}/assets/icons/app_icon.svg" ]]; then
  ICON_SRC="${ROOT_DIR}/assets/icons/app_icon.svg"
fi

cp "${DESKTOP_SRC}" "${APP_DIR}/0rhxplayer.desktop"
cp "${DESKTOP_SRC}" "${APP_DIR}/usr/share/applications/0rhxplayer.desktop"
cp "${ICON_SRC}" "${APP_DIR}/0rhxplayer.svg"
cp "${ICON_SRC}" "${APP_DIR}/.DirIcon"
cp "${ICON_SRC}" "${APP_DIR}/usr/share/icons/hicolor/scalable/apps/0rhxplayer.svg"

# 6. Copy Qt Plugins and Shared Libraries (if available in environment)
QT_LOCATIONS=(
  "${QT_ROOT_DIR:-}"
  "${QT_DIR:-}"
  "${Qt6_DIR:-}"
  "/home/runner/work/0rhxPlayer-Desktop/Qt/6.8.2/gcc_64"
  "/usr/lib/x86_64-linux-gnu/qt6"
  "/usr/lib/aarch64-linux-gnu/qt6"
  "/usr/lib/qt6"
)

for qdir in "${QT_LOCATIONS[@]}"; do
  if [[ -n "$qdir" && -d "$qdir/plugins" ]]; then
    echo "Deploying Qt plugins from $qdir/plugins..."
    cp -r "$qdir/plugins"/* "${APP_DIR}/usr/plugins/" 2>/dev/null || true
  fi
  if [[ -n "$qdir" && -d "$qdir/qml" ]]; then
    echo "Deploying Qt QML modules from $qdir/qml..."
    cp -r "$qdir/qml"/* "${APP_DIR}/usr/qml/" 2>/dev/null || true
  fi
  if [[ -n "$qdir" && -d "$qdir/lib" ]]; then
    echo "Deploying Qt shared libraries from $qdir/lib..."
    cp -d "$qdir/lib"/libQt6*.so* "${APP_DIR}/usr/lib/" 2>/dev/null || true
  fi
done

# 7. Create AppRun Entrypoint Script
cat > "${APP_DIR}/AppRun" << 'EOF'
#!/usr/bin/env bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$HERE/usr/bin:$HERE/bin:$PATH"
export LD_LIBRARY_PATH="$HERE/usr/lib:$HERE/lib:$HERE/usr/bin:$HERE:${LD_LIBRARY_PATH:-}"
export QT_PLUGIN_PATH="$HERE/usr/plugins:$HERE/plugins:${QT_PLUGIN_PATH:-}"
export QML_IMPORT_PATH="$HERE/usr/qml:$HERE/qml:${QML_IMPORT_PATH:-}"
export QML2_IMPORT_PATH="$HERE/usr/qml:$HERE/qml:${QML2_IMPORT_PATH:-}"
export XDG_DATA_DIRS="$HERE/usr/share:${XDG_DATA_DIRS:-}"
exec "$HERE/usr/bin/0rhxPlayer" "$@"
EOF
chmod +x "${APP_DIR}/AppRun"

# 8. Obtain appimagetool and generate .AppImage
HOST_ARCH="$(uname -m)"
APPIMAGE_ARCH="x86_64"
if [[ "${ARCH}" == "arm64" || "${ARCH}" == "aarch64" ]]; then
  APPIMAGE_ARCH="aarch64"
fi

APPIMAGE_OUTPUT="${DIST_FULL_PATH}/0rhxPlayer-v${VERSION}-linux-${ARCH}.AppImage"
rm -f "${APPIMAGE_OUTPUT}"

TOOLS_DIR="${ROOT_DIR}/tools"
mkdir -p "${TOOLS_DIR}"

APPIMAGETOOL_BIN=""
if command -v appimagetool >/dev/null 2>&1; then
  APPIMAGETOOL_BIN="appimagetool"
elif [[ -x "${TOOLS_DIR}/appimagetool" ]]; then
  APPIMAGETOOL_BIN="${TOOLS_DIR}/appimagetool"
fi

if [[ -z "${APPIMAGETOOL_BIN}" ]]; then
  TOOL_DOWNLOAD_ARCH="x86_64"
  if [[ "${HOST_ARCH}" == "aarch64" || "${HOST_ARCH}" == "arm64" ]]; then
    TOOL_DOWNLOAD_ARCH="aarch64"
  fi
  TOOL_URL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${TOOL_DOWNLOAD_ARCH}.AppImage"
  echo "Downloading appimagetool (${TOOL_DOWNLOAD_ARCH}) from ${TOOL_URL}..."
  if ! curl -fsSL -o "${TOOLS_DIR}/appimagetool" "${TOOL_URL}"; then
    FALLBACK_URL="https://github.com/AppImage/AppImageKit/releases/download/13/appimagetool-${TOOL_DOWNLOAD_ARCH}.AppImage"
    echo "Falling back to AppImageKit release 13..."
    curl -fsSL -o "${TOOLS_DIR}/appimagetool" "${FALLBACK_URL}"
  fi
  chmod +x "${TOOLS_DIR}/appimagetool"
  APPIMAGETOOL_BIN="${TOOLS_DIR}/appimagetool"
fi

# Extract appimagetool if running as an AppImage to circumvent FUSE restrictions on CI
EXTRACTED_DIR="${TOOLS_DIR}/appimagetool-extracted"
if [[ -f "${APPIMAGETOOL_BIN}" && ! -d "${EXTRACTED_DIR}" ]]; then
  echo "Extracting appimagetool to bypass CI FUSE requirement..."
  CURR_DIR="$(pwd)"
  cd "${TOOLS_DIR}"
  "${APPIMAGETOOL_BIN}" --appimage-extract >/dev/null 2>&1 || true
  if [[ -d "squashfs-root" ]]; then
    mv squashfs-root "${EXTRACTED_DIR}"
  fi
  cd "${CURR_DIR}"
fi

APPIMAGETOOL_EXEC="${APPIMAGETOOL_BIN}"
if [[ -x "${EXTRACTED_DIR}/AppRun" ]]; then
  APPIMAGETOOL_EXEC="${EXTRACTED_DIR}/AppRun"
fi

echo "Running appimagetool (${APPIMAGE_ARCH}) on ${APP_DIR}..."
if ! ARCH="${APPIMAGE_ARCH}" "${APPIMAGETOOL_EXEC}" --no-appstream "${APP_DIR}" "${APPIMAGE_OUTPUT}" 2>&1; then
  echo "appimagetool execution had errors or was unavailable. Falling back to mksquashfs + type2-runtime..."
fi

if [[ ! -f "${APPIMAGE_OUTPUT}" || ! -s "${APPIMAGE_OUTPUT}" ]]; then
  echo "Generating AppImage via mksquashfs and runtime-${APPIMAGE_ARCH}..."
  RUNTIME_BIN="${TOOLS_DIR}/runtime-${APPIMAGE_ARCH}"
  if [[ ! -f "${RUNTIME_BIN}" ]]; then
    curl -fsSL -o "${RUNTIME_BIN}" "https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-${APPIMAGE_ARCH}" || \
    curl -fsSL -o "${RUNTIME_BIN}" "https://raw.githubusercontent.com/AppImage/AppImageKit/master/resources/runtime-${APPIMAGE_ARCH}"
  fi
  chmod +x "${RUNTIME_BIN}"
  SQUASHFS_TMP="${DIST_FULL_PATH}/temp_app.squashfs"
  rm -f "${SQUASHFS_TMP}"
  if command -v mksquashfs >/dev/null 2>&1; then
    mksquashfs "${APP_DIR}" "${SQUASHFS_TMP}" -root-owned -noappend -comp zstd 2>/dev/null || \
    mksquashfs "${APP_DIR}" "${SQUASHFS_TMP}" -root-owned -noappend -comp xz 2>/dev/null || \
    mksquashfs "${APP_DIR}" "${SQUASHFS_TMP}" -root-owned -noappend
  else
    "${EXTRACTED_DIR}/usr/lib/appimagekit/mksquashfs" "${APP_DIR}" "${SQUASHFS_TMP}" -root-owned -noappend -comp zstd 2>/dev/null || \
    "${EXTRACTED_DIR}/usr/lib/appimagekit/mksquashfs" "${APP_DIR}" "${SQUASHFS_TMP}" -root-owned -noappend
  fi
  cat "${RUNTIME_BIN}" "${SQUASHFS_TMP}" > "${APPIMAGE_OUTPUT}"
  rm -f "${SQUASHFS_TMP}"
fi

chmod +x "${APPIMAGE_OUTPUT}"
echo "Successfully generated: ${APPIMAGE_OUTPUT} ($(du -h "${APPIMAGE_OUTPUT}" | cut -f1))"
echo "=== Linux AppImage Packaging Complete ==="
