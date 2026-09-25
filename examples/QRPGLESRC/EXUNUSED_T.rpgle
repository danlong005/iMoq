**free
// ------------------------------------------------------------------
// EXUNUSED_T - Find stubs that no call used
//
// Features: IMOQUNUSED, imoq_noUnusedStubs
// A stub whose matcher is wrong doesn't fail on its own: the call
// just gets the default answer. IMOQUNUSED fails while any stub has
// answered no call, and names it.
// withCommands() uses the commands, withApi() the RPG API.
// Run it with the driver EXUNUSED.
// ------------------------------------------------------------------
ctl-opt main(main);

/copy QRPGLESRC,IMOQ_H

// The dependencies this example calls. They are mocks created by
// the driver EXUNUSED; no real objects exist.

// EXPRICE (*SRVPGM), procedure EX_PRICE: price of an item
dcl-pr getPrice packed(7:2) extproc('EX_PRICE');
  item char(5) const;
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

  imoq('IMOQWHEN OBJ(EXPRICE) PROC(EX_PRICE) ARGS((1 *EQ A0001)) +
        RETURN(''9.99'')');
  // A typo: the test calls with B0002, so this stub never answers
  imoq('IMOQWHEN OBJ(EXPRICE) PROC(EX_PRICE) ARGS((1 *EQ B002)) +
        RETURN(''5.00'')');
  imoq('IMOQWHEN OBJ(EXCUST) SETPARM((2 ''Acme Corp''))');

  expect(getPrice('A0001') = 9.99 : 'the A0001 stub answered');
  expect(getPrice('B0002') = 0 : 'no stub matched B0002');
  getCustomer('C0042' : name : found);

  expect(not imoq_ok('IMOQUNUSED') : 'the B002 stub is unused');
  expect(%scan('''B002''' : imoq_lastError()) > 0
         : 'imoq_lastError() shows the unused stub''s matchers');
  expect(imoq_ok('IMOQUNUSED OBJ(EXCUST)') : imoq_lastError());

  // Fix the stub: it answers the next call, so it's no longer unused
  imoq('IMOQRESET OBJ(EXPRICE) SCOPE(*STUBS)');
  imoq('IMOQWHEN OBJ(EXPRICE) PROC(EX_PRICE) ARGS((1 *EQ B0002)) +
        RETURN(''5.00'')');
  expect(getPrice('B0002') = 5.00 : 'the fixed stub answered');
  expect(imoq_ok('IMOQUNUSED') : imoq_lastError());
end-proc;

// ------------------------------------------------------------------
// The RPG API
// ------------------------------------------------------------------
dcl-proc withApi;
  dcl-s h int(10);

  imoq_reset();

  h = imoq_when('EXPRICE' : 'EX_PRICE');
  imoq_with(h : 1 : IMOQ_EQ : 'A0001');
  imoq_returns(h : 9.99);
  h = imoq_when('EXPRICE' : 'EX_PRICE');
  imoq_with(h : 1 : IMOQ_EQ : 'B002');           // the same typo
  imoq_returns(h : 5.00);

  getPrice('A0001');
  expect(not imoq_noUnusedStubs('EXPRICE')
         : 'API: the B002 stub is unused');
  expect(%scan('Unused stubs (1)' : imoq_lastError()) > 0
         : 'API: imoq_lastError() counts the unused stubs');

  // One answered call is enough, even when imoq_times allows more
  imoq_reset('EXPRICE' : IMOQ_STUBS);
  h = imoq_when('EXPRICE' : 'EX_PRICE');
  imoq_with(h : 1 : IMOQ_EQ : 'B0002');
  imoq_returns(h : 5.00);
  imoq_times(h : 3);
  getPrice('B0002');
  expect(imoq_noUnusedStubs() : imoq_lastError());
end-proc;
