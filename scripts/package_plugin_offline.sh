#!/usr/bin/env bash

set -euo pipefail

PLUGIN_AUTHOR=${PLUGIN_AUTHOR:?PLUGIN_AUTHOR is required}
PLUGIN_NAME=${PLUGIN_NAME:?PLUGIN_NAME is required}
PLUGIN_VERSION=${PLUGIN_VERSION:?PLUGIN_VERSION is required}
PIP_PLATFORM=${PIP_PLATFORM:?PIP_PLATFORM is required}
PACKAGE_SUFFIX=${PACKAGE_SUFFIX:?PACKAGE_SUFFIX is required}
MARKETPLACE_API_URL=${MARKETPLACE_API_URL:-https://marketplace.dify.ai}

PACKAGE_BASENAME="${PLUGIN_AUTHOR}-${PLUGIN_NAME}_${PLUGIN_VERSION}"
PACKAGE_FILE="${PACKAGE_BASENAME}.difypkg"
OUTPUT_FILE="${PACKAGE_BASENAME}-${PACKAGE_SUFFIX}.difypkg"

curl -L \
  -o "${PACKAGE_FILE}" \
  "${MARKETPLACE_API_URL}/api/v1/plugins/${PLUGIN_AUTHOR}/${PLUGIN_NAME}/${PLUGIN_VERSION}/download"

rm -rf plugin-src
unzip -o "${PACKAGE_FILE}" -d plugin-src

mkdir -p plugin-src/wheels
python -m pip download \
  --dest plugin-src/wheels \
  --index-url https://pypi.org/simple \
  --only-binary=:all: \
  --platform "${PIP_PLATFORM}" \
  --python-version 312 \
  --implementation cp \
  --abi cp312 \
  -r plugin-src/requirements.txt

python - <<'PY'
from pathlib import Path

requirements = Path('plugin-src/requirements.txt')
content = requirements.read_text()
header = '--no-index --find-links=./wheels/\n'
if not content.startswith(header):
    requirements.write_text(header + content)
PY

rm -f plugin-src/pyproject.toml plugin-src/uv.lock

for ignore_file in plugin-src/.difyignore plugin-src/.gitignore; do
  if [ -f "$ignore_file" ]; then
    sed -i '/^wheels\//d' "$ignore_file"
  fi
done

chmod +x ./dify-plugin-linux-amd64
./dify-plugin-linux-amd64 plugin package \
  plugin-src \
  -o "${OUTPUT_FILE}" \
  --max-size 5120

echo "OUTPUT_FILE=${OUTPUT_FILE}" >> "$GITHUB_ENV"
echo "RELEASE_TAG=${PLUGIN_NAME}-${PLUGIN_VERSION}-${PACKAGE_SUFFIX}" >> "$GITHUB_ENV"
echo "RELEASE_NAME=${PLUGIN_NAME} ${PLUGIN_VERSION} ${PACKAGE_SUFFIX}" >> "$GITHUB_ENV"
