#!/bin/bash
# /usr/local/bin/nullmailer-watchdog [--fix]
# Detects nullmailer protocol modules wedged on a silently-dropped SMTP socket.
# Without --fix: report only. With --fix: kill the wedged children.
# Exit 0 = healthy, 1 = wedged (or daemon missing).
set -euo pipefail

MAX_CHILD_AGE="${MAX_CHILD_AGE:-120}"
do_fix="no"

for arg in "$@"; do
  case "${arg}" in
    --fix)
      do_fix="yes"
      ;;
    *)
      echo "unknown argument: ${arg}" >&2
      exit 2
      ;;
  esac
done

parent_pid="$(pgrep -f '/usr/sbin/nullmailer-send' || true)"

if [[ -z "${parent_pid}" ]]; then
  echo "nullmailer-send not running"
  exit 1
fi

wedged=""

while read -r pid etimes comm; do
  if [[ "${etimes}" -gt "${MAX_CHILD_AGE}" ]]; then
    wedged="${wedged} ${pid}(${comm},${etimes}s)"
    if [[ "${do_fix}" == "yes" ]]; then
      logger -t nullmailer-watchdog "killing wedged ${comm} pid=${pid} age=${etimes}s"
      kill -9 "${pid}" 2>/dev/null || true
    fi
  fi
done < <(ps --ppid "${parent_pid}" -o pid=,etimes=,comm= --no-headers || true)

if [[ -n "${wedged}" ]]; then
  echo "nullmailer: wedged child:${wedged}"
  exit 1
fi

echo "nullmailer ok"
exit 0
