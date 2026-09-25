**free
// ------------------------------------------------------------------
// IMOQCMD_T - iMoq command-level tests: stub selection, answers,
//             TIMES, strict mocks, verification counts, IMOQNOMORE,
//             call order, unused stubs, capture and reset scopes.
// The mocks are declared but never built: calls go straight to
// imoq_invoke, the entry point every generated stub calls.
// Run with IMOQTEST.
// ------------------------------------------------------------------
ctl-opt main(runTests) option(*srcstmt:*nodebugio);

/copy QTEMP/IMOQINC,IMOQENG_H

// Two service program mocks, each with
//   PRICE(item char(5) const) returns packed(7:2)
//   SETQTY(item char(5) const : qty int(10))
dcl-c LOOSE 'IMQTSRV';
dcl-c STRICT 'IMQTSTR';
dcl-c LAST -1;

// Escape message the last simulated call sent, blank if none
dcl-s gThrown char(7);

/copy QTEMP/IMOQINC,IMOQTST_H

dcl-proc runTests;
  dcl-pi *n;
    report char(8000);
    failures int(10);
  end-pi;
  tst_init(report);
  if setup();
    test_selection();
    test_listMatchers();
    test_series();
    test_times();
    test_strict();
    test_throw();
    test_setParm();
    test_verifyCounts();
    test_noMore();
    test_order();
    test_unused();
    test_capture();
    test_reset();
    test_rejected();
  endif;
  imoq_ok('IMOQRMV OBJ(' + LOOSE + ')');
  imoq_ok('IMOQRMV OBJ(' + STRICT + ')');
  tst_summary(failures);
end-proc;

// ==================================================================
// Helpers
// ==================================================================

// Run a command that should work
dcl-proc cmd;
  dcl-pi *n;
    text varchar(3000) const;
  end-pi;
  tst_check(imoq_ok(text) : text + ' failed: ' + imoq_lastError());
end-proc;

// Run a command that should fail, with text in imoq_lastError()
dcl-proc fails;
  dcl-pi *n;
    text varchar(3000) const;
    expected varchar(200) const;
  end-pi;
  if imoq_ok(text);
    tst_check(*off : text + ' should have failed');
  else;
    tst_check(%scan(expected : imoq_lastError()) > 0
              : text + ': expected "' + expected + '" in: '
              + imoq_lastError());
  endif;
end-proc;

// Call PRICE of a mock, as its stub would
dcl-proc price;
  dcl-pi *n packed(7:2);
    item char(5) const;
    obj char(10) const options(*nopass);
  end-pi;
  dcl-s o char(10) inz(LOOSE);
  dcl-s it char(5);
  dcl-s r packed(7:2);
  dcl-s ptrs pointer dim(64);
  dcl-ds thr likeds(imoq_throw_t);
  if %parms() >= %parmnum(obj);
    o = obj;
  endif;
  it = item;
  ptrs(1) = %addr(it);
  imoq_invoke(o : 'PRICE' : 1 : %addr(ptrs) : %addr(r) : thr);
  gThrown = thr.msgId;
  return r;
end-proc;

// Call SETQTY of the loose mock; returns qty as the stub left it
dcl-proc setQty;
  dcl-pi *n int(10);
    item char(5) const;
    qtyIn int(10) const;
  end-pi;
  dcl-s it char(5);
  dcl-s q int(10);
  dcl-s ptrs pointer dim(64);
  dcl-ds thr likeds(imoq_throw_t);
  it = item;
  q = qtyIn;
  ptrs(1) = %addr(it);
  ptrs(2) = %addr(q);
  imoq_invoke(LOOSE : 'SETQTY' : 2 : %addr(ptrs) : *null : thr);
  gThrown = thr.msgId;
  return q;
end-proc;

dcl-proc setup;
  dcl-pi *n ind;
  end-pi;
  dcl-s o char(10);
  dcl-s i int(10);
  tst_begin('mocks are declared without building them');
  for i = 1 to 2;
    if i = 1;
      o = LOOSE;
      cmd('IMOQSRVPGM OBJ(' + o + ')');
    else;
      o = STRICT;
      cmd('IMOQSRVPGM OBJ(' + o + ') BEHAVIOR(*STRICT)');
    endif;
    cmd('IMOQPROC OBJ(' + o + ') PROC(PRICE) RTNTYPE(*PACKED 7 2) +
         PARMS((*CHAR 5 *CONST))');
    cmd('IMOQPROC OBJ(' + o + ') PROC(SETQTY) +
         PARMS((*CHAR 5 *CONST) (*INT 10))');
  endfor;
  tst_end();
  return not tst_bad;
end-proc;

// ==================================================================
// Stubbing
// ==================================================================
dcl-proc test_selection;
  tst_begin('the newest matching stub answers');
  monitor;
    cmd('IMOQRESET');
    cmd('IMOQWHEN OBJ(IMQTSRV) PROC(PRICE) RETURN(1)');
    cmd('IMOQWHEN OBJ(IMQTSRV) PROC(PRICE) ARGS((1 *EQ A0001)) RETURN(2)');
    cmd('IMOQWHEN OBJ(IMQTSRV) PROC(PRICE) ARGS((1 *EQ B0002)) RETURN(3)');
    tst_eqNum(2 : price('A0001') : 'A0001');
    tst_eqNum(3 : price('B0002') : 'B0002');
    tst_eqNum(1 : price('C0003') : 'no matcher fits: the catch-all');

    cmd('IMOQWHEN OBJ(IMQTSRV) PROC(PRICE) RETURN(4)');
    tst_eqNum(4 : price('A0001') : 'a newer catch-all hides older stubs');

    cmd('IMOQRESET SCOPE(*STUBS)');
    tst_eqNum(0 : price('A0001') : 'loose mock without stubs');
    tst_check(gThrown = ' ' : 'a loose mock sent ' + gThrown);
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;

dcl-proc test_listMatchers;
  tst_begin('*IN and *BETWEEN match lists and ranges');
  monitor;
    cmd('IMOQRESET');
    cmd('IMOQWHEN OBJ(IMQTSRV) PROC(PRICE) +
         ARGS((1 *IN ''A0001, B0002'')) RETURN(1)');
    cmd('IMOQWHEN OBJ(IMQTSRV) PROC(SETQTY) +
         ARGS((2 *BETWEEN ''10,20'')) SETPARM((2 0))');
    tst_eqNum(1 : price('B0002') : '*IN: listed');
    tst_eqNum(0 : price('C0003') : '*IN: not listed');
    tst_eqNum(0 : setQty('A0001' : 10) : '*BETWEEN: low');
    tst_eqNum(0 : setQty('A0001' : 20) : '*BETWEEN: high');
    tst_eqNum(21 : setQty('A0001' : 21) : '*BETWEEN: above');

    cmd('IMOQVERIFY OBJ(IMQTSRV) PROC(PRICE) +
         ARGS((1 *IN ''C0003,Z9999'')) TIMES(*ONCE)');
    cmd('IMOQVERIFY OBJ(IMQTSRV) PROC(SETQTY) +
         ARGS((2 *BETWEEN ''1,20'')) TIMES(*EXACTLY 2)');

    fails('IMOQWHEN OBJ(IMQTSRV) PROC(SETQTY) ARGS((2 *BETWEEN 5))'
          : 'two values separated by a comma');
    fails('IMOQWHEN OBJ(IMQTSRV) PROC(SETQTY) ARGS((2 *BETWEEN ''20,10''))'
          : 'is greater than high value');
    fails('IMOQWHEN OBJ(IMQTSRV) PROC(SETQTY) ARGS((2 *IN ''1,x''))'
          : '*IN value 2');
    fails('IMOQVERIFY OBJ(IMQTSRV) PROC(PRICE) +
           ARGS((1 *BETWEEN ''A,B,C''))' : 'two values');
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;

dcl-proc test_series;
  tst_begin('RETURN values answer in order, then the last repeats');
  monitor;
    cmd('IMOQRESET');
    cmd('IMOQWHEN OBJ(IMQTSRV) PROC(PRICE) RETURN(1 2 3)');
    tst_eqNum(1 : price('A0001') : 'call 1');
    tst_eqNum(2 : price('A0001') : 'call 2');
    tst_eqNum(3 : price('B0002') : 'call 3');
    tst_eqNum(3 : price('A0001') : 'call 4');
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;

dcl-proc test_times;
  tst_begin('TIMES(n) answers n calls, then older stubs answer');
  monitor;
    cmd('IMOQRESET');
    cmd('IMOQWHEN OBJ(IMQTSRV) PROC(PRICE) RETURN(9)');
    cmd('IMOQWHEN OBJ(IMQTSRV) PROC(PRICE) RETURN(5 6) TIMES(2)');
    tst_eqNum(5 : price('A0001') : 'call 1');
    tst_eqNum(6 : price('A0001') : 'call 2');
    tst_eqNum(9 : price('A0001') : 'call 3: used up, older stub');

    cmd('IMOQRESET SCOPE(*STUBS)');
    cmd('IMOQWHEN OBJ(IMQTSRV) PROC(PRICE) RETURN(7) TIMES(1)');
    tst_eqNum(7 : price('A0001') : 'TIMES(1) call 1');
    tst_eqNum(0 : price('A0001') : 'TIMES(1) call 2: no stub left');
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;

dcl-proc test_strict;
  tst_begin('a strict mock sends IMQ0100 for an unmatched call');
  monitor;
    cmd('IMOQRESET');
    cmd('IMOQWHEN OBJ(IMQTSTR) PROC(PRICE) ARGS((1 *EQ A0001)) RETURN(7)');
    tst_eqNum(7 : price('A0001' : STRICT) : 'matched call');
    tst_check(gThrown = ' ' : 'matched call sent ' + gThrown);

    price('Z9999' : STRICT);
    tst_eqChar('IMQ0100' : gThrown : 'unmatched call');
    tst_check(%scan('IMQTSTR.PRICE' : imoq_lastError()) > 0
              and %scan('Z9999' : imoq_lastError()) > 0
              : 'message names the call: ' + imoq_lastError());

    price('Z9999');
    tst_check(gThrown = ' ' : 'the loose mock sent ' + gThrown);
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;

dcl-proc test_throw;
  tst_begin('THROW sends the escape message instead of answering');
  monitor;
    cmd('IMOQRESET');
    cmd('IMOQWHEN OBJ(IMQTSRV) PROC(PRICE) ARGS((1 *EQ BAD01)) +
         THROW(*MOCK *MOCK *LIBL ''boom'')');
    cmd('IMOQWHEN OBJ(IMQTSRV) PROC(PRICE) ARGS((1 *EQ BAD02)) +
         THROW(CPF9898 QCPFMSG *LIBL ''down'')');
    price('BAD01');
    tst_eqChar('IMQ0101' : gThrown : 'THROW(*MOCK)');
    price('BAD02');
    tst_eqChar('CPF9898' : gThrown : 'THROW(CPF9898)');
    price('A0001');
    tst_check(gThrown = ' ' : 'other items sent ' + gThrown);
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;

dcl-proc test_setParm;
  tst_begin('SETPARM changes an output parameter');
  monitor;
    cmd('IMOQRESET');
    cmd('IMOQWHEN OBJ(IMQTSRV) PROC(SETQTY) ARGS((1 *EQ A0001)) +
         SETPARM((2 42))');
    tst_eqNum(42 : setQty('A0001' : 5) : 'matched call');
    tst_eqNum(5 : setQty('B0002' : 5) : 'unmatched call leaves it');
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;

// ==================================================================
// Verification
// ==================================================================
dcl-proc test_verifyCounts;
  tst_begin('IMOQVERIFY compares the count of matching calls');
  monitor;
    cmd('IMOQRESET');
    price('A0001');
    price('A0001');
    price('B0002');
    tst_eqNum(3 : imoq_count(LOOSE : 'PRICE') : 'imoq_count');

    cmd('IMOQVERIFY OBJ(IMQTSRV) PROC(PRICE) ARGS((1 *EQ A0001)) +
         TIMES(*EXACTLY 2)');
    fails('IMOQVERIFY OBJ(IMQTSRV) PROC(PRICE) ARGS((1 *EQ A0001))'
          : 'matched 2 time(s)');
    cmd('IMOQVERIFY OBJ(IMQTSRV) PROC(PRICE) TIMES(*ATLEAST 3)');
    fails('IMOQVERIFY OBJ(IMQTSRV) PROC(PRICE) TIMES(*ATLEAST 4)'
          : 'at least 4');
    cmd('IMOQVERIFY OBJ(IMQTSRV) PROC(PRICE) TIMES(*ATMOST 3)');
    fails('IMOQVERIFY OBJ(IMQTSRV) PROC(PRICE) TIMES(*ATMOST 2)'
          : 'at most 2');
    cmd('IMOQVERIFY OBJ(IMQTSRV) PROC(PRICE) ARGS((1 *EQ C0003)) +
         TIMES(*NEVER)');
    fails('IMOQVERIFY OBJ(IMQTSRV) PROC(PRICE) ARGS((1 *EQ B0002)) +
           TIMES(*NEVER)' : '''B0002''');
    cmd('IMOQVERIFY OBJ(IMQTSRV) PROC(SETQTY) TIMES(*NEVER)');
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;

dcl-proc test_noMore;
  tst_begin('IMOQNOMORE fails while a call is unverified');
  monitor;
    cmd('IMOQRESET');
    price('A0001');
    price('B0002');
    fails('IMOQNOMORE' : 'Unverified interactions (2)');

    // a failed verification marks nothing
    fails('IMOQVERIFY OBJ(IMQTSRV) PROC(PRICE) TIMES(*EXACTLY 5)'
          : 'Verification failed');
    fails('IMOQNOMORE' : 'Unverified interactions (2)');

    cmd('IMOQVERIFY OBJ(IMQTSRV) PROC(PRICE) ARGS((1 *EQ A0001))');
    fails('IMOQNOMORE' : '''B0002''');
    cmd('IMOQNOMORE OBJ(IMQTSTR)');

    cmd('IMOQVERIFY OBJ(IMQTSRV) PROC(PRICE) ARGS((1 *EQ B0002))');
    cmd('IMOQNOMORE');
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;

dcl-proc test_order;
  tst_begin('IMOQORDER checks that each call came after the last');
  monitor;
    cmd('IMOQRESET');
    price('A0001');                                  // call 1
    setQty('B0002' : 1);                             // call 2
    price('C0003');                                  // call 3

    cmd('IMOQORDER OBJ(IMQTSRV) PROC(PRICE) ARGS((1 *EQ A0001))');
    cmd('IMOQORDER OBJ(IMQTSRV) PROC(SETQTY)');
    cmd('IMOQORDER OBJ(IMQTSRV) PROC(PRICE) ARGS((1 *EQ C0003))');
    fails('IMOQORDER OBJ(IMQTSRV) PROC(PRICE) ARGS((1 *EQ A0001))'
          : 'after IMQTSRV.PRICE#3');

    // a new sequence; steps skip calls in between, and each takes
    // the earliest call that fits, so SETQTY is then too early
    cmd('IMOQORDER OBJ(IMQTSRV) PROC(PRICE) ARGS((1 *EQ A0001)) +
         AFTER(*START)');
    cmd('IMOQORDER OBJ(IMQTSRV) PROC(PRICE)');
    fails('IMOQORDER OBJ(IMQTSRV) PROC(SETQTY)' : 'Matching calls: #2');

    // the order checks marked all three calls verified
    cmd('IMOQNOMORE');

    // clearing the calls starts the order over
    cmd('IMOQRESET SCOPE(*CALLS)');
    price('A0001');
    cmd('IMOQORDER OBJ(IMQTSRV) PROC(PRICE)');
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;

dcl-proc test_unused;
  tst_begin('IMOQUNUSED lists stubs that answered no call');
  monitor;
    cmd('IMOQRESET');
    cmd('IMOQWHEN OBJ(IMQTSRV) PROC(PRICE) ARGS((1 *EQ A0001)) RETURN(1)');
    cmd('IMOQWHEN OBJ(IMQTSRV) PROC(PRICE) ARGS((1 *EQ B002)) RETURN(2)');
    cmd('IMOQWHEN OBJ(IMQTSTR) PROC(PRICE) RETURN(3) TIMES(5)');
    price('A0001');
    price('A0001' : STRICT);

    fails('IMOQUNUSED' : 'Unused stubs (1)');
    fails('IMOQUNUSED' : '''B002''');
    cmd('IMOQUNUSED OBJ(IMQTSTR)');                   // 1 of 5 is enough

    cmd('IMOQRESET SCOPE(*CALLS)');                   // USED stays
    cmd('IMOQUNUSED OBJ(IMQTSTR)');
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;

dcl-proc test_capture;
  tst_begin('arguments are captured as they arrived');
  monitor;
    cmd('IMOQRESET');
    cmd('IMOQWHEN OBJ(IMQTSRV) PROC(SETQTY) SETPARM((2 42))');
    price('A0001');
    price('B0002');
    tst_eqChar('A0001' : imoq_arg(LOOSE : 'PRICE' : 1 : 1) : 'first call');
    tst_eqChar('B0002' : imoq_arg(LOOSE : 'PRICE' : LAST : 1)
               : 'last call');
    tst_check(%scan('*ERROR' : imoq_arg(LOOSE : 'PRICE' : 3 : 1)) = 1
              : 'call 3 does not exist');

    tst_eqNum(42 : setQty('C0003' : 5) : 'SETPARM');
    tst_eqChar('5' : imoq_arg(LOOSE : 'SETQTY' : 1 : 2)
               : 'captured before SETPARM');
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;

dcl-proc test_reset;
  tst_begin('IMOQRESET clears only its scope and mock');
  monitor;
    cmd('IMOQRESET');
    cmd('IMOQWHEN OBJ(IMQTSRV) PROC(PRICE) RETURN(1)');
    cmd('IMOQWHEN OBJ(IMQTSTR) PROC(PRICE) RETURN(2)');
    price('A0001');
    price('A0001' : STRICT);

    cmd('IMOQRESET SCOPE(*CALLS)');
    tst_eqNum(0 : imoq_count(LOOSE : 'PRICE') : '*CALLS: calls');
    tst_eqNum(1 : price('A0001') : '*CALLS: stubs kept');

    cmd('IMOQRESET SCOPE(*STUBS)');
    tst_eqNum(1 : imoq_count(LOOSE : 'PRICE') : '*STUBS: calls kept');
    tst_eqNum(0 : price('A0001') : '*STUBS: stubs');

    cmd('IMOQWHEN OBJ(IMQTSRV) PROC(PRICE) RETURN(1)');
    cmd('IMOQWHEN OBJ(IMQTSTR) PROC(PRICE) RETURN(2)');
    cmd('IMOQRESET OBJ(IMQTSTR)');
    tst_eqNum(1 : price('A0001') : 'OBJ: other mock''s stubs kept');
    tst_eqNum(3 : imoq_count(LOOSE : 'PRICE') : 'OBJ: other mock''s calls');
    tst_eqNum(0 : imoq_count(STRICT : 'PRICE') : 'OBJ: its calls');
    price('A0001' : STRICT);
    tst_eqChar('IMQ0100' : gThrown : 'OBJ: its stubs');
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;

dcl-proc test_rejected;
  tst_begin('invalid stubs are rejected and never answer');
  monitor;
    cmd('IMOQRESET');
    fails('IMOQWHEN OBJ(IMQTSRV) PROC(PRICE) ARGS((2 *EQ X)) RETURN(1)'
          : 'parameter 2 of IMQTSRV.PRICE is not declared');
    fails('IMOQWHEN OBJ(IMQTSRV) PROC(PRICE) RETURN(''abc'')'
          : 'RETURN value 1');
    fails('IMOQWHEN OBJ(IMQTSRV) PROC(SETQTY) SETPARM((3 X))'
          : 'parameter 3 of IMQTSRV.SETQTY is not declared');
    fails('IMOQWHEN OBJ(IMQTSRV) PROC(NOPE) RETURN(1)' : 'does not export');
    fails('IMOQWHEN OBJ(IMQTNONE) RETURN(1)' : 'does not exist');
    fails('IMOQVERIFY OBJ(IMQTSRV) PROC(PRICE) ARGS((3 *EQ X))'
          : 'not declared');
    tst_eqNum(0 : price('A0001') : 'no stub was saved');
    cmd('IMOQUNUSED');
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;
