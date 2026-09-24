#!/bin/bash
# ------------------------------------------------------------------
# pub400-remote.sh - the pub400 side of tools/pub400-build.sh
#
# Runs on pub400 with LIB and DIR set: clears LIB (EVERYTHING IN IT
# IS DELETED), builds iMoq into it from DIR and runs the self-tests.
# ------------------------------------------------------------------
set -u
DB2=/QOpenSys/pkgs/bin/db2util

# Wait for a submitted job (number/user/name) to leave the system
waitjob() {
  local s
  while :; do
    s=$(system "DSPJOB JOB($1) OPTION(*STSA)" 2>&1 || true)
    echo "$s" | grep -qE 'CPF1070|OUTQ' && return 0
    sleep 5
  done
}

# Only CPF/IMQ/MCH... result lines, not listings or completion noise
results() {
  grep -E '^[A-Z]{3}[0-9A-F]{4}:' | grep -vE '^(CPC|CPI|CPD0912)' || true
}

echo "== clearing $LIB"
for r in $($DB2 -o space "select objname from table(qsys2.object_statistics(
             '$LIB', '*JRNRCV')) x" 2>/dev/null | tr -d '"'); do
  system "DLTJRNRCV JRNRCV($LIB/$r) DLTOPT(*IGNINQMSG)" 2>&1 | results
done
job=$(system "SBMJOB CMD(CLRLIB LIB($LIB)) JOB(IMOQCLR) \
               INQMSGRPY(*DFT)" 2>&1 \
      | sed -n 's/.*Job \([0-9]*\/[A-Z0-9]*\/IMOQCLR\) submitted.*/\1/p')
if [ -z "$job" ]; then
  echo "could not submit CLRLIB"; exit 1
fi
waitjob "$job"
left=$(system "DSPOBJD OBJ($LIB/*ALL) OBJTYPE(*ALL)" 2>&1 \
       | grep -E '^ [A-Z0-9$#@]' | grep -vE 'Library \. \.|Object +Type' || true)
if [ -n "$left" ]; then
  echo "$LIB is not empty after CLRLIB; not building:"
  echo "$left"
  exit 1
fi

echo "== building into $LIB"
# *YES also copies examples/ (the demo and examples need it) and runs
# the self-tests once; BUILD fails if one of them fails. They run
# again below so their results show up here.
system "CRTBNDCL PGM($LIB/BUILD) SRCSTMF('$DIR/QCLLESRC/BUILD.clle')" \
  2>&1 | grep -E '^CPF' || true
system "CALL PGM($LIB/BUILD) PARM('$LIB' '$DIR' '*YES')" 2>&1 | results

echo "== IMOQTEST"
system "CALL PGM($LIB/IMOQTEST) PARM('$LIB' '$LIB')" 2>&1 | results
echo "== IMOQDEMO"
system "CALL PGM($LIB/IMOQDEMO) PARM('$LIB' '$LIB')" 2>&1 | results
echo "== EXAMPLES"
system "CRTBNDCL PGM($LIB/EXAMPLES) SRCFILE($LIB/QCLLESRC) \
          SRCMBR(EXAMPLES) REPLACE(*YES)" 2>&1 | grep -E '^CPF' || true
system "CALL PGM($LIB/EXAMPLES) PARM('$LIB')" 2>&1 | results
