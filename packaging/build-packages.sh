#!/usr/bin/env bash
#
# Builds .deb and .rpm from an unpacked feeze release tarball.
#
#   ./build-packages.sh 0.001dev /path/to/feeze_0.001dev_Ubuntu_24
#
set -euo pipefail

export FEEZE_VERSION="${1:?usage: $0 <version> <unpacked-release-dir>}"
export FEEZE_SRC="$(realpath "${2:?usage: $0 <version> <unpacked-release-dir>}")"

cd "$(dirname "$0")"
mkdir -p ../dist

# nfpm expands ${...} in scalar fields but not in contents[].src,
# so render the config first.
envsubst < nfpm.yaml.tmpl > /tmp/nfpm.rendered.yaml

for pkg in deb rpm; do
  nfpm pkg --config /tmp/nfpm.rendered.yaml --packager "$pkg" --target ../dist/
done

ls -la ../dist/
