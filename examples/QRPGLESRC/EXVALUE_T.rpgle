**free
// ------------------------------------------------------------------
// EXVALUE_T - Parameters passed by value
//
// Features: *VALUE in the IMOQPROC layout, matchers and captures on
// value parameters (varchar too), and why SETPARM can't set them.
// Run it with the driver EXVALUE.
// ------------------------------------------------------------------
ctl-opt main(main);

/copy QRPGLESRC,IMOQ_H

// The dependency this example calls. It is a mock created by the
// driver EXVALUE; no real object exists.

// EXCALC (*SRVPGM), procedure EX_ROUND: round to some decimal places
dcl-pr roundTo packed(9:2) extproc('EX_ROUND');
  amount packed(9:2) value;
  places int(10) value;
end-pr;

// EXCALC (*SRVPGM), procedure EX_INITIALS: initials of a name. A
// varchar over 65535 has a 4-byte length prefix.
dcl-pr initials char(3) extproc('EX_INITIALS');
  name varchar(30) value;
  note varchar(70000:4) value;
end-pr;

/copy QRPGLESRC,EXAMPLE_H

dcl-proc main;
  imoq('IMOQRESET');

  // Matchers work on value parameters like on any other
  imoq('IMOQWHEN OBJ(EXCALC) PROC(EX_ROUND) +
        ARGS((2 *EQ 0)) RETURN(''13.00'')');
  imoq('IMOQWHEN OBJ(EXCALC) PROC(EX_ROUND) +
        ARGS((2 *EQ 1)) RETURN(''12.60'')');

  expect(roundTo(12.55 : 0) = 13.00 : 'no decimal places');
  expect(roundTo(12.55 : 1) = 12.60 : 'one decimal place');

  // So do captures
  expect(imoq_arg('EXCALC' : 'EX_ROUND' : 1 : 1) = '12.55'
         : 'captured amount');
  expect(imoq_arg('EXCALC' : 'EX_ROUND' : IMOQ_LAST : 2) = '1'
         : 'captured places');

  // The caller keeps its own copy of a value parameter, so there is
  // nothing for SETPARM to write back to: IMOQWHEN refuses it
  expect(not imoq_ok('IMOQWHEN OBJ(EXCALC) PROC(EX_ROUND) +
                      SETPARM((1 ''0''))')
         : 'SETPARM on a *VALUE parameter is rejected');
  expect(%scan('passed by value' : imoq_lastError()) > 0
         : 'imoq_lastError() says why');

  // Varchar parameters can be passed by value too
  imoq('IMOQWHEN OBJ(EXCALC) PROC(EX_INITIALS) +
        ARGS((1 *EQ ''Ada Lovelace'')) RETURN(AL)');
  imoq('IMOQWHEN OBJ(EXCALC) PROC(EX_INITIALS) +
        ARGS((2 *LIKE ''%urgent%'')) RETURN(URG)');

  expect(initials('Ada Lovelace' : '') = 'AL' : 'varchar 30 value');
  expect(initials('Bob' : 'an urgent note') = 'URG'
         : 'varchar 70000 value');
  expect(initials('Bob' : '') = ' ' : 'no stub matches');
  expect(imoq_arg('EXCALC' : 'EX_INITIALS' : 2 : 1) = 'Bob'
         : 'captured name');
end-proc;
