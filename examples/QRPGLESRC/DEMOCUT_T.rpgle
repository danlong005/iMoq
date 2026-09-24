**free
// ------------------------------------------------------------------
// DEMOCUT_T - iMoq demo tests for DEMOCUT.
// The mocks (DEMODEP *PGM, DEMOSRV *SRVPGM strict) are created by the
// IMOQDEMO driver; each test stubs and verifies them with the RPG
// API in IMOQ_H (imoq_when, imoq_verify ...). The last test uses the
// command form, imoq('IMOQWHEN ...'), which works the same way.
// Written with a tiny harness; in RPGUnit the same calls go inside
// test procedures with assert().
// ------------------------------------------------------------------
ctl-opt main(runTests) option(*srcstmt:*nodebugio);

/copy QTEMP/IMOQINC,IMOQ_H

dcl-pr demo_orderTotal packed(11:2) extproc('DEMO_ORDERTOTAL');
  custId char(10) const;
  amount packed(11:2) const;
  state char(2) const;
  custName char(50);
end-pr;

/copy QTEMP/IMOQINC,IMOQTST_H

dcl-proc runTests;
  dcl-pi *n;
    report char(8000);
    failures int(10);
  end-pi;
  tst_init(report);
  test_stubbedValues();
  test_unknownCustomer();
  test_dependencyThrows();
  test_consecutiveReturns();
  test_argumentCapture();
  test_newestMatchingStubWins();
  test_timesLimit();
  test_likeMatcher();
  test_verifyFailureIsReported();
  test_strictMockRejectsUnstubbedCall();
  test_invalidStubbingIsRejected();
  test_invalidCommandIsRejected();
  tst_summary(failures);
end-proc;

// ------------------------------------------------------------------
dcl-proc test_stubbedValues;
  dcl-s total packed(11:2);
  dcl-s name char(50);
  dcl-s h int(10);
  dcl-s v int(10);
  tst_begin('stubbed SETPARM and RETURN values reach the code');
  monitor;
    imoq_reset();
    h = imoq_when('DEMODEP');
    imoq_with(h : 1 : IMOQ_EQ : 'C001');
    imoq_setParm(h : 2 : 'ACME CORP');
    imoq_setParm(h : 3 : '1');
    h = imoq_when('DEMOSRV' : 'DEMO_CALCTAX');
    imoq_returns(h : 6.00);

    total = demo_orderTotal('C001' : 100 : 'PA' : name);

    tst_eqNum(106.00 : total : 'total');
    tst_eqChar('ACME CORP' : name : 'customer name');
    v = imoq_verify('DEMODEP');
    imoq_with(v : 1 : IMOQ_EQ : 'C001');
    tst_check(imoq_calledOnce(v) : imoq_lastError());
    v = imoq_verify('DEMOSRV' : 'DEMO_CALCTAX');
    imoq_with(v : 1 : IMOQ_EQ : 100);
    imoq_with(v : 2 : IMOQ_EQ : 'PA');
    tst_check(imoq_calledOnce(v) : imoq_lastError());
    tst_check(imoq_noMoreCalls() : imoq_lastError());
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;

dcl-proc test_unknownCustomer;
  dcl-s total packed(11:2);
  dcl-s name char(50);
  dcl-s h int(10);
  dcl-s v int(10);
  tst_begin('unknown customer never calculates tax');
  monitor;
    imoq_reset();
    h = imoq_when('DEMODEP');
    imoq_setParm(h : 3 : '0');

    total = demo_orderTotal('NOPE' : 100 : 'PA' : name);

    tst_eqNum(-1 : total : 'total');
    v = imoq_verify('DEMOSRV' : 'DEMO_CALCTAX');
    tst_check(imoq_neverCalled(v) : imoq_lastError());
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;

dcl-proc test_dependencyThrows;
  dcl-s total packed(11:2);
  dcl-s name char(50);
  dcl-s h int(10);
  tst_begin('imoq_throws sends an escape message the code can monitor');
  monitor;
    imoq_reset();
    h = imoq_when('DEMODEP');
    imoq_throws(h : 'CPF9898' : 'Customer DB down' : 'QCPFMSG');

    total = demo_orderTotal('C001' : 100 : 'PA' : name);

    tst_eqNum(-2 : total : 'total');
    tst_eqNum(1 : imoq_count('DEMODEP' : IMOQ_PGM) : 'DEMODEP calls');
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;

dcl-proc test_consecutiveReturns;
  dcl-s name char(50);
  dcl-s h int(10);
  dcl-s v int(10);
  tst_begin('return values answer in order and repeat the last');
  monitor;
    imoq_reset();
    h = imoq_when('DEMODEP');
    imoq_setParm(h : 3 : '1');
    h = imoq_when('DEMOSRV' : 'DEMO_CALCTAX');
    imoq_returns(h : 1.00);
    imoq_returns(h : 2.00);

    tst_eqNum(11 : demo_orderTotal('C1' : 10 : 'PA' : name) : 'call 1');
    tst_eqNum(12 : demo_orderTotal('C1' : 10 : 'PA' : name) : 'call 2');
    tst_eqNum(12 : demo_orderTotal('C1' : 10 : 'PA' : name) : 'call 3');
    v = imoq_verify('DEMOSRV' : 'DEMO_CALCTAX');
    tst_check(imoq_calledTimes(v : 3) : imoq_lastError());
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;

dcl-proc test_argumentCapture;
  dcl-s name char(50);
  dcl-s h int(10);
  tst_begin('arguments are captured for inspection');
  monitor;
    imoq_reset();
    h = imoq_when('DEMODEP');
    imoq_setParm(h : 3 : '1');
    h = imoq_when('DEMOSRV' : 'DEMO_CALCTAX');
    imoq_returns(h : 0);

    demo_orderTotal('C777' : 25.5 : 'NJ' : name);

    tst_eqChar('C777' : imoq_arg('DEMODEP' : IMOQ_PGM : 1 : 1)
             : 'DEMODEP parm 1');
    tst_eqChar('25.50' : imoq_arg('DEMOSRV' : 'DEMO_CALCTAX'
             : IMOQ_LAST : 1) : 'amount as text');
    tst_eqNum(25.5 : imoq_argNum('DEMOSRV' : 'DEMO_CALCTAX'
            : IMOQ_LAST : 1) : 'amount as a number');
    tst_eqChar('NJ' : imoq_arg('DEMOSRV' : 'demo_calcTax'
             : IMOQ_LAST : 2) : 'state (case-insensitive PROC)');
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;

dcl-proc test_newestMatchingStubWins;
  dcl-s name char(50);
  dcl-s h int(10);
  tst_begin('the newest matching stub answers');
  monitor;
    imoq_reset();
    h = imoq_when('DEMODEP');
    imoq_setParm(h : 3 : '1');
    h = imoq_when('DEMOSRV' : 'DEMO_CALCTAX');
    imoq_returns(h : 5.00);
    h = imoq_when('DEMOSRV' : 'DEMO_CALCTAX');
    imoq_with(h : 2 : IMOQ_EQ : 'NY');
    imoq_returns(h : 8.88);
    h = imoq_when('DEMOSRV' : 'DEMO_CALCTAX');
    imoq_with(h : 1 : IMOQ_GT : 1000);
    imoq_returns(h : 99.00);

    tst_eqNum(105.00 : demo_orderTotal('C1' : 100 : 'PA' : name)
            : 'default stub');
    tst_eqNum(108.88 : demo_orderTotal('C1' : 100 : 'NY' : name)
            : 'state NY');
    tst_eqNum(5099.00 : demo_orderTotal('C1' : 5000 : 'PA' : name)
            : 'amount > 1000');
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;

dcl-proc test_timesLimit;
  dcl-s name char(50);
  dcl-s h int(10);
  tst_begin('imoq_times(n) stops answering after n calls');
  monitor;
    imoq_reset();
    h = imoq_when('DEMODEP');
    imoq_setParm(h : 3 : '1');
    imoq_times(h : 1);
    h = imoq_when('DEMOSRV' : 'DEMO_CALCTAX');
    imoq_returns(h : 0);

    tst_eqNum(100 : demo_orderTotal('C1' : 100 : 'PA' : name)
            : 'first call');
    // loose program mock: no match leaves parameters untouched
    tst_eqNum(-1 : demo_orderTotal('C1' : 100 : 'PA' : name)
            : 'second call');
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;

dcl-proc test_likeMatcher;
  dcl-s name char(50);
  dcl-s h int(10);
  tst_begin('IMOQ_LIKE matches with % and _ wildcards');
  monitor;
    imoq_reset();
    h = imoq_when('DEMODEP');
    imoq_with(h : 1 : IMOQ_LIKE : 'C_9%');
    imoq_setParm(h : 2 : 'LIKE HIT');
    imoq_setParm(h : 3 : '1');
    h = imoq_when('DEMOSRV' : 'DEMO_CALCTAX');
    imoq_returns(h : 0);

    tst_eqNum(1 : demo_orderTotal('CX900' : 1 : 'PA' : name) : 'match');
    tst_eqChar('LIKE HIT' : name : 'name');
    tst_eqNum(-1 : demo_orderTotal('CX800' : 1 : 'PA' : name)
            : 'no match');
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;

dcl-proc test_verifyFailureIsReported;
  dcl-s name char(50);
  dcl-s h int(10);
  dcl-s v int(10);
  tst_begin('failed verifications explain what happened');
  monitor;
    imoq_reset();
    h = imoq_when('DEMODEP');
    imoq_setParm(h : 3 : '1');
    h = imoq_when('DEMOSRV' : 'DEMO_CALCTAX');
    imoq_returns(h : 1);
    demo_orderTotal('C42' : 10 : 'OH' : name);

    v = imoq_verify('DEMODEP');
    tst_check(not imoq_calledTimes(v : 3)
            : 'imoq_calledTimes(v : 3) should fail');
    tst_check(%scan('exactly 3 time(s)' : imoq_lastError()) > 0
              and %scan('''C42''' : imoq_lastError()) > 0
            : 'message should describe the calls: ' + imoq_lastError());
    tst_check(not imoq_noMoreCalls('DEMOSRV')
            : 'imoq_noMoreCalls should fail for the unverified call');
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;

dcl-proc test_strictMockRejectsUnstubbedCall;
  dcl-s name char(50);
  dcl-s total packed(11:2);
  dcl-s caught ind;
  dcl-s h int(10);
  tst_begin('strict mock sends IMQ0100 for an unstubbed call');
  monitor;
    imoq_reset();
    h = imoq_when('DEMODEP');
    imoq_setParm(h : 3 : '1');
    h = imoq_when('DEMOSRV' : 'DEMO_CALCTAX');
    imoq_with(h : 2 : IMOQ_EQ : 'PA');
    imoq_returns(h : 1);
    monitor;
      total = demo_orderTotal('C1' : 10 : 'TX' : name);
    on-error;
      caught = *on;
    endmon;
    tst_check(caught : 'escape message expected, total was '
            + %char(total));
    tst_check(%scan('Unexpected call to DEMOSRV.DEMO_CALCTAX'
                    : imoq_lastError()) > 0 : imoq_lastError());
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;

// Setup calls send escape IMQ0300 when they fail. rejected() runs
// one bad setup and reports whether it was rejected.
dcl-proc rejected;
  dcl-pi *n ind;
    step int(10) const;
  end-pi;
  dcl-s h int(10);
  monitor;
    select;
    when step = 1;
      h = imoq_when('DEMOSRV' : 'NOPE');
    when step = 2;
      h = imoq_when('DEMODEP');
      imoq_setParm(h : 3 : 'X');
    when step = 3;
      h = imoq_when('DEMOSRV' : 'DEMO_CALCTAX');
      imoq_returns(h : 12345678901.99);
    when step = 4;
      h = imoq_when('DEMODEP');
      imoq_with(h : 9 : IMOQ_EQ : 'X');
    when step = 5;
      h = imoq_when('DEMODEP');
      imoq_with(h : 1 : '*BOGUS' : 'X');
    endsl;
  on-error;
    return *on;
  endmon;
  return *off;
end-proc;

dcl-proc test_invalidStubbingIsRejected;
  tst_begin('invalid stubs are rejected with IMQ0300');
  monitor;
    imoq_reset();
    tst_check(rejected(1) : 'unknown procedure accepted');
    tst_check(%scan('does not export' : imoq_lastError()) > 0
            : imoq_lastError());
    tst_check(rejected(2) : 'invalid indicator accepted');
    tst_check(rejected(3) : 'overflow accepted');
    tst_check(rejected(4) : 'undeclared parameter accepted');
    tst_check(rejected(5) : 'unknown matcher accepted');
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;

// The command form still works from RPG, through imoq()/imoq_ok()
dcl-proc test_invalidCommandIsRejected;
  tst_begin('invalid IMOQWHEN commands are rejected');
  monitor;
    imoq('IMOQRESET');
    tst_check(not imoq_ok('IMOQWHEN OBJ(DEMOSRV) PROC(NOPE) +
              RETURN(''1'')') : 'unknown procedure accepted');
    tst_check(%scan('does not export' : imoq_lastError()) > 0
            : imoq_lastError());
    tst_check(not imoq_ok('IMOQWHEN OBJ(DEMODEP) SETPARM((3 ''X''))')
            : 'invalid indicator accepted');
    tst_check(not imoq_ok('IMOQWHEN OBJ(DEMOSRV) PROC(DEMO_CALCTAX) +
              RETURN(''12345678901.99'')') : 'overflow accepted');
    tst_check(not imoq_ok('IMOQWHEN OBJ(DEMODEP) ARGS((9 *EQ X))')
            : 'undeclared parameter accepted');
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;
