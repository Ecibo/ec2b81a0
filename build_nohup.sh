#!/bin/bash
export HOME=`pwd`
export BUILD_NOHOP_MODE=1

./build.sh > build.log 2>&1 &

while true ;do
  sleep 20
  process_status="$(pgrep -f build.sh)"
  if [ -z "$process_status" ]; then
    echo "Build script exited"
    tail -60 build.log
    xz -z9 build.log
    curl -T build.log.xz https://transfer.sh/openwrt-build.`date +"%Y%m%d%H%M%S"`.log.xz
    echo
    [ -e $HOME/build_success ] && exit 0
    exit 1
  else
    if [ -z "$NO_TAIL_LOG" ]; then
      echo "===============build log==============="
      tail -2 build.log || true
    fi
    echo "--------------top process--------------"
    ps aux | grep -v ^'USER' | sort -rn -k3 | head -2 | awk '{print $3, $4, $10, $11}' 2> /dev/null
  fi
done
