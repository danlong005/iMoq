**free
// ------------------------------------------------------------------
// IMOQAPI - iMoq RPG API: stubs and verifications built from handles
// Module of service program IMOQENG. Test programs use it through
// the prototypes in IMOQ_H.
//
//   Stub handles (> 0) are stub numbers. Every call saves the stub
//   again, so the stub answers calls from the moment imoq_when
//   returns, just like a bare IMOQWHEN.
//   Verification handles (< 0) point at a ring of VSLOTS slots in
//   this module; a slot is reused by the VSLOTS-th newer imoq_verify.
//
//   Setup calls send escape IMQ0300 to the test when they fail.
//   Checks (imoq_called..., imoq_noMoreCalls, imoq_noUnusedStubs)
//   return *off and leave the reason in imoq_lastError().
// ------------------------------------------------------------------
ctl-opt nomain option(*srcstmt:*nodebugio);

/copy QTEMP/IMOQINC,IMOQENG_H

dcl-c LOWER 'abcdefghijklmnopqrstuvwxyz';
dcl-c UPPER 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
dcl-c VSLOTS 16;

dcl-ds psds psds qualified;
  lib char(10) pos(81);
end-ds;

dcl-ds apiErr_t qualified template;
  bytesProv int(10);
  bytesAvail int(10);
  msgId char(7);
  rsv char(1);
end-ds;

dcl-pr qmhsndpm extpgm('QMHSNDPM');
  msgId char(7) const;
  msgf char(20) const;
  msgDta char(512) const;
  msgDtaLen int(10) const;
  msgType char(10) const;
  callStk char(10) const;
  callStkCtr int(10) const;
  msgKey char(4);
  errCode likeds(apiErr_t);
end-pr;

// Verification handles: the target and the matchers to count with
dcl-ds gV qualified dim(VSLOTS);
  gen int(10);
  obj char(10);
  proc varchar(4096);
  nM int(10);
  m likeds(imoq_matcher_t) dim(64);
end-ds;
dcl-s gVGen int(10);

// Why the last helper returned *off
dcl-s gMsg varchar(512);

// ==================================================================
// Helpers
// ==================================================================

// Send escape IMQ0300 to the test. Call it only directly from an
// exported procedure: the message goes 2 entries up the call stack
// (fail -> API procedure -> test).
dcl-proc fail;
  dcl-pi *n;
    text varchar(512) const;
  end-pi;
  dcl-s key char(4);
  dcl-ds ec likeds(apiErr_t);
  dcl-s dta char(512);
  imoq_setLastError(text);
  ec.bytesProv = 0;
  dta = text;
  qmhsndpm('IMQ0300' : 'IMOQMSGF  ' + psds.lib : dta : %len(text)
          : '*ESCAPE' : '*' : 2 : key : ec);
end-proc;

dcl-proc upperName;
  dcl-pi *n char(10);
    name char(10) const;
  end-pi;
  return %xlate(LOWER : UPPER : name);
end-proc;

// Number as the text the engine reads: no trailing zeros after the
// decimal point, a leading zero before it (6.500000000 -> 6.5)
dcl-proc imoq_numText export;
  dcl-pi *n varchar(64);
    value packed(31:9) const;
  end-pi;
  dcl-s t varchar(64);
  t = %char(value);
  if %scan('.' : t) > 0;
    dow %len(t) > 0 and %subst(t : %len(t) : 1) = '0';
      %len(t) = %len(t) - 1;
    enddo;
    if %len(t) > 0 and %subst(t : %len(t) : 1) = '.';
      %len(t) = %len(t) - 1;
    endif;
  endif;
  select;
  when t = '' or t = '-';
    return '0';
  when %subst(t : 1 : 1) = '.';
    return '0' + t;
  when %len(t) > 1 and %subst(t : 1 : 2) = '-.';
    return '-0' + %subst(t : 2);
  endsl;
  return t;
end-proc;

dcl-proc loadStub;
  dcl-pi *n ind;
    h int(10) const;
    stub likeds(imoq_stub_t);
  end-pi;
  dcl-ds err likeds(imoq_err_t);
  if h <= 0;
    gMsg = 'Handle ' + %char(h) + ' is not a stub handle. '
         + 'Use the handle imoq_when returned';
    return *off;
  endif;
  if not imoq_stubLoad(h : stub : err);
    gMsg = %trimr(err.text);
    return *off;
  endif;
  return *on;
end-proc;

dcl-proc saveStub;
  dcl-pi *n ind;
    stub likeds(imoq_stub_t);
  end-pi;
  dcl-ds err likeds(imoq_err_t);
  if not imoq_stubSave(stub : err);
    gMsg = %trimr(err.text);
    return *off;
  endif;
  return *on;
end-proc;

// Slot of a verification handle, 0 if it is not (or no longer) one
dcl-proc vSlot;
  dcl-pi *n int(10);
    h int(10) const;
  end-pi;
  dcl-s s int(10);
  if h >= 0;
    if h > 0;
      gMsg = 'Handle ' + %char(h) + ' is a stub handle. Checks need '
           + 'the handle imoq_verify returned';
    else;
      gMsg = 'Handle 0 is not valid. The imoq_when or imoq_verify '
           + 'that should have created it failed';
    endif;
    return 0;
  endif;
  s = %rem(-h - 1 : VSLOTS) + 1;
  if gV(s).gen <> -h;
    gMsg = 'Verification handle ' + %char(h) + ' expired: ' + %char(VSLOTS)
         + ' newer imoq_verify calls reused its slot';
    return 0;
  endif;
  return s;
end-proc;

dcl-proc addMatcher;
  dcl-pi *n ind;
    h int(10) const;
    parmNo int(10) const;
    matcher char(10) const;
    value varchar(1024) const;
    field varchar(40) const;
  end-pi;
  dcl-ds stub likeds(imoq_stub_t);
  dcl-ds m likeds(imoq_matcher_t);
  dcl-ds err likeds(imoq_err_t);
  dcl-s s int(10);
  dcl-s msg varchar(256);

  m.parmNo = parmNo;
  m.matcher = matcher;
  m.val = value;
  if not imoq_parseField(field : m.field : msg);
    gMsg = msg;
    return *off;
  endif;

  if h < 0;
    s = vSlot(h);
    if s = 0;
      return *off;
    endif;
    if gV(s).nM >= IMOQ_MAXP;
      gMsg = 'At most 64 argument matchers are allowed';
      return *off;
    endif;
    if not imoq_checkMatcher(gV(s).obj : gV(s).proc : m
                             : 'Matcher ' + %char(gV(s).nM + 1) : err);
      gMsg = %trimr(err.text);
      return *off;
    endif;
    gV(s).nM += 1;
    gV(s).m(gV(s).nM) = m;
    return *on;
  endif;

  if not loadStub(h : stub);
    return *off;
  endif;
  if stub.nM >= IMOQ_MAXP;
    gMsg = 'At most 64 argument matchers are allowed';
    return *off;
  endif;
  stub.nM += 1;
  stub.m(stub.nM) = m;
  return saveStub(stub);
end-proc;

dcl-proc addReturn;
  dcl-pi *n ind;
    h int(10) const;
    value varchar(1024) const;
  end-pi;
  dcl-ds stub likeds(imoq_stub_t);
  if not loadStub(h : stub);
    return *off;
  endif;
  if stub.nRtn >= %elem(stub.rtn);
    gMsg = 'At most 32 return values are allowed';
    return *off;
  endif;
  stub.nRtn += 1;
  stub.rtn(stub.nRtn) = value;
  return saveStub(stub);
end-proc;

dcl-proc addSet;
  dcl-pi *n ind;
    h int(10) const;
    parmNo int(10) const;
    value varchar(1024) const;
    field varchar(40) const;
  end-pi;
  dcl-ds stub likeds(imoq_stub_t);
  dcl-s fld varchar(40);
  dcl-s msg varchar(256);
  if not imoq_parseField(field : fld : msg);
    gMsg = msg;
    return *off;
  endif;
  if not loadStub(h : stub);
    return *off;
  endif;
  if stub.nSet >= IMOQ_MAXP;
    gMsg = 'At most 64 SETPARM entries are allowed';
    return *off;
  endif;
  stub.nSet += 1;
  stub.setNo(stub.nSet) = parmNo;
  stub.setVal(stub.nSet) = value;
  stub.setFld(stub.nSet) = fld;
  return saveStub(stub);
end-proc;

// Run a verification; *off with imoq_lastError() set if it failed
dcl-proc runCheck;
  dcl-pi *n ind;
    s int(10) const;
    mode char(9) const;
    want int(10) const;
    count int(10);
  end-pi;
  dcl-ds err likeds(imoq_err_t);
  if not imoq_verifyCalls(gV(s).obj : gV(s).proc : gV(s).m : gV(s).nM
                          : mode : want : count : err);
    gMsg = %trimr(err.text);
    return *off;
  endif;
  return *on;
end-proc;

// Captured argument as text; *off if the call or mock doesn't exist
dcl-proc argText;
  dcl-pi *n ind;
    obj char(10) const;
    proc varchar(4096) const;
    callNo int(10) const;
    parmNo int(10) const;
    fieldIn varchar(40) const;
    value varchar(1024);
    passed ind options(*nopass);
  end-pi;
  dcl-ds err likeds(imoq_err_t);
  dcl-s field varchar(40);
  dcl-s msg varchar(256);
  if not imoq_parseField(fieldIn : field : msg);
    gMsg = msg;
    return *off;
  endif;
  if not imoq_getArg(upperName(obj) : proc : callNo : parmNo : field
                     : value : err);
    gMsg = %trimr(err.text);
    return *off;
  endif;
  if value = '*OMIT' or value = '*NOTPASSED';
    if %parms() >= %parmnum(passed);
      passed = *off;
      return *on;
    endif;
    gMsg = 'Parameter ' + %char(parmNo) + ' of call ' + %char(callNo)
         + ' has no value (' + value + ')';
    return *off;
  endif;
  if %parms() >= %parmnum(passed);
    passed = *on;
  endif;
  return *on;
end-proc;

// ==================================================================
// Stubbing
// ==================================================================

// imoq_when(obj : proc) - start a stub; returns its handle
dcl-proc imoq_when export;
  dcl-pi *n int(10);
    obj char(10) const;
    proc varchar(4096) const options(*nopass);
  end-pi;
  dcl-ds stub likeds(imoq_stub_t);
  clear stub;
  stub.obj = upperName(obj);
  stub.proc = '*PGM';
  if %parms() >= %parmnum(proc);
    stub.proc = proc;
  endif;
  stub.times = -1;
  if not saveStub(stub);
    fail(gMsg);
    return 0;
  endif;
  return stub.id;
end-proc;

// imoq_with(h : parmNo : matcher : value) - add an argument matcher
// to a stub or a verification
dcl-proc imoq_withChar export;
  dcl-pi *n;
    h int(10) const;
    parmNo int(10) const;
    matcher char(10) const;
    value varchar(1024) const options(*nopass);
    field varchar(40) const options(*nopass);
  end-pi;
  dcl-s v varchar(1024);
  dcl-s f varchar(40);
  if %parms() >= %parmnum(value);
    v = value;
  endif;
  if %parms() >= %parmnum(field);
    f = field;
  endif;
  if not addMatcher(h : parmNo : matcher : v : f);
    fail(gMsg);
  endif;
end-proc;

dcl-proc imoq_withNum export;
  dcl-pi *n;
    h int(10) const;
    parmNo int(10) const;
    matcher char(10) const;
    value packed(31:9) const;
    field varchar(40) const options(*nopass);
  end-pi;
  dcl-s f varchar(40);
  if %parms() >= %parmnum(field);
    f = field;
  endif;
  if not addMatcher(h : parmNo : matcher : imoq_numText(value) : f);
    fail(gMsg);
  endif;
end-proc;

dcl-proc imoq_withDate export;
  dcl-pi *n;
    h int(10) const;
    parmNo int(10) const;
    matcher char(10) const;
    value date(*iso) const;
    field varchar(40) const options(*nopass);
  end-pi;
  dcl-s f varchar(40);
  if %parms() >= %parmnum(field);
    f = field;
  endif;
  if not addMatcher(h : parmNo : matcher : %char(value : *iso) : f);
    fail(gMsg);
  endif;
end-proc;

dcl-proc imoq_withTime export;
  dcl-pi *n;
    h int(10) const;
    parmNo int(10) const;
    matcher char(10) const;
    value time(*iso) const;
    field varchar(40) const options(*nopass);
  end-pi;
  dcl-s f varchar(40);
  if %parms() >= %parmnum(field);
    f = field;
  endif;
  if not addMatcher(h : parmNo : matcher : %char(value : *iso) : f);
    fail(gMsg);
  endif;
end-proc;

dcl-proc imoq_withTimestamp export;
  dcl-pi *n;
    h int(10) const;
    parmNo int(10) const;
    matcher char(10) const;
    value timestamp const;
    field varchar(40) const options(*nopass);
  end-pi;
  dcl-s f varchar(40);
  if %parms() >= %parmnum(field);
    f = field;
  endif;
  if not addMatcher(h : parmNo : matcher : %char(value : *iso) : f);
    fail(gMsg);
  endif;
end-proc;

// imoq_returns(h : value) - add a return value; several calls make a
// series (one value per call, the last one repeats)
dcl-proc imoq_returnsChar export;
  dcl-pi *n;
    h int(10) const;
    value varchar(1024) const;
  end-pi;
  if not addReturn(h : value);
    fail(gMsg);
  endif;
end-proc;

dcl-proc imoq_returnsNum export;
  dcl-pi *n;
    h int(10) const;
    value packed(31:9) const;
  end-pi;
  if not addReturn(h : imoq_numText(value));
    fail(gMsg);
  endif;
end-proc;

dcl-proc imoq_returnsDate export;
  dcl-pi *n;
    h int(10) const;
    value date(*iso) const;
  end-pi;
  if not addReturn(h : %char(value : *iso));
    fail(gMsg);
  endif;
end-proc;

dcl-proc imoq_returnsTime export;
  dcl-pi *n;
    h int(10) const;
    value time(*iso) const;
  end-pi;
  if not addReturn(h : %char(value : *iso));
    fail(gMsg);
  endif;
end-proc;

dcl-proc imoq_returnsTimestamp export;
  dcl-pi *n;
    h int(10) const;
    value timestamp const;
  end-pi;
  if not addReturn(h : %char(value : *iso));
    fail(gMsg);
  endif;
end-proc;

// imoq_setParm(h : parmNo : value) - fill an output parameter
dcl-proc imoq_setParmChar export;
  dcl-pi *n;
    h int(10) const;
    parmNo int(10) const;
    value varchar(1024) const;
    field varchar(40) const options(*nopass);
  end-pi;
  dcl-s f varchar(40);
  if %parms() >= %parmnum(field);
    f = field;
  endif;
  if not addSet(h : parmNo : value : f);
    fail(gMsg);
  endif;
end-proc;

dcl-proc imoq_setParmNum export;
  dcl-pi *n;
    h int(10) const;
    parmNo int(10) const;
    value packed(31:9) const;
    field varchar(40) const options(*nopass);
  end-pi;
  dcl-s f varchar(40);
  if %parms() >= %parmnum(field);
    f = field;
  endif;
  if not addSet(h : parmNo : imoq_numText(value) : f);
    fail(gMsg);
  endif;
end-proc;

dcl-proc imoq_setParmDate export;
  dcl-pi *n;
    h int(10) const;
    parmNo int(10) const;
    value date(*iso) const;
    field varchar(40) const options(*nopass);
  end-pi;
  dcl-s f varchar(40);
  if %parms() >= %parmnum(field);
    f = field;
  endif;
  if not addSet(h : parmNo : %char(value : *iso) : f);
    fail(gMsg);
  endif;
end-proc;

dcl-proc imoq_setParmTime export;
  dcl-pi *n;
    h int(10) const;
    parmNo int(10) const;
    value time(*iso) const;
    field varchar(40) const options(*nopass);
  end-pi;
  dcl-s f varchar(40);
  if %parms() >= %parmnum(field);
    f = field;
  endif;
  if not addSet(h : parmNo : %char(value : *iso) : f);
    fail(gMsg);
  endif;
end-proc;

dcl-proc imoq_setParmTimestamp export;
  dcl-pi *n;
    h int(10) const;
    parmNo int(10) const;
    value timestamp const;
    field varchar(40) const options(*nopass);
  end-pi;
  dcl-s f varchar(40);
  if %parms() >= %parmnum(field);
    f = field;
  endif;
  if not addSet(h : parmNo : %char(value : *iso) : f);
    fail(gMsg);
  endif;
end-proc;

// imoq_throws(h : msgId : msgDta : msgf : msgfLib) - send an escape
// message instead of answering. msgId IMOQ_MOCK sends IMQ0101.
dcl-proc imoq_throws export;
  dcl-pi *n;
    h int(10) const;
    msgId char(7) const;
    msgDta varchar(512) const options(*nopass);
    msgf char(10) const options(*nopass);
    msgfLib char(10) const options(*nopass);
  end-pi;
  dcl-ds stub likeds(imoq_stub_t);
  if not loadStub(h : stub);
    fail(gMsg);
    return;
  endif;
  stub.thrId = msgId;
  stub.thrDta = '';
  stub.thrMsgf = '*MOCK';
  stub.thrLib = '*LIBL';
  if %parms() >= %parmnum(msgDta);
    stub.thrDta = msgDta;
  endif;
  if %parms() >= %parmnum(msgf);
    stub.thrMsgf = msgf;
  endif;
  if %parms() >= %parmnum(msgfLib);
    stub.thrLib = msgfLib;
  endif;
  if not saveStub(stub);
    fail(gMsg);
  endif;
end-proc;

// imoq_times(h : n) - answer only n calls (IMOQ_ALWAYS: every call)
dcl-proc imoq_times export;
  dcl-pi *n;
    h int(10) const;
    n int(10) const;
  end-pi;
  dcl-ds stub likeds(imoq_stub_t);
  if not loadStub(h : stub);
    fail(gMsg);
    return;
  endif;
  stub.times = n;
  if not saveStub(stub);
    fail(gMsg);
  endif;
end-proc;

// ==================================================================
// Verification
// ==================================================================

// imoq_verify(obj : proc) - start a verification; returns its handle
dcl-proc imoq_verify export;
  dcl-pi *n int(10);
    obj char(10) const;
    proc varchar(4096) const options(*nopass);
  end-pi;
  dcl-ds err likeds(imoq_err_t);
  dcl-s p varchar(4096);
  dcl-s resolved varchar(4096);
  dcl-s s int(10);

  p = '*PGM';
  if %parms() >= %parmnum(proc);
    p = proc;
  endif;
  if not imoq_resolveTarget(upperName(obj) : p : resolved : err);
    fail(%trimr(err.text));
    return 0;
  endif;
  gVGen += 1;
  s = %rem(gVGen - 1 : VSLOTS) + 1;
  clear gV(s);
  gV(s).gen = gVGen;
  gV(s).obj = upperName(obj);
  gV(s).proc = resolved;
  return -gVGen;
end-proc;

dcl-proc imoq_calledTimes export;
  dcl-pi *n ind;
    h int(10) const;
    n int(10) const;
  end-pi;
  dcl-s s int(10);
  dcl-s cnt int(10);
  s = vSlot(h);
  if s = 0;
    fail(gMsg);
    return *off;
  endif;
  return runCheck(s : '*EXACTLY' : n : cnt);
end-proc;

dcl-proc imoq_calledOnce export;
  dcl-pi *n ind;
    h int(10) const;
  end-pi;
  dcl-s s int(10);
  dcl-s cnt int(10);
  s = vSlot(h);
  if s = 0;
    fail(gMsg);
    return *off;
  endif;
  return runCheck(s : '*EXACTLY' : 1 : cnt);
end-proc;

dcl-proc imoq_neverCalled export;
  dcl-pi *n ind;
    h int(10) const;
  end-pi;
  dcl-s s int(10);
  dcl-s cnt int(10);
  s = vSlot(h);
  if s = 0;
    fail(gMsg);
    return *off;
  endif;
  return runCheck(s : '*EXACTLY' : 0 : cnt);
end-proc;

dcl-proc imoq_calledAtLeast export;
  dcl-pi *n ind;
    h int(10) const;
    n int(10) const;
  end-pi;
  dcl-s s int(10);
  dcl-s cnt int(10);
  s = vSlot(h);
  if s = 0;
    fail(gMsg);
    return *off;
  endif;
  return runCheck(s : '*ATLEAST' : n : cnt);
end-proc;

dcl-proc imoq_calledAtMost export;
  dcl-pi *n ind;
    h int(10) const;
    n int(10) const;
  end-pi;
  dcl-s s int(10);
  dcl-s cnt int(10);
  s = vSlot(h);
  if s = 0;
    fail(gMsg);
    return *off;
  endif;
  return runCheck(s : '*ATMOST' : n : cnt);
end-proc;

// imoq_calledInOrder(v) - *on if a matching call came after the call
// the previous order check matched; that call becomes the new position
dcl-proc imoq_calledInOrder export;
  dcl-pi *n ind;
    h int(10) const;
  end-pi;
  dcl-ds err likeds(imoq_err_t);
  dcl-s s int(10);
  s = vSlot(h);
  if s = 0;
    fail(gMsg);
    return *off;
  endif;
  return imoq_verifyOrder(gV(s).obj : gV(s).proc : gV(s).m : gV(s).nM
                          : *off : err);
end-proc;

// Number of recorded calls that match (does not mark them verified)
dcl-proc imoq_matchCount export;
  dcl-pi *n int(10);
    h int(10) const;
  end-pi;
  dcl-s s int(10);
  dcl-s cnt int(10);
  s = vSlot(h);
  if s = 0;
    fail(gMsg);
    return 0;
  endif;
  if not runCheck(s : '*COUNT' : 0 : cnt);
    fail(gMsg);
    return 0;
  endif;
  return cnt;
end-proc;

// imoq_noMoreCalls(obj) - *on if every call (to obj) was verified
dcl-proc imoq_noMoreCalls export;
  dcl-pi *n ind;
    obj char(10) const options(*nopass);
  end-pi;
  dcl-ds err likeds(imoq_err_t);
  dcl-s o char(10);
  o = '*ALL';
  if %parms() >= %parmnum(obj);
    o = upperName(obj);
  endif;
  imoq_cl_noMore(o : err);
  return err.msgId = ' ';
end-proc;

// imoq_noUnusedStubs(obj) - *on if every stub (of obj) answered a call
dcl-proc imoq_noUnusedStubs export;
  dcl-pi *n ind;
    obj char(10) const options(*nopass);
  end-pi;
  dcl-ds err likeds(imoq_err_t);
  dcl-s o char(10);
  o = '*ALL';
  if %parms() >= %parmnum(obj);
    o = upperName(obj);
  endif;
  imoq_cl_unused(o : err);
  return err.msgId = ' ';
end-proc;

// imoq_reset(obj : scope) - forget stubs and/or calls
dcl-proc imoq_reset export;
  dcl-pi *n;
    obj char(10) const options(*nopass);
    scope char(7) const options(*nopass);
  end-pi;
  dcl-ds err likeds(imoq_err_t);
  dcl-s o char(10);
  dcl-s sc char(7);
  o = '*ALL';
  sc = '*ALL';
  if %parms() >= %parmnum(obj);
    o = upperName(obj);
  endif;
  if %parms() >= %parmnum(scope);
    sc = %xlate(LOWER : UPPER : scope);
  endif;
  if sc <> '*ALL' and sc <> '*CALLS' and sc <> '*STUBS';
    fail('Reset scope must be IMOQ_ALL, IMOQ_CALLS or IMOQ_STUBS, not '
       + %trim(scope));
    return;
  endif;
  imoq_cl_reset(o : sc : err);
  if err.msgId <> ' ';
    fail(%trimr(err.text));
  endif;
end-proc;

// ==================================================================
// Captured arguments, typed (imoq_arg returns them as text)
// ==================================================================
dcl-proc imoq_argNum export;
  dcl-pi *n packed(31:9);
    obj char(10) const;
    proc varchar(4096) const;
    callNo int(10) const;
    parmNo int(10) const;
    field varchar(40) const options(*nopass);
  end-pi;
  dcl-s f varchar(40);
  dcl-s v varchar(1024);
  if %parms() >= %parmnum(field);
    f = field;
  endif;
  if not argText(obj : proc : callNo : parmNo : f : v);
    fail(gMsg);
    return 0;
  endif;
  monitor;
    return %dec(v : 31 : 9);
  on-error;
    fail('Parameter ' + %char(parmNo) + ' is not a number: ''' + v + '''');
  endmon;
  return 0;
end-proc;

dcl-proc imoq_argDate export;
  dcl-pi *n date(*iso);
    obj char(10) const;
    proc varchar(4096) const;
    callNo int(10) const;
    parmNo int(10) const;
    field varchar(40) const options(*nopass);
  end-pi;
  dcl-s f varchar(40);
  dcl-s v varchar(1024);
  if %parms() >= %parmnum(field);
    f = field;
  endif;
  if not argText(obj : proc : callNo : parmNo : f : v);
    fail(gMsg);
    return *loval;
  endif;
  monitor;
    return %date(v : *iso);
  on-error;
    fail('Parameter ' + %char(parmNo) + ' is not an *ISO date: '''
       + v + '''');
  endmon;
  return *loval;
end-proc;

dcl-proc imoq_argTime export;
  dcl-pi *n time(*iso);
    obj char(10) const;
    proc varchar(4096) const;
    callNo int(10) const;
    parmNo int(10) const;
    field varchar(40) const options(*nopass);
  end-pi;
  dcl-s f varchar(40);
  dcl-s v varchar(1024);
  if %parms() >= %parmnum(field);
    f = field;
  endif;
  if not argText(obj : proc : callNo : parmNo : f : v);
    fail(gMsg);
    return *loval;
  endif;
  monitor;
    return %time(v : *iso);
  on-error;
    fail('Parameter ' + %char(parmNo) + ' is not an *ISO time: '''
       + v + '''');
  endmon;
  return *loval;
end-proc;

dcl-proc imoq_argTimestamp export;
  dcl-pi *n timestamp;
    obj char(10) const;
    proc varchar(4096) const;
    callNo int(10) const;
    parmNo int(10) const;
    field varchar(40) const options(*nopass);
  end-pi;
  dcl-s f varchar(40);
  dcl-s v varchar(1024);
  if %parms() >= %parmnum(field);
    f = field;
  endif;
  if not argText(obj : proc : callNo : parmNo : f : v);
    fail(gMsg);
    return *loval;
  endif;
  monitor;
    return %timestamp(v : *iso);
  on-error;
    fail('Parameter ' + %char(parmNo) + ' is not a timestamp: '''
       + v + '''');
  endmon;
  return *loval;
end-proc;

dcl-proc imoq_argInd export;
  dcl-pi *n ind;
    obj char(10) const;
    proc varchar(4096) const;
    callNo int(10) const;
    parmNo int(10) const;
    field varchar(40) const options(*nopass);
  end-pi;
  dcl-s f varchar(40);
  dcl-s v varchar(1024);
  if %parms() >= %parmnum(field);
    f = field;
  endif;
  if not argText(obj : proc : callNo : parmNo : f : v);
    fail(gMsg);
    return *off;
  endif;
  if v <> '0' and v <> '1';
    fail('Parameter ' + %char(parmNo) + ' is not an indicator: '''
       + v + '''');
    return *off;
  endif;
  return v = '1';
end-proc;

// *off when the parameter was omitted (*OMIT) or not passed
dcl-proc imoq_argPassed export;
  dcl-pi *n ind;
    obj char(10) const;
    proc varchar(4096) const;
    callNo int(10) const;
    parmNo int(10) const;
    field varchar(40) const options(*nopass);
  end-pi;
  dcl-s f varchar(40);
  dcl-s v varchar(1024);
  dcl-s passed ind;
  if %parms() >= %parmnum(field);
    f = field;
  endif;
  if not argText(obj : proc : callNo : parmNo : f : v : passed);
    fail(gMsg);
    return *off;
  endif;
  return passed;
end-proc;
