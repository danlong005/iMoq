**free
// ------------------------------------------------------------------
// EXORDER_T - Check the order of calls
//
// Features: IMOQORDER, imoq_calledInOrder, imoq_startOrder
// Each order check passes if a matching call came after the call the
// previous one matched. Other calls may come in between. The other
// checks never look at the order: use these only where it matters.
// withCommands() uses the commands, withApi() the RPG API.
// Run it with the driver EXORDER.
// ------------------------------------------------------------------
ctl-opt main(main);

/copy QRPGLESRC,IMOQ_H

// The dependencies this example calls. They are mocks created by
// the driver EXORDER; no real objects exist.

// EXLOCK (*SRVPGM), procedures EX_LOCK and EX_UNLOCK: lock and
// release a customer
dcl-pr lockCust extproc('EX_LOCK');
  custId char(5) const;
end-pr;

dcl-pr unlockCust extproc('EX_UNLOCK');
  custId char(5) const;
end-pr;

// EXCUST (*PGM): look up a customer name
dcl-pr getCustomer extpgm('EXCUST');
  custId char(5) const;
  name char(30);
  found ind;
end-pr;

/copy QRPGLESRC,EXAMPLE_H

dcl-proc main;
  withCommands();
  withApi();
end-proc;

// ------------------------------------------------------------------
// The command form
// ------------------------------------------------------------------
dcl-proc withCommands;
  dcl-s name char(30);
  dcl-s found ind;

  imoq('IMOQRESET');

  lockCust('C0042');
  getCustomer('C0042' : name : found);
  unlockCust('C0042');

  // Lock, read, unlock: each step came after the one before
  expect(imoq_ok('IMOQORDER OBJ(EXLOCK) PROC(EX_LOCK) +
                  ARGS((1 *EQ C0042))') : imoq_lastError());
  expect(imoq_ok('IMOQORDER OBJ(EXCUST) ARGS((1 *EQ C0042))')
         : imoq_lastError());
  expect(imoq_ok('IMOQORDER OBJ(EXLOCK) PROC(EX_UNLOCK)')
         : imoq_lastError());

  // AFTER(*START) begins a new sequence. Steps may skip calls: lock
  // then unlock passes although the read came in between.
  expect(imoq_ok('IMOQORDER OBJ(EXLOCK) PROC(EX_LOCK) AFTER(*START)')
         : imoq_lastError());
  expect(imoq_ok('IMOQORDER OBJ(EXLOCK) PROC(EX_UNLOCK)')
         : imoq_lastError());

  // Nothing was locked after the unlock
  expect(not imoq_ok('IMOQORDER OBJ(EXLOCK) PROC(EX_LOCK)')
         : 'no lock came after the unlock');
  expect(%scan('after EXLOCK.EX_UNLOCK' : imoq_lastError()) > 0
         : 'imoq_lastError() says where the sequence stood');
end-proc;

// ------------------------------------------------------------------
// The RPG API: order checks on verification handles
// ------------------------------------------------------------------
dcl-proc withApi;
  dcl-s name char(30);
  dcl-s found ind;
  dcl-s v int(10);

  imoq_reset();

  // The bug to catch: the customer is read after it was unlocked
  lockCust('C0042');
  unlockCust('C0042');
  getCustomer('C0042' : name : found);

  v = imoq_verify('EXLOCK' : 'EX_LOCK');
  expect(imoq_calledInOrder(v) : imoq_lastError());
  v = imoq_verify('EXCUST');
  imoq_with(v : 1 : IMOQ_EQ : 'C0042');
  expect(imoq_calledInOrder(v) : imoq_lastError());
  v = imoq_verify('EXLOCK' : 'EX_UNLOCK');
  expect(not imoq_calledInOrder(v) : 'API: the unlock came too early');

  // The other checks don't look at the order
  expect(imoq_calledOnce(v) : imoq_lastError());

  // imoq_startOrder() begins a new sequence
  imoq_startOrder();
  expect(imoq_calledInOrder(v) : imoq_lastError());
end-proc;
