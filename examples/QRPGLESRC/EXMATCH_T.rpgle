**free
// ------------------------------------------------------------------
// EXMATCH_T - Answer differently depending on the arguments
//
// Features: IMOQWHEN ARGS((parm matcher value))
// Matchers: *EQ *NE *GT *GE *LT *LE *LIKE *BLANK *ANY *IN
//           *BETWEEN *OMIT *NOTPASSED (see EXOMIT)
// Run it with the driver EXMATCH.
// ------------------------------------------------------------------
ctl-opt main(main);

/copy QRPGLESRC,IMOQ_H

// The dependencies this example calls. They are mocks created by
// the driver EXMATCH; no real objects exist.

// EXPRICE (*SRVPGM), procedure EX_PRICE: price of an item
dcl-pr getPrice packed(7:2) extproc('EX_PRICE');
  item char(5) const;
end-pr;

// EXPRICE (*SRVPGM), procedure EX_DISCOUNT: discount for an amount
dcl-pr getDiscount packed(7:2) extproc('EX_DISCOUNT');
  amount packed(7:2) const;
  code char(10) const options(*nopass:*omit);
end-pr;

/copy QRPGLESRC,EXAMPLE_H

dcl-proc main;
  imoq('IMOQRESET');

  // Parameter 1 equal to A0001
  imoq('IMOQWHEN OBJ(EXPRICE) PROC(EX_PRICE) +
        ARGS((1 *EQ A0001)) RETURN(''1.00'')');
  // Parameter 1 starts with B (% = any text, _ = one character)
  imoq('IMOQWHEN OBJ(EXPRICE) PROC(EX_PRICE) +
        ARGS((1 *LIKE ''B%'')) RETURN(''2.00'')');
  // Parameter 1 is blank
  imoq('IMOQWHEN OBJ(EXPRICE) PROC(EX_PRICE) +
        ARGS((1 *BLANK)) RETURN(''0.50'')');
  // Numbers compare as numbers: amounts over 100 get 10.00 off
  imoq('IMOQWHEN OBJ(EXPRICE) PROC(EX_DISCOUNT) +
        ARGS((1 *GT 100)) RETURN(''10.00'')');
  // Parameter 1 is one of a list, separated by commas
  imoq('IMOQWHEN OBJ(EXPRICE) PROC(EX_PRICE) +
        ARGS((1 *IN ''C0003,D0004'')) RETURN(''3.00'')');
  // Parameter 1 is in a range: low,high, both ends included
  imoq('IMOQWHEN OBJ(EXPRICE) PROC(EX_DISCOUNT) +
        ARGS((1 *BETWEEN ''60,70'')) RETURN(''5.00'')');

  expect(getPrice('A0001') = 1.00 : '*EQ A0001');
  expect(getPrice('B7777') = 2.00 : '*LIKE B%');
  expect(getPrice(' ') = 0.50 : '*BLANK');
  expect(getDiscount(150.00) = 10.00 : '*GT 100');
  expect(getPrice('D0004') = 3.00 : '*IN C0003,D0004');
  expect(getDiscount(70.00) = 5.00 : '*BETWEEN 60,70');

  // No stub matches: a loose mock returns zero
  expect(getPrice('Z9999') = 0 : 'no match returns zero');
  expect(getDiscount(50.00) = 0 : '50 is not greater than 100');
end-proc;
