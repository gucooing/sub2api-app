#!/usr/bin/env bash
# 把 flutter build linux 的产物打成 tar.gz / deb / AppImage 三种。
# 用法:bash .github/package-linux.sh <version>
set -euo pipefail

V="${1:?需要版本号参数}"
APP=sub2api
BUNDLE=build/linux/x64/release/bundle
ICON=assets/icon/app_icon.png

mkdir -p dist

# ── tar.gz ──
tar -czf "dist/sub2api_linux_${V}_amd64.tar.gz" -C "$BUNDLE" .

# ── 公共 .desktop 内容 ──
desktop_entry() {
  cat <<EOF
[Desktop Entry]
Type=Application
Name=Sub2api
Comment=Sub2API 网关客户端
Exec=$APP
Icon=$APP
Categories=Utility;Network;
Terminal=false
EOF
}

# ── deb ──
PKG=debpkg
rm -rf "$PKG"
mkdir -p "$PKG/DEBIAN" \
         "$PKG/usr/lib/$APP" \
         "$PKG/usr/bin" \
         "$PKG/usr/share/applications" \
         "$PKG/usr/share/icons/hicolor/256x256/apps"
cp -r "$BUNDLE"/* "$PKG/usr/lib/$APP/"
ln -s "/usr/lib/$APP/$APP" "$PKG/usr/bin/$APP"
cp "$ICON" "$PKG/usr/share/icons/hicolor/256x256/apps/$APP.png"
desktop_entry > "$PKG/usr/share/applications/$APP.desktop"
cat > "$PKG/DEBIAN/control" <<EOF
Package: $APP
Version: $V
Section: utils
Priority: optional
Architecture: amd64
Maintainer: gucooing <noreply@github.com>
Depends: libgtk-3-0, libstdc++6, libglib2.0-0
Description: Sub2api - Sub2API 网关跨平台客户端
EOF
dpkg-deb --build --root-owner-group "$PKG" "dist/sub2api_linux_${V}_amd64.deb"

# ── AppImage(CI 无 FUSE,提取后运行 appimagetool) ──
APPDIR=AppDir
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"
cp -r "$BUNDLE"/* "$APPDIR/usr/bin/"
cp "$ICON" "$APPDIR/$APP.png"
desktop_entry > "$APPDIR/$APP.desktop"
cat > "$APPDIR/AppRun" <<EOF
#!/bin/bash
HERE="\$(dirname "\$(readlink -f "\$0")")"
exec "\$HERE/usr/bin/$APP" "\$@"
EOF
chmod +x "$APPDIR/AppRun"

wget -qO appimagetool "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
chmod +x appimagetool
./appimagetool --appimage-extract >/dev/null
ARCH=x86_64 ./squashfs-root/AppRun "$APPDIR" "dist/sub2api_linux_${V}_amd64.AppImage"

echo "Linux 产物:"
ls -lh dist
