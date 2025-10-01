#!/bin/bash -e

rm -rf "${PWD}/dist"
mkdir -p "${PWD}/dist"

readonly BASEDIR="${PWD}"
readonly PREFIX="${PWD}/dist"

# ===== Platform and Architecture ==============================================

# Our version (should be defined outside, defaulting to the one in package.json)
readonly PACKAGE_VERSION="${PACKAGE_VERSION:-$(node -p 'require("./package.json").version')}"
# PostgreSQL version to build
readonly POSTGRESQL_VERSION="$(node -p 'require("./package.json").postgresql_version')"

# Variables derived from the current NodeJS installation
readonly NODE_VERSION="$(node -p 'process.versions.node')"
readonly NODE_MAJOR_VERSION="$(node -p 'process.versions.node.split(".")[0]')"
readonly NODE_MODULE_VERSION="$(node -p 'process.versions.modules')"
readonly NODE_PLATFORM="$(node -p 'process.platform')"
readonly NODE_ARCH="$(node -p 'process.arch')"
readonly NODE_OS="${NODE_PLATFORM}-${NODE_ARCH}"
readonly NODE_INCLUDE_DIR="$(node -p 'path.resolve(process.execPath, "..", "..", "include", "node")')"

# Figure out the OpenSSL version to build (the RE is to extract the "x.y.z" part
# when NodeJS reports something like "3.0.15+quic").
readonly OPENSSL_VERSION="$(node -p 'process.versions.openssl.match(/\d+\.\d+\.\d+/)[0]')"

echo "========================================================================="
echo "  Building @juit/libpq"
echo "========================================================================="
echo "  NodeJS Version:        ${NODE_VERSION}"
echo "  NodeJS Major Version:  ${NODE_MAJOR_VERSION}"
echo "  NodeJS Module Version: ${NODE_MODULE_VERSION}"
echo "  NodeJS Platform:       ${NODE_PLATFORM}"
echo "  NodeJS Architecture:   ${NODE_ARCH}"
echo "  NodeJS OS:             ${NODE_OS}"
echo "  NodeJS Include Dir:    ${NODE_INCLUDE_DIR}"
echo "  OpenSSL Version:       ${OPENSSL_VERSION}"
echo "  PostgreSQL Version:    ${POSTGRESQL_VERSION}"
echo "  Install Prefix:        ${PREFIX}"
echo "  Package Version:       ${PACKAGE_VERSION}"
echo "========================================================================="

# ===== Build Environment Setup ================================================

# On macOS, target only Big Sur (11.0) and later (M1 support)
readonly MACOSX_DEPLOYMENT_TARGET=11.0
export MACOSX_DEPLOYMENT_TARGET

# ===== OpenSSL Build ==========================================================

# Download OpenSSL and expand it
rm -rf "./openssl-${OPENSSL_VERSION}"
curl -LO "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz"
tar -zxf "./openssl-${OPENSSL_VERSION}.tar.gz"

# OpenSSL build target
case "${NODE_OS}" in
  "darwin-arm64")
    OPENSSL_TARGET="darwin64-arm64-cc"
    ;;
  "darwin-x64")
    OPENSSL_TARGET="darwin64-x86_64-cc"
    ;;
  "linux-x64")
    OPENSSL_TARGET="linux-x86_64"
    ;;
  "linux-arm64")
    OPENSSL_TARGET="linux-aarch64"
    ;;
  *)
    echo "Unsupported platform/architecture: ${NODE_OS}"
    exit 1
    ;;
esac

# Build OpenSSL and install the binaries/headers
(
  cd "./openssl-${OPENSSL_VERSION}"
  ./Configure --prefix="${PREFIX}" \
    --openssldir=/etc/ssl \
    ${OPENSSL_TARGET}

  make
  make install_sw
)

# ===== PostgreSQL Build =======================================================

# Download PostgreSQL and expand it
rm -rf "./postgresql-${POSTGRESQL_VERSION}"
curl -LO "https://ftp.postgresql.org/pub/source/v${POSTGRESQL_VERSION}/postgresql-${POSTGRESQL_VERSION}.tar.gz"
tar -zxf "./postgresql-${POSTGRESQL_VERSION}.tar.gz"

# Build PostgreSQL and install the binaries/headers for LibPQ only
(
  cd "./postgresql-${POSTGRESQL_VERSION}"
  LDFLAGS="-L${PREFIX}/lib" \
  ./configure --prefix="${PREFIX}" \
    --with-includes="${NODE_INCLUDE_DIR}" \
    --enable-thread-safety \
    --with-openssl \
    --without-libxml \
    --without-libxslt \
    --without-python \
    --without-readline \
    --without-icu \
    --without-lz4 \
    --without-zstd

  make -C "./src/include"
  make -C "./src/common"
  make -C "./src/port"
  make -C "./src/interfaces/libpq"
  make -C "./src/bin/pg_config"

  make -C "./src/include" install
  make -C "./src/common" install
  make -C "./src/port" install
  make -C "./src/interfaces/libpq" install
  make -C "./src/bin/pg_config" install
)

# ===== Final Node "libpq" build ===============================================

./node_modules/.bin/node-gyp rebuild

rm -rf "./package"
mkdir "./package"
cp "./build/Release/libpq.node" "./package/libpq.node"
cat > "./package/package.json" <<EOF
{
  "name": "@juit/libpq-${NODE_PLATFORM}-${NODE_ARCH}-node${NODE_MAJOR_VERSION}",
  "description": "Node.js bindings for libpq",
  "version": "${PACKAGE_VERSION}",
  "license": "MIT",
  "homepage": "https://github.com/juitnow/juit-libpq",
  "main": "libpq.node",
  "engines": { "node": "${NODE_MAJOR_VERSION}" },
  "os": [ "${NODE_PLATFORM}" ],
  "cpu": [ "${NODE_ARCH}" ],
  "files": [ "libpq.node" ]
}
EOF

npm pack "./package"
