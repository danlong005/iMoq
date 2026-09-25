#!/bin/bash
# ------------------------------------------------------------------
# pub400-build.sh - build and test the working tree on pub400
#
#   tools/pub400-build.sh
#
# 1. Copies the working tree (uncommitted changes included) to the
#    IFS directory DIR on pub400.
# 2. Empties library LIB (tools/pub400-remote.sh does 2-4 on
#    pub400). LIB is scratch space, cleared before every build:
#    EVERYTHING IN IT IS DELETED. Journal receivers go first with *IGNINQMSG, so
#    "receiver never fully saved" (CPA7025) can't stop the job.
# 3. Builds iMoq into LIB with BUILD '*YES'.
# 4. Runs IMOQTEST, IMOQDEMO and EXAMPLES and prints their results.
#
# Needs an SSH key installed for USR (ssh-copy-id -p 2222 ...).
# Override the defaults with environment variables USR, LIB and DIR.
# ------------------------------------------------------------------
set -euo pipefail

USR=${USR:-LONGDM}
LIB=${LIB:-LONGDMB}
DIR=${DIR:-/home/$USR/imoq}
HOST=pub400.com
PORT=2222

cd "$(dirname "$0")/.."

# pub400 prints a login banner on every connection
unbanner() {
  grep -v -e '^\*' -e '^ *$' -e 'Enter your password' \
          -e 'http://pub400.com' || true
}

echo "== copying the working tree to $DIR"
rsync -az --delete --exclude .git --exclude build.log \
  -e "ssh -o BatchMode=yes -p $PORT" \
  --rsync-path=/QOpenSys/pkgs/bin/rsync \
  ./ "$USR@$HOST:$DIR/" 2>&1 | unbanner

# The pub400 side runs from a file: fed through stdin, the commands
# it runs would read the rest of the script as their input
ssh -o BatchMode=yes -p $PORT "$USR@$HOST" \
    "LIB=$LIB DIR=$DIR bash $DIR/tools/pub400-remote.sh </dev/null" \
    2>&1 | unbanner
