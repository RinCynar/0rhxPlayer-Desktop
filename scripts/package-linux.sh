#!/usr/bin/env bash
set -euo pipefail

VERSION="1.1.0"
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

echo "=== Packaging 0rhxPlayer v${VERSION} for Linux (${ARCH}) ==="

STAGE_DIR="${ROOT_DIR}/${DIST_DIR}/0rhxPlayer"
DIST_FULL_PATH="${ROOT_DIR}/${DIST_DIR}"

rm -rf "${STAGE_DIR}"
mkdir -p "${STAGE_DIR}" "${DIST_FULL_PATH}"

# 1. Binary executable
EXE_SRC="${ROOT_DIR}/${BUILD_DIR}/0rhxPlayer"
if [[ ! -f "${EXE_SRC}" ]]; then
  echo "Error: Binary not found at ${EXE_SRC}! Please build the project first." >&2
  exit 1
fi
cp "${EXE_SRC}" "${STAGE_DIR}/0rhxPlayer"
chmod +x "${STAGE_DIR}/0rhxPlayer"

# 2. Portable mode marker
touch "${STAGE_DIR}/portable.dat"

# 3. BASS shared libraries
BASS_DIR="${ROOT_DIR}/libs/bass/linux-${ARCH}/lib"
if [[ -d "${BASS_DIR}" ]]; then
  cp "${BASS_DIR}"/*.so "${STAGE_DIR}/"
  mkdir -p "${STAGE_DIR}/lib"
  cp "${BASS_DIR}"/*.so "${STAGE_DIR}/lib/"
  echo "Copied BASS runtime libraries from ${BASS_DIR}."
else
  echo "Warning: BASS directory not found at ${BASS_DIR}." >&2
fi

# 4. Assets and Translations
if [[ -d "${ROOT_DIR}/assets" ]]; then
  cp -r "${ROOT_DIR}/assets" "${STAGE_DIR}/"
fi
mkdir -p "${STAGE_DIR}/translations"
if compgen -G "${ROOT_DIR}/translations/*.qm" > /dev/null; then
  cp "${ROOT_DIR}/translations"/*.qm "${STAGE_DIR}/translations/"
fi

# 5. Linux Desktop Integration
if [[ -f "${ROOT_DIR}/installer/linux/0rhxplayer.desktop" ]]; then
  cp "${ROOT_DIR}/installer/linux/0rhxplayer.desktop" "${STAGE_DIR}/0rhxplayer.desktop"
fi
if [[ -f "${ROOT_DIR}/installer/linux/0rhxplayer.svg" ]]; then
  cp "${ROOT_DIR}/installer/linux/0rhxplayer.svg" "${STAGE_DIR}/0rhxplayer.svg"
elif [[ -f "${ROOT_DIR}/assets/icons/app_icon.svg" ]]; then
  cp "${ROOT_DIR}/assets/icons/app_icon.svg" "${STAGE_DIR}/0rhxplayer.svg"
fi

# 6. Launch script
cat > "${STAGE_DIR}/0rhxPlayer.sh" << 'EOF'
#!/usr/bin/env bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LD_LIBRARY_PATH="$HERE:$HERE/lib:${LD_LIBRARY_PATH:-}"
export QML_IMPORT_PATH="$HERE/qml:${QML_IMPORT_PATH:-}"
export QML2_IMPORT_PATH="$HERE/qml:${QML2_IMPORT_PATH:-}"
export QT_PLUGIN_PATH="$HERE/plugins:${QT_PLUGIN_PATH:-}"
exec "$HERE/0rhxPlayer" "$@"
EOF
chmod +x "${STAGE_DIR}/0rhxPlayer.sh"
cp "${STAGE_DIR}/0rhxPlayer.sh" "${STAGE_DIR}/AppRun"
chmod +x "${STAGE_DIR}/AppRun"

# 7. Create Portable tar.gz archives
TAR_NAME_VER="0rhxPlayer-v${VERSION}-linux-${ARCH}-portable.tar.gz"
TAR_NAME_CANON="0rhxPlayer-linux-${ARCH}-portable.tar.gz"

cd "${DIST_FULL_PATH}"
tar -czf "${TAR_NAME_VER}" 0rhxPlayer
cp "${TAR_NAME_VER}" "${TAR_NAME_CANON}"

echo "Created ${TAR_NAME_VER} ($(du -h "${TAR_NAME_VER}" | cut -f1))"
echo "Created ${TAR_NAME_CANON} ($(du -h "${TAR_NAME_CANON}" | cut -f1))"
echo "=== Linux Packaging Complete ==="
