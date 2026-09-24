**free
// ------------------------------------------------------------------
// EXTYPES_T - Varchar, zoned, float and pointer parameters
//
// Features: SETPARM, matchers and captures on (*VARCHAR n),
// (*ZONED n d), (*FLOAT 8) and (*PTR) parameters.
// Values are text: numbers as '1234.50', pointers as *NULL or
// *NOTNULL (a stub can only set a pointer to *NULL).
// Run it with the driver EXTYPES.
// ------------------------------------------------------------------
ctl-opt main(main);

/copy QRPGLESRC,IMOQ_H

// The dependency this example calls. It is a mock created by the
// driver EXTYPES; no real object exists.

// EXPROF (*PGM): read a customer profile
dcl-pr getProfile extpgm('EXPROF');
  name varchar(30);
  balance zoned(9:2);
  rate float(8);
  note pointer;
end-pr;

/copy QRPGLESRC,EXAMPLE_H

dcl-proc main;
  dcl-s name varchar(30);
  dcl-s balance zoned(9:2);
  dcl-s rate float(8);
  dcl-s note pointer;
  dcl-s memo char(10) inz('memo');

  imoq('IMOQRESET');

  // Match a varchar by its value; set zoned, float and pointer
  imoq('IMOQWHEN OBJ(EXPROF) ARGS((1 *EQ ''Ada'')) +
        SETPARM((2 ''1234.50'') (3 ''0.25'') (4 ''*NULL''))');
  // Setting a varchar sets its length too
  imoq('IMOQWHEN OBJ(EXPROF) ARGS((1 *EQ ''Bob'')) +
        SETPARM((1 ''Robert''))');

  name = 'Ada';
  note = %addr(memo);
  getProfile(name : balance : rate : note);
  expect(balance = 1234.50 : 'zoned set');
  expect(rate = 0.25 : 'float set');
  expect(note = *null : 'pointer set to *NULL');

  name = 'Bob';
  getProfile(name : balance : rate : note);
  expect(name = 'Robert' and %len(name) = 6 : 'varchar set with length');

  // Matchers compare zoned and float as numbers, pointers as
  // *NULL / *NOTNULL
  imoq('IMOQRESET');
  imoq('IMOQWHEN OBJ(EXPROF) +
        ARGS((2 *GT 1000) (3 *LT 1) (4 *EQ ''*NOTNULL'')) +
        SETPARM((1 ''BIG SPENDER''))');

  name = 'Ada';
  balance = 5000;
  rate = 0.5;
  note = %addr(memo);
  getProfile(name : balance : rate : note);
  expect(name = 'BIG SPENDER' : 'all three matchers match');

  name = 'Ada';
  balance = 10;
  getProfile(name : balance : rate : note);
  expect(name = 'Ada' : 'balance 10 is not over 1000');

  // Captured values are text
  expect(imoq_arg('EXPROF' : IMOQ_PGM : IMOQ_LAST : 1) = 'Ada'
         : 'varchar captured');
  expect(imoq_arg('EXPROF' : IMOQ_PGM : IMOQ_LAST : 2) = '10.00'
         : 'zoned captured');
  expect(%float(imoq_arg('EXPROF' : IMOQ_PGM : IMOQ_LAST : 3)) = 0.5
         : 'float captured (compare it as a float)');
  expect(imoq_arg('EXPROF' : IMOQ_PGM : IMOQ_LAST : 4) = '*NOTNULL'
         : 'pointer captured as *NOTNULL');
end-proc;
