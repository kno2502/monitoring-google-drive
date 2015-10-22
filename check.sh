#!/bin/sh
LINES=$(grep '/anyone:' | awk -F"\t" '$2 !~ /\/(_世界に向けて公開するファイル|_個別提供OKなファイル)(\/.*)?$/ {print $1,$2}')

if [ -z "${LINES}" ]; then
  /bin/echo -e "watcher\tgoogle-drive[pasv]\t0\tsharing status OK"
else
  /bin/echo -e "watcher\tgoogle-drive[pasv]\t2\tsharing status NG"
fi
