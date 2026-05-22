#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${ROOT_DIR}/AppStoreScreenshots"
RESULTS_DIR="${OUTPUT_DIR}/results"
RAW_DIR="${OUTPUT_DIR}/raw"
IPAD_DESTINATION="${IPAD_DESTINATION:-platform=iOS Simulator,name=iPad Pro 13-inch (M5)}"
MAC_DESTINATION="${MAC_DESTINATION:-platform=macOS}"

mkdir -p "${RESULTS_DIR}" "${RAW_DIR}/ipad" "${RAW_DIR}/mac"

run_capture() {
  local platform_name="$1"
  local destination="$2"
  local result_bundle="${RESULTS_DIR}/Luna-${platform_name}.xcresult"
  local raw_output="${RAW_DIR}/${platform_name}"

  rm -rf "${result_bundle}"
  xcodebuild test \
    -project "${ROOT_DIR}/Luna.xcodeproj" \
    -scheme Luna \
    -destination "${destination}" \
    -only-testing:LunaUITests/LunaAppStoreScreenshotUITests/testCaptureAppStoreScreenshots \
    -resultBundlePath "${result_bundle}"

  rm -rf "${raw_output}"
  mkdir -p "${raw_output}"
  if xcrun xcresulttool export attachments --path "${result_bundle}" --output-path "${raw_output}" >/dev/null 2>&1; then
    find "${raw_output}" -type f -name "*.png" -print
  else
    echo "Captured ${platform_name} screenshots in ${result_bundle}."
    echo "Export PNG attachments from the result bundle into ${raw_output}."
  fi
}

run_capture "ipad" "${IPAD_DESTINATION}"
run_capture "mac" "${MAC_DESTINATION}"

python3 "${ROOT_DIR}/scripts/generate_screenshot_composites.py" \
  --input "${RAW_DIR}" \
  --output "${OUTPUT_DIR}/composites"
