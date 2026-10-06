**free
// ------------------------------------------------------------------
// IMOQCMD_T - iMoq command-level tests: stub selection, answers,
//             COPYARG, answer procedures, TIMES, strict mocks,
//             verification counts, IMOQNOMORE, call order, unused
//             stubs, capture and reset scopes.
// The mocks are declared but never built: calls go straight to
// imoq_invoke, the entry point every generated stub calls.
// Run with IMOQTEST. Called without parameters, it is the answer
// program of test_answerPgm.
// ------------------------------------------------------------------
ctl-opt main(runTests) option(*srcstmt:*nodebugio);

/copy QTEMP/IMOQINC,IMOQENG_H

// Two service program mocks, each with
//   PRICE(item char(5) const) returns packed(7:2)
//   SETQTY(item char(5) const : qty int(10))
//   SCALE(amount packed(7:2) const : result packed(9:2))
//     returns packed(7:2)
//   NEST(boxes likeds(boxes_t)): data structures in data structures
//   NOTE(text char(33000) const): a long argument
dcl-c LOOSE 'IMQTSRV';
dcl-c STRICT 'IMQTSTR';
dcl-c LAST -1;

// NEST's parameter: 2 boxes of 20 bytes, each with a tag and 3 items
dcl-ds item_t qualified template;
  sku char(4);
  qty int(5);
end-ds;
dcl-ds box_t qualified template;
  tag char(2);
  item likeds(item_t) dim(3);
end-ds;
dcl-ds boxes_t qualified template;
  box likeds(box_t) dim(2);
end-ds;

// Escape message the last simulated call sent, blank if none
dcl-s gThrown char(7);

/copy QTEMP/IMOQINC,IMOQTST_H

dcl-proc runTests;
  dcl-pi *n;
    report char(8000);
    failures int(10);
  end-pi;
  if %parms() = 0;
    answerProgram();
    return;
  endif;
  tst_init(report);
  if setup();
    test_selection();
    test_listMatchers();
    test_orGroups();
    test_series();
    test_times();
    test_strict();
    test_throw();
    test_setParm();
    test_nestedFields();
    test_longArgs();
    test_copyArg();
    test_copyRejected();
    test_answerProc();
    test_answerFails();
    test_answerByName();
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

// Call SCALE of the loose mock; returns what it returned, and the
// result parameter as the stub left it
dcl-proc scale;
  dcl-pi *n packed(7:2);
    amount packed(7:2) const;
    result packed(9:2);
  end-pi;
  dcl-s a packed(7:2);
  dcl-s r packed(7:2);
  dcl-s ptrs pointer dim(64);
  dcl-ds thr likeds(imoq_throw_t);
  a = amount;
  ptrs(1) = %addr(a);
  ptrs(2) = %addr(result);
  imoq_invoke(LOOSE : 'SCALE' : 2 : %addr(ptrs) : %addr(r) : thr);
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

// Call NEST of the loose mock
dcl-proc nest;
  dcl-pi *n;
    boxes likeds(boxes_t);
  end-pi;
  dcl-s ptrs pointer dim(64);
  dcl-ds thr likeds(imoq_throw_t);
  ptrs(1) = %addr(boxes);
  imoq_invoke(LOOSE : 'NEST' : 1 : %addr(ptrs) : *null : thr);
  gThrown = thr.msgId;
end-proc;

// Call NOTE of the loose mock
dcl-proc note;
  dcl-pi *n;
    text char(33000) const;
  end-pi;
  dcl-s t char(33000);
  dcl-s ptrs pointer dim(64);
  dcl-ds thr likeds(imoq_throw_t);
  t = text;
  ptrs(1) = %addr(t);
  imoq_invoke(LOOSE : 'NOTE' : 1 : %addr(ptrs) : *null : thr);
  gThrown = thr.msgId;
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
    cmd('IMOQPROC OBJ(' + o + ') PROC(SCALE) RTNTYPE(*PACKED 7 2) +
         PARMS((*PACKED 7 2 *CONST) (*PACKED 9 2))');
    cmd('IMOQPROC OBJ(' + o + ') PROC(NEST) PARMS((*CHAR 40))');
    cmd('IMOQPROC OBJ(' + o + ') PROC(NOTE) PARMS((*CHAR 33000 *CONST))');
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

dcl-proc test_orGroups;
  tst_begin('OR groups: one group of ARGS entries must match');
  monitor;
    // item A0001, or a quantity over 100
    cmd('IMOQRESET');
    cmd('IMOQWHEN OBJ(IMQTSRV) PROC(SETQTY) +
         ARGS((1 *EQ A0001 *N 1) (2 *GT 100 *N 2)) SETPARM((2 0))');
    tst_eqNum(0 : setQty('A0001' : 5) : 'group 1 matches');
    tst_eqNum(0 : setQty('B0002' : 150) : 'group 2 matches');
    tst_eqNum(0 : setQty('A0001' : 150) : 'both groups match');
    tst_eqNum(5 : setQty('B0002' : 5) : 'neither group matches');

    // entries without a group always apply: an A item, and a
    // quantity below zero or over 100
    cmd('IMOQRESET');
    cmd('IMOQWHEN OBJ(IMQTSRV) PROC(SETQTY) +
         ARGS((1 *LIKE ''A%'') (2 *LT 0 *N 1) (2 *GT 100 *N 2)) +
         SETPARM((2 50))');
    tst_eqNum(50 : setQty('A0001' : -1) : 'always, and group 1');
    tst_eqNum(50 : setQty('A0002' : 150) : 'always, and group 2');
    tst_eqNum(10 : setQty('A0001' : 10) : 'always, but no group');
    tst_eqNum(150 : setQty('B0002' : 150) : 'a group, but not always');

    // all entries of a group must match
    cmd('IMOQRESET');
    cmd('IMOQWHEN OBJ(IMQTSRV) PROC(SETQTY) +
         ARGS((1 *EQ A0001 *N 1) (2 *EQ 5 *N 1) (1 *EQ B0002 *N 2)) +
         SETPARM((2 0))');
    tst_eqNum(0 : setQty('A0001' : 5) : 'all of group 1');
    tst_eqNum(6 : setQty('A0001' : 6) : 'part of group 1');
    tst_eqNum(0 : setQty('B0002' : 6) : 'group 2');

    // group numbers don't need to start at 1 or follow each other
    cmd('IMOQRESET');
    cmd('IMOQWHEN OBJ(IMQTSRV) PROC(PRICE) +
         ARGS((1 *EQ A0001 *N 7) (1 *EQ B0002 *N 64)) RETURN(9)');
    tst_eqNum(9 : price('B0002') : 'groups 7 and 64');
    tst_eqNum(0 : price('C0003') : 'groups 7 and 64: no match');

    // verification and order checks take groups too
    cmd('IMOQVERIFY OBJ(IMQTSRV) PROC(PRICE) +
         ARGS((1 *EQ A0001 *N 1) (1 *EQ C0003 *N 2)) TIMES(*ONCE)');
    cmd('IMOQVERIFY OBJ(IMQTSRV) PROC(SETQTY) TIMES(*NEVER)');
    cmd('IMOQORDER OBJ(IMQTSRV) PROC(PRICE) AFTER(*START) +
         ARGS((1 *EQ Z9999 *N 1) (1 *EQ B0002 *N 2))');
    cmd('IMOQORDER OBJ(IMQTSRV) PROC(PRICE) +
         ARGS((1 *EQ C0003 *N 1) (1 *EQ Z9999 *N 2))');
    fails('IMOQVERIFY OBJ(IMQTSRV) PROC(PRICE) +
           ARGS((1 *NE C0003) (1 *EQ Z9999 *N 1) (1 *EQ Y8888 *N 2))'
          : 'with (1 *NE ''C0003'', (1 *EQ ''Z9999'') or +
             (1 *EQ ''Y8888''))');
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;

dcl-proc test_nestedFields;
  dcl-ds b likeds(boxes_t) inz(*likeds);
  tst_begin('*DS fields: arrays of data structures, nested');
  monitor;
    cmd('IMOQRESET');
    cmd('IMOQFIELD OBJ(IMQTSRV) PROC(NEST) PARM(1) +
         FIELDS((BOX 1 *DS 20 0 2) (BOX.TAG 1 *CHAR 2) +
                (BOX.ITEM *NEXT *DS 6 0 3) (BOX.ITEM.SKU 1 *CHAR 4) +
                (BOX.ITEM.QTY *NEXT *INT 5))');
    cmd('IMOQWHEN OBJ(IMQTSRV) PROC(NEST) +
         ARGS((1 *EQ 7 ''BOX(1).ITEM(2).QTY'') +
              (1 *EQ B2 ''BOX(2).TAG'')) +
         SETPARM((1 ZZ ''BOX(2).ITEM(3).SKU'') +
                 (1 9 ''box(1).item(1).qty''))');

    b.box(1).item(2).qty = 7;
    b.box(2).tag = 'B2';
    nest(b);
    tst_eqChar('ZZ' : b.box(2).item(3).sku : 'BOX(2).ITEM(3).SKU set');
    tst_eqNum(9 : b.box(1).item(1).qty : 'BOX(1).ITEM(1).QTY set');
    tst_eqChar(' ' : b.box(1).item(3).sku : 'other elements untouched');
    tst_eqNum(7 : b.box(1).item(2).qty : 'matched field untouched');

    clear b;
    b.box(1).item(2).qty = 7;
    nest(b);
    tst_eqChar(' ' : b.box(2).item(3).sku : 'BOX(2).TAG differs');

    tst_eqChar('7' : imoq_arg(LOOSE : 'NEST' : 1 : 1 : 'BOX(1).ITEM(2).QTY')
               : 'captured BOX(1).ITEM(2).QTY');
    tst_eqChar('' : imoq_arg(LOOSE : 'NEST' : 1 : 1
                             : 'BOX(2).ITEM(3).SKU')
               : 'values are captured as they arrived, before SETPARM');
    cmd('IMOQVERIFY OBJ(IMQTSRV) PROC(NEST) +
         ARGS((1 *EQ B2 ''BOX(2).TAG'')) TIMES(*ONCE)');

    // references that name no value
    fails('IMOQWHEN OBJ(IMQTSRV) PROC(NEST) ARGS((1 *EQ X ''BOX(1)''))'
          : 'is a data structure. Name one of its fields, such as BOX(1).TAG');
    fails('IMOQWHEN OBJ(IMQTSRV) PROC(NEST) +
           ARGS((1 *EQ X ''BOX(1).ITEM(1)''))' : 'such as BOX(1).ITEM(1).SKU');
    fails('IMOQWHEN OBJ(IMQTSRV) PROC(NEST) +
           ARGS((1 *EQ X ''BOX(1).TAG.X''))' : 'is not a data structure');
    fails('IMOQWHEN OBJ(IMQTSRV) PROC(NEST) ARGS((1 *EQ X BOX.TAG))'
          : 'name an element, such as BOX(1)');
    fails('IMOQWHEN OBJ(IMQTSRV) PROC(NEST) +
           ARGS((1 *EQ X ''BOX(3).TAG''))' : 'has 2 elements, not 3');
    fails('IMOQWHEN OBJ(IMQTSRV) PROC(NEST) +
           ARGS((1 *EQ X ''BOX(1).NOPE''))' : 'Field BOX.NOPE');

    // declarations that don't fit
    fails('IMOQFIELD OBJ(IMQTSRV) PROC(NEST) PARM(1) +
           FIELDS((X.A 1 *CHAR 1))' : 'declare X as a *DS field');
    fails('IMOQFIELD OBJ(IMQTSRV) PROC(NEST) PARM(1) +
           FIELDS((X 1 *CHAR 4) (X.A 1 *CHAR 1))' : 'declare X as a *DS');
    fails('IMOQFIELD OBJ(IMQTSRV) PROC(NEST) PARM(1) +
           FIELDS((X 1 *DS 4) (X.A 1 *CHAR 5))'
          : 'don''t fit in data structure X, which is 4 bytes');
    fails('IMOQFIELD OBJ(IMQTSRV) PROC(NEST) PARM(1) +
           FIELDS((X 1 *DS 10 0 5))' : 'don''t fit in');
    fails('IMOQFIELD OBJ(IMQTSRV) PROC(NEST) PARM(1) FIELDS((X 1 *DS))'
          : 'size of one element');
    fails('IMOQFIELD OBJ(IMQTSRV) PROC(NEST) PARM(1) +
           FIELDS((X 1 *DS 40) (X.A 1 *CHAR 1) (X.A 2 *CHAR 1))'
          : 'declared twice');
    // AA(40).B(1).C(1).D(1).E(1).F(1).G(1).H(1) is 41 characters
    fails('IMOQFIELD OBJ(IMQTSRV) PROC(NEST) PARM(1) +
           FIELDS((AA 1 *DS 1 0 40) (AA.B 1 *DS 1 0 1) +
                  (AA.B.C 1 *DS 1 0 1) (AA.B.C.D 1 *DS 1 0 1) +
                  (AA.B.C.D.E 1 *DS 1 0 1) (AA.B.C.D.E.F 1 *DS 1 0 1) +
                  (AA.B.C.D.E.F.G 1 *DS 1 0 1) +
                  (AA.B.C.D.E.F.G.H 1 *CHAR 1 0 1))'
          : 'references are at most 40');
    // the failed declarations left the fields alone
    tst_eqChar('B2' : imoq_arg(LOOSE : 'NEST' : 1 : 1 : 'BOX(2).TAG')
               : 'fields still declared');
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;

dcl-proc test_longArgs;
  dcl-s t char(33000);
  dcl-s v varchar(IMOQ_MAXARG);
  tst_begin('arguments are recorded and matched up to 32,000 characters');
  monitor;
    cmd('IMOQRESET');
    cmd('IMOQWHEN OBJ(IMQTSRV) PROC(NOTE) +
         ARGS((1 *LIKE ''%END-MARK'')) THROW(*MOCK)');
    %subst(t : 3992 : 8) = 'END-MARK';
    note(t);
    tst_eqChar('IMQ0101' : gThrown : '*LIKE matched past 1,024');

    v = imoq_arg(LOOSE : 'NOTE' : 1 : 1);
    tst_eqNum(3999 : %len(v) : 'captured in full');
    tst_eqChar('END-MARK' : %subst(v : 3992) : 'captured text');

    // ABCDE ends at 32,000, FGHIJ comes after it
    %subst(t : 31996 : 10) = 'ABCDEFGHIJ';
    note(t);
    v = imoq_arg(LOOSE : 'NOTE' : LAST : 1);
    tst_eqNum(32000 : %len(v) : 'cut at 32,000');
    tst_eqChar('ABCDE' : %subst(v : 31996) : 'up to 32,000');

    cmd('IMOQVERIFY OBJ(IMQTSRV) PROC(NOTE) +
         ARGS((1 *LIKE ''%END-MARK%'')) TIMES(*EXACTLY 2)');
    cmd('IMOQVERIFY OBJ(IMQTSRV) PROC(NOTE) +
         ARGS((1 *LIKE ''%ABCDE'')) TIMES(*ONCE)');
    cmd('IMOQVERIFY OBJ(IMQTSRV) PROC(NOTE) +
         ARGS((1 *LIKE ''%FGHIJ%'')) TIMES(*NEVER)');
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

dcl-proc test_copyArg;
  dcl-s r packed(9:2);
  tst_begin('COPYARG copies arguments into outputs');
  monitor;
    cmd('IMOQRESET');
    cmd('IMOQWHEN OBJ(IMQTSRV) PROC(SCALE) COPYARG((1 0) (1 2))');
    tst_eqNum(12.5 : scale(12.5 : r) : 'to the return value');
    tst_eqNum(12.5 : r : 'to parameter 2');
    tst_eqNum(7 : scale(7 : r) : 'every call copies its own');

    // text converts to the target's type
    cmd('IMOQWHEN OBJ(IMQTSRV) PROC(SETQTY) COPYARG((1 2))');
    tst_eqNum(42 : setQty('00042' : 5) : 'char to int');
    tst_check(gThrown = ' ' : 'char to int sent ' + gThrown);

    // a value that doesn't fit ends the call with IMQ0102
    setQty('ABC' : 5);
    tst_eqChar('IMQ0102' : gThrown : 'char ''ABC'' to int');
    tst_check(%scan('COPYARG 1 to 2' : imoq_lastError()) > 0
              : 'message names the copy: ' + imoq_lastError());

    // next to RETURN and the matchers of the same stub
    cmd('IMOQWHEN OBJ(IMQTSRV) PROC(SCALE) ARGS((1 *GT 100)) +
         RETURN(1) COPYARG((1 2))');
    tst_eqNum(1 : scale(200 : r) : 'RETURN');
    tst_eqNum(200 : r : 'COPYARG next to RETURN');
    tst_eqNum(3 : scale(3 : r) : 'the older stub');
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;

dcl-proc test_copyRejected;
  tst_begin('invalid COPYARG entries are rejected');
  monitor;
    cmd('IMOQRESET');
    fails('IMOQWHEN OBJ(IMQTSRV) PROC(SCALE) COPYARG((3 2))'
          : 'parameter 3 of IMQTSRV.SCALE is not declared');
    fails('IMOQWHEN OBJ(IMQTSRV) PROC(SCALE) COPYARG((1 3))'
          : 'parameter 3 of IMQTSRV.SCALE is not declared');
    fails('IMOQWHEN OBJ(IMQTSRV) PROC(SETQTY) COPYARG((1 0))'
          : 'has no declared return value');
    fails('IMOQWHEN OBJ(IMQTSRV) PROC(SCALE) RETURN(1) COPYARG((1 0))'
          : 'comes from RETURN already');
    fails('IMOQWHEN OBJ(IMQTSRV) PROC(SCALE) SETPARM((2 1)) +
           COPYARG((1 2))' : 'SETPARM entry 1 sets 2 already');
    fails('IMOQWHEN OBJ(IMQTSRV) PROC(SCALE) COPYARG((1 2 NOPE))'
          : 'Field NOPE');
    tst_eqNum(0 : price('A0001') : 'no stub was saved');
    cmd('IMOQUNUSED');
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;

// ==================================================================
// Answer procedures. The RPG API (imoq_answers) passes a procedure
// pointer to imoq_stubSave, as these tests do.
// ==================================================================

// Save a stub for SCALE with RETURN(1) SETPARM((2 1)), finished by
// answer procedure ptr
dcl-proc stubWithAnswer;
  dcl-pi *n;
    ptr pointer(*proc) const;
  end-pi;
  dcl-ds stub likeds(imoq_stub_t);
  dcl-ds err likeds(imoq_err_t);
  clear stub;
  stub.obj = LOOSE;
  stub.proc = 'SCALE';
  stub.times = -1;
  stub.nRtn = 1;
  stub.rtn(1) = '1';
  stub.nSet = 1;
  stub.setNo(1) = 2;
  stub.setVal(1) = '1';
  stub.ansPtr = ptr;
  tst_check(imoq_stubSave(stub : err) : 'stub not saved: ' + err.text);
end-proc;

// SCALE: returns amount * 2 and sets result to amount * 3
dcl-proc doubleIt;
  dcl-ds err likeds(imoq_err_t);
  dcl-s v varchar(IMOQ_MAXARG);
  dcl-s n packed(31:9);
  imoq_answerGet(1 : '' : v : err);
  n = %dec(v : 31 : 9);
  imoq_answerPut(0 : '' : %char(n * 2) : err);
  imoq_answerPut(2 : '' : %char(n * 3) : err);
end-proc;

// SCALE: fails
dcl-proc divideByZero;
  dcl-s z int(10);
  z = 1 / z;
end-proc;

// SCALE: tries to set a parameter SCALE doesn't have
dcl-proc setsParm3;
  dcl-ds err likeds(imoq_err_t);
  if not imoq_answerPut(3 : '' : '1' : err);
    imoq_setLastError(err.text);
    divideByZero();
  endif;
end-proc;

dcl-proc test_answerProc;
  dcl-s r packed(9:2);
  dcl-s v varchar(IMOQ_MAXARG);
  dcl-ds err likeds(imoq_err_t);
  tst_begin('an answer procedure reads and sets the call');
  monitor;
    cmd('IMOQRESET');
    stubWithAnswer(%paddr(doubleIt));
    tst_eqNum(10 : scale(5 : r) : 'return value, not RETURN(1)');
    tst_eqNum(15 : r : 'parameter 2, not SETPARM((2 1))');
    tst_eqNum(-2 : scale(-1 : r) : 'every call gets its own');
    tst_check(gThrown = ' ' : 'the answer sent ' + gThrown);
    tst_eqNum(5 : %dec(imoq_arg(LOOSE : 'SCALE' : 1 : 1) : 31 : 9)
              : 'the call is recorded as it arrived');

    tst_check(not imoq_answerGet(1 : '' : v : err)
              : 'imoq_answerGet worked outside an answer');
    tst_check(%scan('No call is being answered' : err.text) > 0
              : 'outside an answer: ' + err.text);
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;

dcl-proc test_answerFails;
  dcl-s r packed(9:2);
  tst_begin('a failing answer procedure ends the call with IMQ0102');
  monitor;
    cmd('IMOQRESET');
    stubWithAnswer(%paddr(divideByZero));
    scale(5 : r);
    tst_eqChar('IMQ0102' : gThrown : 'MCH1211 in the answer');
    tst_check(%scan('IMQTSRV.SCALE' : imoq_lastError()) > 0
              : 'message names the mock: ' + imoq_lastError());

    cmd('IMOQRESET');
    stubWithAnswer(%paddr(setsParm3));
    scale(5 : r);
    tst_eqChar('IMQ0102' : gThrown : 'bad imoq_answerPut');
    tst_check(%scan('Parameter 3 of IMQTSRV.SCALE is not declared'
                    : imoq_lastError()) > 0
              : 'message gives the reason: ' + imoq_lastError());
  on-error;
    tst_error(imoq_lastError());
  endmon;
  tst_end();
end-proc;

// Answer program of test_answerPgm: SETQTY's quantity becomes 99
dcl-proc answerProgram;
  dcl-ds err likeds(imoq_err_t);
  imoq_answerPut(2 : '' : '99' : err);
end-proc;

dcl-proc test_answerByName;
  tst_begin('ANSWER names a program or a service program export');
  monitor;
    cmd('IMOQRESET');
    // this program, called without parameters
    cmd('IMOQWHEN OBJ(IMQTSRV) PROC(SETQTY) ANSWER(IMOQCMD_T)');
    tst_eqNum(99 : setQty('A0001' : 5) : 'ANSWER(program)');
    tst_check(gThrown = ' ' : 'ANSWER(program) sent ' + gThrown);

    // any export that takes no parameters will do
    cmd('IMOQWHEN OBJ(IMQTSRV) PROC(SETQTY) +
         ANSWER(IMOQENG imoq_startOrder)');
    tst_eqNum(5 : setQty('A0001' : 5) : 'ANSWER(srvpgm export)');
    tst_check(gThrown = ' ' : 'ANSWER(srvpgm export) sent ' + gThrown);

    // in a named library (IMOQTEST builds this program next to IMOQENG)
    cmd('IMOQWHEN OBJ(IMQTSRV) PROC(SETQTY) +
         ANSWER(' + %trim(tst_pgmLib) + '/IMOQENG IMOQ_STARTORDER)');
    tst_eqNum(5 : setQty('A0001' : 5) : 'ANSWER(lib/srvpgm export)');
    tst_check(gThrown = ' ' : 'ANSWER(lib/srvpgm export) sent '
              + gThrown);

    fails('IMOQWHEN OBJ(IMQTSRV) PROC(SETQTY) ANSWER(IMQTNOPGM)'
          : 'was not found');
    fails('IMOQWHEN OBJ(IMQTSRV) PROC(SETQTY) ANSWER(IMOQENG IMOQ_NOPE)'
          : 'does not export a procedure named IMOQ_NOPE');
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
