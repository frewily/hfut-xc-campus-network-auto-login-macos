#!/bin/bash
# 合肥工业大学宣城校区校园网自动认证
# 凭据只从 macOS 钥匙串读取；本文件不包含账号或密码。

set -u

PORTAL_URL='http://172.18.3.3/0.htm'
SERVICE_PREFIX='HFUT-XC-Campus-Network'
LOG_FILE="$HOME/Library/Logs/hfut-campus-login.log"

log() {
  mkdir -p "$(dirname "$LOG_FILE")"
  printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG_FILE"
}

keychain_value() {
  /usr/bin/security find-generic-password -s "$1" -w 2>/dev/null
}

# If this known captive-portal probe contains "Success", the Internet is
# already reachable and no authentication request is made.
probe=$(/usr/bin/curl --noproxy '*' --connect-timeout 4 --max-time 8 -fsS \
  'http://captive.apple.com/hotspot-detect.html' 2>/dev/null || true)
if [[ "$probe" == *Success* ]]; then
  exit 0
fi

username=$(keychain_value "$SERVICE_PREFIX-Username" || true)
password=$(keychain_value "$SERVICE_PREFIX-Password" || true)
if [[ -z "$username" || -z "$password" ]]; then
  log '未配置钥匙串凭据，跳过认证。'
  exit 0
fi

# The page supplies changing pid/calg challenge values. Fetch a fresh page
# rather than hard-coding either value.
page=$(/usr/bin/curl --noproxy '*' --connect-timeout 4 --max-time 10 -fsS \
  "$PORTAL_URL" 2>/dev/null || true)
if [[ -z "$page" ]]; then
  log '无法访问校园网认证门户，跳过认证。'
  exit 0
fi

# `ps`, `pid`, and `calg` are defined by the page's a41.js on this portal.
# Combine both sources so the script also works if the variables move into the
# HTML in a later portal revision.
portal_js=$(/usr/bin/curl --noproxy '*' --connect-timeout 4 --max-time 10 -fsS \
  'http://172.18.3.3/a41.js' 2>/dev/null || true)
source_text="${page}"$'\n'"${portal_js}"

extract_js_value() {
  NAME="$1" /usr/bin/perl -0777 -ne '
    my $n = $ENV{NAME};
    if (/\b\Q$n\E\s*=\s*(?:"([^"]*)"|'"'"'([^'"'"']*)'"'"'|([0-9]+))/s) {
      print defined($1) ? $1 : defined($2) ? $2 : $3;
    }
  '
}

ps=$(printf '%s' "$source_text" | extract_js_value ps)
pid=$(printf '%s' "$source_text" | extract_js_value pid)
calg=$(printf '%s' "$source_text" | extract_js_value calg)
mkkey=$(printf '%s' "$source_text" | /usr/bin/perl -0777 -ne '
  print $1 if /name=["'"'"']0MKKey["'"'"']\s+value=["'"'"']([^"'"'"']*)/s
')

if [[ "$ps" != '1' || -z "$pid" || -z "$calg" || -z "$mkkey" ]]; then
  log '门户参数格式发生变化，未提交认证。'
  exit 1
fi

# This exactly matches a41.js: MD5(pid + password + calg) + calg + pid.
encoded_password="$(printf '%s' "${pid}${password}${calg}" | /sbin/md5 -q)${calg}${pid}"
response=$(/usr/bin/curl --noproxy '*' --connect-timeout 4 --max-time 12 -fsS \
  -X POST "$PORTAL_URL" \
  --data-urlencode "DDDDD=$username" \
  --data-urlencode "upass=$encoded_password" \
  --data 'R1=0' --data 'R2=1' --data 'para=00' \
  --data-urlencode "0MKKey=$mkkey" --data 'v6ip=' 2>/dev/null || true)

if [[ -n "$response" ]]; then
  log '已向校园网门户提交认证请求。'
else
  log '认证请求未获得响应。'
  exit 1
fi
