**free
// ------------------------------------------------------------------
// EXANSWER_T - Answers built from the arguments
//
// Features: IMOQWHEN COPYARG (copy an argument into an output
// parameter, a subfield or the return value) and IMOQWHEN ANSWER
// (your own procedure computes the answer), with the RPG API
// equivalents imoq_copyArg and imoq_answers.
// withCommands() uses the commands, withApi() the RPG API.
// Run it with the driver EXANSWER.
// ------------------------------------------------------------------
ctl-opt main(main);

/copy QRPGLESRC,IMOQ_H

dcl-ds cust_t qualified template;
  id char(5);                       // positions 1-5
  name char(30);                    // 6-35
end-ds;

// The dependencies this example calls. They are mocks created by
// the driver EXANSWER; no real objects exist.

// EXCONV (*SRVPGM), procedure EX_CONVERT: amount in dollars
dcl-pr convert packed(9:2) extproc('EX_CONVERT');
  amount packed(9:2) const;
  currency char(3) const;
end-pr;

// EXCONV (*SRVPGM), procedure EX_LOOKUP: find a customer
dcl-pr lookup extproc('EX_LOOKUP');
  custId char(5) const;
  cust likeds(cust_t);
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
  dcl-ds cust likeds(cust_t);

  imoq('IMOQRESET');

  // Dollars are already dollars: return the amount it was given.
  // COPYARG((from to)); to 0 is the return value.
  imoq('IMOQWHEN OBJ(EXCONV) PROC(EX_CONVERT) +
        ARGS((2 *EQ USD)) COPYARG((1 0))');
  // Euros need a calculation: procedure EURANSWER of service program
  // EXANSSRV computes the answer (see EXANSSRV)
  imoq('IMOQWHEN OBJ(EXCONV) PROC(EX_CONVERT) +
        ARGS((2 *EQ EUR)) ANSWER(EXANSSRV EURANSWER)');
  // Copy into a subfield: the customer number goes into field ID of
  // parameter 2, next to a fixed NAME. COPYARG((from to fromField
  // toField)); ' ' means the whole parameter.
  imoq('IMOQWHEN OBJ(EXCONV) PROC(EX_LOOKUP) +
        COPYARG((1 2 '' '' ID)) SETPARM((2 ''ACME CORP'' NAME))');

  expect(convert(12.50 : 'USD') = 12.50 : 'USD: the amount itself');
  expect(convert(99.99 : 'USD') = 99.99 : 'every call copies its own');
  expect(convert(100.00 : 'EUR') = 110.00 : 'EUR: computed by EURANSWER');
  lookup('C0042' : cust);
  expect(cust.id = 'C0042' : 'ID copied from parameter 1');
  expect(cust.name = 'ACME CORP' : 'NAME from SETPARM');
end-proc;

// ------------------------------------------------------------------
// The RPG API: imoq_copyArg(h : from : to : fromField : toField)
// and imoq_answers(h : %paddr(procedure))
// ------------------------------------------------------------------
dcl-proc withApi;
  dcl-ds cust likeds(cust_t);
  dcl-s h int(10);

  imoq_reset();

  h = imoq_when('EXCONV' : 'EX_CONVERT');
  imoq_with(h : 2 : IMOQ_EQ : 'USD');
  imoq_copyArg(h : 1 : 0);

  // An answer procedure in this program (see eurAnswer below)
  h = imoq_when('EXCONV' : 'EX_CONVERT');
  imoq_with(h : 2 : IMOQ_EQ : 'EUR');
  imoq_answers(h : %paddr(eurAnswer));

  // Answers can set outputs too: the name is built from the number
  h = imoq_when('EXCONV' : 'EX_LOOKUP');
  imoq_copyArg(h : 1 : 2 : '' : 'ID');
  imoq_answers(h : %paddr(nameAnswer));

  expect(convert(12.50 : 'USD') = 12.50 : 'API: USD');
  expect(convert(200.00 : 'EUR') = 220.00 : 'API: EUR');
  lookup('C0042' : cust);
  expect(cust.id = 'C0042' : 'API: ID copied');
  expect(cust.name = 'Customer C0042' : 'API: NAME from the answer');

  // The calls are recorded as they arrived, as always
  expect(imoq_argNum('EXCONV' : 'EX_CONVERT' : IMOQ_LAST : 1) = 200
         : 'API: argument capture');
end-proc;

// ------------------------------------------------------------------
// Answer procedures take no parameters. imoq_answerArg... read the
// call being answered (as it arrived); imoq_answerReturns and
// imoq_answerSetParm set its return value and output parameters.
// They run after the stub's RETURN, SETPARM and COPYARG.
// ------------------------------------------------------------------

// EX_CONVERT(amount : currency): euros at 1.10 dollars each
dcl-proc eurAnswer;
  imoq_answerReturns(imoq_answerArgNum(1) * 1.10);
end-proc;

// EX_LOOKUP(custId : cust): the name is 'Customer ' and the number
dcl-proc nameAnswer;
  imoq_answerSetParm(2 : 'Customer ' + imoq_answerArg(1) : 'NAME');
end-proc;
