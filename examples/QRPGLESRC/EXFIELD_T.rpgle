**free
// ------------------------------------------------------------------
// EXFIELD_T - Data structures, arrays and data structure returns
//
// Features: subfields declared with IMOQFIELD, used in ARGS,
// SETPARM, IMOQVERIFY and imoq_arg; array elements (AMT(12)); and a
// data structure return value built field by field (parameter 0).
// withCommands() uses the commands, withApi() the RPG API.
// Run it with the driver EXFIELD.
// ------------------------------------------------------------------
ctl-opt main(main);

/copy QRPGLESRC,IMOQ_H

dcl-ds order_t qualified template;
  item char(5);                     // positions 1-5
  qty packed(7:0);                  // 6-9
  price zoned(9:2);                 // 10-18
  shipped date(*iso);               // 19-28
end-ds;

dcl-ds result_t qualified template;
  status char(2);                   // 1-2
  total packed(11:2);               // 3-8
  lineNo int(10);                   // 9-12
end-ds;

// The dependency this example calls. It is a mock created by the
// driver EXFIELD; no real object exists.

// EXORDER (*SRVPGM), procedure EX_ADDORDER: add an order line
dcl-pr addOrder likeds(result_t) extproc('EX_ADDORDER');
  order likeds(order_t) const;
  monthly packed(9:2) dim(12) const;
end-pr;

// EXORDER (*SRVPGM), procedure EX_PRICEIT: fill in the price
dcl-pr priceIt extproc('EX_PRICEIT');
  order likeds(order_t);
end-pr;

/copy QRPGLESRC,EXAMPLE_H

dcl-proc main;
  withCommands();
  withApi();
end-proc;

// ------------------------------------------------------------------
// The command form: the field is the last element of an ARGS or
// SETPARM entry, and FIELD() on IMOQGETARG
// ------------------------------------------------------------------
dcl-proc withCommands;
  dcl-ds order likeds(order_t) inz(*likeds);
  dcl-ds result likeds(result_t);
  dcl-s monthly packed(9:2) dim(12);

  imoq('IMOQRESET');

  // Match on subfields; build the returned data structure field by
  // field (parameter 0 is the return value)
  imoq('IMOQWHEN OBJ(EXORDER) PROC(EX_ADDORDER) +
        ARGS((1 *EQ A0001 ITEM) (1 *GT 10 QTY)) +
        SETPARM((0 OK STATUS) (0 ''99.50'' TOTAL) (0 7 LINENO))');
  // Match on an array element (quoted: it has parentheses); fields
  // left unset start blank or zero
  imoq('IMOQWHEN OBJ(EXORDER) PROC(EX_ADDORDER) +
        ARGS((2 *GT 1000 ''AMT(12)'')) SETPARM((0 HI STATUS))');

  order.item = 'A0001';
  order.qty = 12;
  order.shipped = d'2026-10-01';
  result = addOrder(order : monthly);
  expect(result.status = 'OK' and result.total = 99.50
         and result.lineNo = 7 : 'return value built from its fields');

  monthly(12) = 5000;
  result = addOrder(order : monthly);
  expect(result.status = 'HI' and result.total = 0 and result.lineNo = 0
         : 'array element matched; other fields zero');

  // Set one subfield of an output data structure
  imoq('IMOQWHEN OBJ(EXORDER) PROC(EX_PRICEIT) +
        SETPARM((1 ''12.34'' PRICE))');
  priceIt(order);
  expect(order.price = 12.34 and order.item = 'A0001' and order.qty = 12
         : 'only PRICE changed');

  // Verify and capture by subfield
  expect(imoq_ok('IMOQVERIFY OBJ(EXORDER) PROC(EX_ADDORDER) +
                  ARGS((1 *EQ A0001 ITEM)) TIMES(*EXACTLY 2)')
         : imoq_lastError());
  expect(imoq_arg('EXORDER' : 'EX_ADDORDER' : 1 : 1 : 'QTY') = '12'
         : 'captured QTY');
  expect(imoq_arg('EXORDER' : 'EX_ADDORDER' : 1 : 1 : 'SHIPPED')
         = '2026-10-01' : 'captured SHIPPED');
  expect(imoq_arg('EXORDER' : 'EX_ADDORDER' : IMOQ_LAST : 2 : 'AMT(12)')
         = '5000.00' : 'captured AMT(12)');

  // A field that wasn't declared is rejected
  expect(not imoq_ok('IMOQWHEN OBJ(EXORDER) PROC(EX_ADDORDER) +
                      ARGS((1 *EQ X NOPE))')
         : 'undeclared field rejected');
  expect(%scan('not declared' : imoq_lastError()) > 0
         : 'imoq_lastError() says why');
end-proc;

// ------------------------------------------------------------------
// The RPG API: the field is the last argument
// ------------------------------------------------------------------
dcl-proc withApi;
  dcl-ds order likeds(order_t) inz(*likeds);
  dcl-ds result likeds(result_t);
  dcl-s monthly packed(9:2) dim(12);
  dcl-s h int(10);
  dcl-s v int(10);

  imoq_reset();

  h = imoq_when('EXORDER' : 'EX_ADDORDER');
  imoq_with(h : 1 : IMOQ_EQ : 'B0002' : 'ITEM');
  imoq_with(h : 1 : IMOQ_GE : d'2026-01-01' : 'SHIPPED');
  imoq_with(h : 2 : IMOQ_EQ : 0 : 'AMT(1)');
  imoq_setParm(h : 0 : 'OK' : 'STATUS');
  imoq_setParm(h : 0 : 12.50 : 'TOTAL');

  h = imoq_when('EXORDER' : 'EX_PRICEIT');
  imoq_setParm(h : 1 : 3.75 : 'PRICE');
  imoq_setParm(h : 1 : d'2026-12-24' : 'SHIPPED');

  order.item = 'B0002';
  order.qty = 3;
  order.shipped = d'2026-11-05';
  result = addOrder(order : monthly);
  expect(result.status = 'OK' and result.total = 12.50
         : 'API: return value built from its fields');

  priceIt(order);
  expect(order.price = 3.75 and order.shipped = d'2026-12-24'
         : 'API: output subfields set');

  v = imoq_verify('EXORDER' : 'EX_ADDORDER');
  imoq_with(v : 1 : IMOQ_EQ : 3 : 'QTY');
  expect(imoq_calledOnce(v) : imoq_lastError());

  expect(imoq_argNum('EXORDER' : 'EX_ADDORDER' : 1 : 1 : 'QTY') = 3
         : 'API: typed capture of a subfield');
  expect(imoq_argDate('EXORDER' : 'EX_ADDORDER' : 1 : 1 : 'SHIPPED')
         = d'2026-11-05' : 'API: typed capture of a date subfield');
  expect(imoq_argNum('EXORDER' : 'EX_ADDORDER' : 1 : 2 : 'AMT(12)') = 0
         : 'API: typed capture of an array element');
end-proc;
