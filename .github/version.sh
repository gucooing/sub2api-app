#!/usr/bin/env bash
# 计算用于产物命名 / deb-AppImage 版本的版本号。
#  - tag 触发(refs/tags/vX.Y.Z)→ 去掉前缀 v 的版本号(X.Y.Z)
#  - 其它(分支推送 / 手动)→ 取 pubspec.yaml 的 version,去掉 +build 部分
set -euo pipefail

ref="${GITHUB_REF:-}"
if [[ "$ref" == refs/tags/v* ]]; then
  echo "${ref#refs/tags/v}"
else
  grep '^version:' pubspec.yaml | sed 's/version:[[:space:]]*//' | cut -d'+' -f1
fi
