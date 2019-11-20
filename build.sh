#!/bin/bash
set -eo pipefail
export HOME=`pwd`
MAKE_THREADS=${MAKE_THREADS:-$(expr `nproc` + 1)}
OPENWRT_VERSION=${OPENWRT_VERSION:-19.07.0-rc2}
OPENWRT_CONFIG_FILE_VER=$OPENWRT_VERSION

pack_and_upload() {
  echo 'Uploading artifacts...'
  cd $HOME/firmware
  local build_time=`date +"%Y%m%d%H%M%S"`
  tar cJf "$HOME/Openwrt.tar.xz" *
  curl -T "$HOME/Openwrt.tar.xz" "https://transfer.sh/Openwrt-$build_time.tar.xz"
  echo
  if [ -n "$TERACLOUD_AUTH" -a -n "$TERACLOUD_HOST" ]; then
    curl -u "$TERACLOUD_AUTH" -T "$HOME/Openwrt.tar.xz" "https://$TERACLOUD_HOST/dav/artifacts/Openwrt-$build_time.tar.xz" >/dev/null
    echo
  fi
}

mkdir -p $HOME/firmware || true

if [ "$OPENWRT_VERSION" = "git" ]; then
  git clone https://git.openwrt.org/openwrt/openwrt.git
  cd openwrt
  [ -n "$OPENWRT_GITVER" ] && git checkout $OPENWRT_GITVER
  OPENWRT_VERSION=$(git describe --tags || git rev-parse --short HEAD) || true
else
  curl -L https://github.com/openwrt/openwrt/archive/v$OPENWRT_VERSION.tar.gz | tar xz
  mv openwrt-$OPENWRT_VERSION openwrt
  cd openwrt
fi

echo 'Updating feeds...'
./scripts/feeds update -a > /dev/null 2>&1
echo 'Install packages...'
./scripts/feeds install -a > /dev/null 2>&1

for d in $BUILD_DEVICES; do
  make clean >/dev/null 2>&1 || true
  echo '--------start building--------'
  echo "Build openwrt $OPENWRT_VERSION for $d."
  cp $HOME/build_configs/$d-$OPENWRT_CONFIG_FILE_VER.config ./.config
  echo '--------config target--------'
  make defconfig
  echo '--------make download--------'
  make -j5 download
  echo '--------make firmware--------'
  make -j$MAKE_THREADS V=s
  echo '--------move artifacts--------'
  mv bin/targets/*/*/*.bin $HOME/firmware
done

cd $HOME/firmware
if [ "$(ls -A .)" ]; then
  echo "build succeed:"
  ls -hl
  [ -n "$SHARE_ARTIFACTS" ] && pack_and_upload
  [ -n "$BUILD_NOHOP_MODE" ] && touch $HOME/build_success || true
  exit 0
fi
exit 1
