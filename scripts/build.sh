#!/usr/bin/env bash
set -e

[[ "$#" -ne 1 ]] && echo "Missing architecture" && exit 1
[[ "$1" != "amd64" && "$1" != "arm64" ]] && echo "Unsupported architecture" && exit 1

# Set variables
ARCH=$1
TARGET=$([[ "${ARCH}" == "x86_64" ]] && echo "x86_64-linux" || echo "aarch64-linux")
VERSION=$(cat build.zig.zon | grep '.version' | sed 's/.*= "\(.*\)",/\1/')
APP_NAME=$(cat build.zig.zon | grep '.name' | sed 's/.*= "\(.*\)",/\1/')
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
APP_DIR="${SCRIPT_DIR}/../dist/opt/${APP_NAME}"


# Clean up dist directory
rm -rf "${SCRIPT_DIR}/../dist"

# Create directories
mkdir -p "${SCRIPT_DIR}/../dist/DEBIAN" "${SCRIPT_DIR}/../dist/lib/systemd/system" "${APP_DIR}"

# Create files
cat > "${SCRIPT_DIR}/../dist/DEBIAN/control" <<EOF
Package: ${APP_NAME}
Version: ${VERSION}
Architecture: ${ARCH}
Maintainer: Shock VPN <info@shockvpn.com>
Section: network
Priority: optional
Homepage: https://shockvpn.com
Description:
    Expose homelab services to the web via SSH tunneling
EOF

cat > "${SCRIPT_DIR}/../dist/DEBIAN/postinst" <<EOF
#!/bin/bash
set -e

chown -R root:root /opt/${APP_NAME}
ln -sf /opt/${APP_NAME}/${APP_NAME} /usr/local/bin/${APP_NAME}
sed -i "s/%%USER%%/\$(logname)/g" /lib/systemd/system/${APP_NAME}.service

systemctl daemon-reload
EOF
chmod +x "${SCRIPT_DIR}/../dist/DEBIAN/postinst"

cat > "${SCRIPT_DIR}/../dist/DEBIAN/prerm" <<EOF
#!/bin/bash
set -e

systemctl stop ${APP_NAME} || true
systemctl disable ${APP_NAME} || true
rm -f /usr/local/bin/${APP_NAME}
EOF
chmod +x "${SCRIPT_DIR}/../dist/DEBIAN/prerm"

cat > "${SCRIPT_DIR}/../dist/lib/systemd/system/${APP_NAME}.service" <<EOF
[Unit]
Description=Home Forwarder
After=network.target

[Service]
Type=simple
User=%%USER%%
ExecStart=/opt/${APP_NAME}/${APP_NAME}
Restart=always

[Install]
WantedBy=multi-user.target
EOF

cat > "${APP_DIR}/config.json" <<EOF
{
    "timeout": 5,
    "services": [],
    "forward_host": "localhost"
}
EOF

# Build Zig Project
cd "${SCRIPT_DIR}/.." && zig build -Doptimize=ReleaseSafe -Dtarget=${TARGET} && mv "${SCRIPT_DIR}/../zig-out/bin/${APP_NAME}" "${APP_DIR}"

# Build deb
mkdir -p "${SCRIPT_DIR}/../debs"
dpkg-deb --build -Zgzip "${SCRIPT_DIR}/../dist" "${SCRIPT_DIR}/../debs/${APP_NAME}_${VERSION}_${ARCH}.deb"
