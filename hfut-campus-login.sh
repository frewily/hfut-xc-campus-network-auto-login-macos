#!/bin/bash
# 合肥工业大学宣城校区校园网认证。
# 凭据只从 macOS 钥匙串读取；本文件不包含账号或密码。

set -u

PORTAL_URL='http://172.18.3.3/0.htm'
SERVICE_PREFIX='HFUT-XC-Campus-Network'
LOG_FILE="$HOME/Library/Logs/hfut-campus-login.log"
WAIT_SECONDS=0

if [[ "${1:-}" == '--wait-seconds' ]]; then
  WAIT_SECONDS="${2:-0}"
fi
if ! [[ "$WAIT_SECONDS" =~ ^[0-9]+$ ]]; then
  echo 'Usage: hfut-campus-login.sh [--wait-seconds seconds]' >&2
  exit 2
fi

log() {
  mkdir -p "$(dirname "$LOG_FILE")"
  printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG_FILE"
}

keychain_value() {
  /usr/bin/security find-generic-password -s "$1" -w 2>/dev/null
}

is_online() {
  local probe
  probe=$(/usr/bin/curl --noproxy '*' --connect-timeout 1 --max-time 2 -fsS \
    'http://captive.apple.com/hotspot-detect.html' 2>/dev/null || true)
  [[ "$probe" == *Success* ]]
}

extract_js_value() {
  NAME="$1" /usr/bin/perl -0777 -ne '
    my $n = $ENV{NAME};
    if (/\b\Q$n\E\s*=\s*(?:"([^"]*)"|'"'"'([^'"'"']*)'"'"'|([0-9]+))/s) {
      print defined($1) ? $1 : defined($2) ? $2 : $3;
    }
  '
}

username=$(keychain_value "$SERVICE_PREFIX-Username" || true)
password=$(keychain_value "$SERVICE_PREFIX-Password" || true)
if [[ -z "$username" || -z "$password" ]]; then
  log '未配置钥匙串凭据，跳过认证。'
  exit 1
fi

deadline=$(( $(date +%s) + WAIT_SECONDS ))
while :; do
  # Already online: do nothing and do not open a browser window.
  if is_online; then
    exit 0
  fi

  page=$(/usr/bin/curl --noproxy '*' --connect-timeout 1 --max-time 2 -fsS \
    "$PORTAL_URL" 2>/dev/null || true)
  if [[ -n "$page" ]]; then
    portal_js=$(/usr/bin/curl --noproxy '*' --connect-timeout 1 --max-time 2 -fsS \
      'http://172.18.3.3/a41.js' 2>/dev/null || true)
    source_text="${page}"$'\n'"${portal_js}"

    ps=$(printf '%s' "$source_text" | extract_js_value ps)
    pid=$(printf '%s' "$source_text" | extract_js_value pid)
    calg=$(printf '%s' "$source_text" | extract_js_value calg)
    mkkey=$(printf '%s' "$source_text" | /usr/bin/perl -0777 -ne '
      print $1 if /name=["'"'"']0MKKey["'"'"']\s+value=["'"'"']([^"'"'"']*)/s
    ')

    if [[ "$ps" == '1' && -n "$pid" && -n "$calg" && -n "$mkkey" ]]; then
      # This matches the portal's a41.js: MD5(pid + password + calg) + calg + pid.
      encoded_password="$(printf '%s' "${pid}${password}${calg}" | /sbin/md5 -q)${calg}${pid}"
      response=$(/usr/bin/curl --noproxy '*' --connect-timeout 2 --max-time 6 -fsS \
        -X POST "$PORTAL_URL" \
        --data-urlencode "DDDDD=$username" \
        --data-urlencode "upass=$encoded_password" \
        --data 'R1=0' --data 'R2=1' --data 'para=00' \
        --data-urlencode "0MKKey=$mkkey" --data 'v6ip=' 2>/dev/null || true)
      if [[ -n "$response" ]]; then
        log '已向校园网门户提交认证请求。'
        exit 0
      fi
    fi
  fi

  if (( $(date +%s) >= deadline )); then
    log '唤醒后等待校园网就绪超时，未提交认证。'
    exit 1
  fi
  /bin/sleep 1
done
