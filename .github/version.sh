#!/usr/bin/env bash
# 计算用于产物命名 / deb-AppImage 版本的版本号。
#  - 手动触发填了版本号(环境变量 APP_VERSION)→ 用之(去掉可能的前缀 v)
#  - 否则 → 取 pubspec.yaml 的 version,去掉 +build 部分
set -euo pipefail

if [[ -n "${APP_VERSION:-}" ]]; then
  echo "${APP_VERSION#v}"
else
  grep '^version:' pubspec.yaml | sed 's/version:[[:space:]]*//' | cut -d'+' -f1
fi
