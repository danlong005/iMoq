**free
// ------------------------------------------------------------------
// EXAPI_T - Everything the RPG API can do, one topic per procedure
//
//   stubbing     imoq_when, imoq_returns (series), imoq_setParm,
//                imoq_times, IMOQ_ALWAYS
//   matchers     all thirteen IMOQ_ matchers with imoq_with
//   typedValues  numbers, dates, times and timestamps in imoq_with,
//                imoq_returns and imoq_setParm
//   throwing     imoq_throws with IMOQ_MOCK and with a real message
//   verifying    imoq_verify, imoq_calledOnce/Times/AtLeast/AtMost,
//                imoq_neverCalled, imoq_matchCount, imoq_noMoreCalls
//   capturing    imoq_arg, imoq_argNum/Date/Time/Timestamp/Ind,
//                imoq_argPassed, imoq_count
//   resetting    imoq_reset scopes, and a stale handle (IMQ0300)
//
// Values are RPG values: no command strings, no doubled quotes.
// Needs IBM i 7.4 TR5 or later (OVERLOAD).
// Run it with the driver EXAPI.
// ------------------------------------------------------------------
ctl-opt main(main);

/copy QRPGLESRC,IMOQ_H

// The dependencies this example calls. They are mocks created by
// the driver EXAPI; no real objects exist.

// EXCUST (*PGM): look up a customer name
dcl-pr getCustomer extpgm('EXCUST');
  custId char(5) const;
  name char(30);
  found ind;
end-pr;

// EXPRICE (*SRVPGM), procedure EX_PRICE: price of an item
dcl-pr getPrice packed(7:2) extproc('EX_PRICE');
  item char(5) const;
end-pr;

// EXPRICE (*SRVPGM), procedure EX_DISCOUNT: discount for an amount
dcl-pr getDiscount packed(7:2) extproc('EX_DISCOUNT');
  amount packed(7:2) const;
  code char(10) const options(*nopass:*omit);
end-pr;

// EXPRICE (*SRVPGM), procedure EX_SCHEDULE: book a delivery slot.
// Fills in the quantity and due date; returns the delivery time.
dcl-pr schedule timestamp extproc('EX_SCHEDULE');
  item char(5) const;
  atTime time;
  stamp timestamp;
  rush ind;
  qty packed(7:2);
  due date;
end-pr;

// EXPRICE (*SRVPGM), procedure EX_CUTOFF: last order time of the day
dcl-pr cutoff time extproc('EX_CUTOFF');
  item char(5) const;
end-pr;

// Message ID of the last error caught with MONITOR
dcl-ds psds psds qualified;
  excId char(7) pos(40);
end-ds;

/copy QRPGLESRC,EXAMPLE_H

dcl-proc main;
  stubbing();
  matchers();
  typedValues();
  throwing();
  verifying();
  capturing();
  resetting();
end-proc;

// ------------------------------------------------------------------
// Stubbing: a handle from imoq_when, then one call per piece.
// The stub answers as soon as imoq_when returns.
// ------------------------------------------------------------------
dcl-proc stubbing;
  dcl-s h int(10);
  dcl-s name char(30);
  dcl-s found ind;

  imoq_reset();

  // A series of return values: one per call, the last one repeats
  h = imoq_when('EXPRICE' : 'EX_PRICE');
  imoq_with(h : 1 : IMOQ_EQ : 'A0001');
  imoq_returns(h : 5.00);
  imoq_returns(h : 4.50);

  expect(getPrice('A0001') = 5.00 : 'first call: first value');
  expect(getPrice('A0001') = 4.50 : 'second call: second value');
  expect(getPrice('A0001') = 4.50 : 'later calls: the last value repeats');

  // A program mock answers by filling output parameters. The default
  // answer comes first; IMOQ_ALWAYS is the default for imoq_times.
  h = imoq_when('EXCUST');
  imoq_setParm(h : 2 : 'WALK-IN CUSTOMER');
  imoq_setParm(h : 3 : '1');
  imoq_times(h : IMOQ_ALWAYS);

  // The newest matching stub wins; this one answers one call only
  h = imoq_when('EXCUST');
  imoq_with(h : 1 : IMOQ_EQ : 'C0042');
  imoq_setParm(h : 2 : 'ACME CORP');    // blanks need no extra quotes
  imoq_setParm(h : 3 : '1');
  imoq_times(h : 1);

  getCustomer('C0042' : name : found);
  expect(found and name = 'ACME CORP' : 'newest stub answers first');
  getCustomer('C0042' : name : found);
  expect(name = 'WALK-IN CUSTOMER'
         : 'after imoq_times(1) is used up, the older stub answers');
end-proc;

// ------------------------------------------------------------------
// Matchers: imoq_with(h : parmNo : matcher : value). All matchers
// on one stub must match. Values without a value: IMOQ_ANY,
// IMOQ_BLANK, IMOQ_OMIT and IMOQ_NOTPASSED.
// ------------------------------------------------------------------
dcl-proc matchers;
  dcl-s h int(10);

  imoq_reset();

  // Text: IMOQ_NE as the default, then the special cases (newest
  // matching stub wins)
  h = imoq_when('EXPRICE' : 'EX_PRICE');
  imoq_with(h : 1 : IMOQ_NE : 'Z9999');
  imoq_returns(h : 9);
  h = imoq_when('EXPRICE' : 'EX_PRICE');
  imoq_with(h : 1 : IMOQ_EQ : 'A0001');
  imoq_returns(h : 1);
  h = imoq_when('EXPRICE' : 'EX_PRICE');
  imoq_with(h : 1 : IMOQ_LIKE : 'B_0%');   // % any text, _ one char
  imoq_returns(h : 2);
  h = imoq_when('EXPRICE' : 'EX_PRICE');
  imoq_with(h : 1 : IMOQ_BLANK);
  imoq_returns(h : 3);

  expect(getPrice('A0001') = 1 : 'IMOQ_EQ');
  expect(getPrice('BX001') = 2 : 'IMOQ_LIKE');
  expect(getPrice(' ') = 3 : 'IMOQ_BLANK');
  expect(getPrice('C0003') = 9 : 'IMOQ_NE');
  expect(getPrice('Z9999') = 0 : 'no stub matches Z9999');

  // Numbers compare as numbers
  imoq_reset();
  h = imoq_when('EXPRICE' : 'EX_DISCOUNT');
  imoq_with(h : 1 : IMOQ_GT : 100);
  imoq_returns(h : 4);
  h = imoq_when('EXPRICE' : 'EX_DISCOUNT');
  imoq_with(h : 1 : IMOQ_LT : 10);
  imoq_returns(h : 1);
  h = imoq_when('EXPRICE' : 'EX_DISCOUNT');
  imoq_with(h : 1 : IMOQ_GE : 50);         // two matchers: a range
  imoq_with(h : 1 : IMOQ_LE : 60);
  imoq_returns(h : 2);

  expect(getDiscount(150) = 4 : 'IMOQ_GT 100');
  expect(getDiscount(5) = 1 : 'IMOQ_LT 10');
  expect(getDiscount(50) = 2 : 'IMOQ_GE 50 and IMOQ_LE 60: 50');
  expect(getDiscount(60) = 2 : 'IMOQ_GE 50 and IMOQ_LE 60: 60');
  expect(getDiscount(70) = 0 : '70 matches no stub');

  // Lists and ranges: the values are text, separated by commas
  imoq_reset();
  h = imoq_when('EXPRICE' : 'EX_PRICE');
  imoq_with(h : 1 : IMOQ_IN : 'A0001,B0002,C0003');
  imoq_returns(h : 5);
  h = imoq_when('EXPRICE' : 'EX_DISCOUNT');
  imoq_with(h : 1 : IMOQ_BETWEEN : '50,60');  // both ends included
  imoq_returns(h : 2);

  expect(getPrice('B0002') = 5 : 'IMOQ_IN');
  expect(getPrice('D0004') = 0 : 'D0004 is not in the list');
  expect(getDiscount(60) = 2 : 'IMOQ_BETWEEN 50,60: 60');
  expect(getDiscount(61) = 0 : '61 is outside the range');

  // Optional parameters: passed, omitted or not passed at all
  imoq_reset();
  h = imoq_when('EXPRICE' : 'EX_DISCOUNT');
  imoq_with(h : 2 : IMOQ_ANY);
  imoq_returns(h : 1);
  h = imoq_when('EXPRICE' : 'EX_DISCOUNT');
  imoq_with(h : 2 : IMOQ_OMIT);
  imoq_returns(h : 2);
  h = imoq_when('EXPRICE' : 'EX_DISCOUNT');
  imoq_with(h : 2 : IMOQ_NOTPASSED);
  imoq_returns(h : 3);

  expect(getDiscount(10 : 'SPRING') = 1 : 'IMOQ_ANY');
  expect(getDiscount(10 : *omit) = 2 : 'IMOQ_OMIT');
  expect(getDiscount(10) = 3 : 'IMOQ_NOTPASSED');
end-proc;

// ------------------------------------------------------------------
// Typed values: imoq_with, imoq_returns and imoq_setParm take text,
// numbers, dates, times and timestamps
// ------------------------------------------------------------------
dcl-proc typedValues;
  dcl-s h int(10);
  dcl-s at time inz(t'14.30.00');
  dcl-s stamp timestamp inz(z'2026-09-24-14.30.00.000000');
  dcl-s rush ind inz(*on);
  dcl-s qty packed(7:2);
  dcl-s due date;
  dcl-s deliver timestamp;

  imoq_reset();

  // Default answer: a timestamp, nothing else set
  h = imoq_when('EXPRICE' : 'EX_SCHEDULE');
  imoq_returns(h : z'2026-12-31-00.00.00.000000');

  h = imoq_when('EXPRICE' : 'EX_SCHEDULE');
  imoq_with(h : 2 : IMOQ_GE : t'12.00.00');                    // time
  imoq_with(h : 3 : IMOQ_LT : z'2027-01-01-00.00.00.000000');  // timestamp
  imoq_setParm(h : 5 : 12.5);                                  // number
  imoq_setParm(h : 6 : d'2026-10-15');                         // date
  imoq_returns(h : z'2026-10-15-08.00.00.000000');             // timestamp

  h = imoq_when('EXPRICE' : 'EX_CUTOFF');
  imoq_returns(h : t'17.30.00');                               // time

  deliver = schedule('A0001' : at : stamp : rush : qty : due);
  expect(deliver = z'2026-10-15-08.00.00.000000' : 'timestamp returned');
  expect(qty = 12.5 : 'number set');
  expect(due = d'2026-10-15' : 'date set');
  expect(cutoff('A0001') = t'17.30.00' : 'time returned');

  // Before noon the time matcher doesn't match: the default answers
  at = t'09.00.00';
  qty = 0;
  deliver = schedule('A0001' : at : stamp : rush : qty : due);
  expect(qty = 0 and deliver = z'2026-12-31-00.00.00.000000'
         : 'IMOQ_GE on a time');
end-proc;

// ------------------------------------------------------------------
// Throwing: the caller gets an ordinary escape message
// ------------------------------------------------------------------
dcl-proc throwing;
  dcl-s h int(10);
  dcl-s name char(30);
  dcl-s found ind;
  dcl-s failed ind;

  imoq_reset();

  // IMOQ_MOCK sends IMQ0101 with your text
  h = imoq_when('EXPRICE' : 'EX_PRICE');
  imoq_with(h : 1 : IMOQ_EQ : 'X0000');
  imoq_throws(h : IMOQ_MOCK : 'Price list is locked');

  monitor;
    getPrice('X0000');
  on-error;
    failed = *on;
  endmon;
  expect(failed and psds.excId = 'IMQ0101' : 'IMOQ_MOCK sends IMQ0101');

  // Any message: ID, message data, message file (library *LIBL)
  h = imoq_when('EXCUST');
  imoq_throws(h : 'CPF9898' : 'Customer file is locked' : 'QCPFMSG');

  failed = *off;
  monitor;
    getCustomer('C0001' : name : found);
  on-error;
    failed = *on;
  endmon;
  expect(failed and psds.excId = 'CPF9898' : 'CPF9898 from QCPFMSG');
end-proc;

// ------------------------------------------------------------------
// Verifying: a handle from imoq_verify, optional matchers, then a
// check. Checks return *off and explain why in imoq_lastError().
// ------------------------------------------------------------------
dcl-proc verifying;
  dcl-s v int(10);
  dcl-s name char(30);
  dcl-s found ind;

  imoq_reset();
  getPrice('A0001');
  getPrice('A0001');
  getPrice('B0002');
  getCustomer('C0042' : name : found);

  v = imoq_verify('EXPRICE' : 'EX_PRICE');     // no matchers: any call
  expect(imoq_matchCount(v) = 3 : 'imoq_matchCount counts only');
  expect(imoq_calledAtLeast(v : 2) : imoq_lastError());
  expect(imoq_calledAtMost(v : 5) : imoq_lastError());

  v = imoq_verify('EXPRICE' : 'EX_PRICE');
  imoq_with(v : 1 : IMOQ_EQ : 'A0001');
  expect(imoq_calledTimes(v : 2) : imoq_lastError());

  v = imoq_verify('EXPRICE' : 'EX_PRICE');
  imoq_with(v : 1 : IMOQ_EQ : 'B0002');
  expect(imoq_calledOnce(v) : imoq_lastError());

  v = imoq_verify('EXPRICE' : 'EX_DISCOUNT');
  expect(imoq_neverCalled(v) : imoq_lastError());

  // Successful checks mark calls verified. EXPRICE is done; the
  // EXCUST call hasn't been verified yet.
  expect(imoq_noMoreCalls('EXPRICE') : imoq_lastError());
  expect(not imoq_noMoreCalls() : 'the EXCUST call is unverified');
  expect(%scan('EXCUST' : imoq_lastError()) > 0
         : 'imoq_lastError() lists the unverified call');

  v = imoq_verify('EXCUST');                    // program mock: no proc
  imoq_with(v : 1 : IMOQ_EQ : 'C0042');
  expect(imoq_calledOnce(v) : imoq_lastError());
  expect(imoq_noMoreCalls() : imoq_lastError());

  // A failed check returns *off and explains what happened
  v = imoq_verify('EXPRICE' : 'EX_PRICE');
  imoq_with(v : 1 : IMOQ_EQ : 'A0001');
  expect(not imoq_calledTimes(v : 5) : 'A0001 was called twice, not 5');
  expect(%scan('Verification failed' : imoq_lastError()) > 0
         and %scan('''A0001''' : imoq_lastError()) > 0
         : 'imoq_lastError() shows the recorded calls');
end-proc;

// ------------------------------------------------------------------
// Capturing: read the arguments a call received, as text or typed.
// Call numbers start at 1; IMOQ_LAST is the most recent call.
// ------------------------------------------------------------------
dcl-proc capturing;
  dcl-s h int(10);
  dcl-s at time inz(t'14.30.00');
  dcl-s stamp timestamp inz(z'2026-09-24-14.30.00.000000');
  dcl-s rush ind inz(*on);
  dcl-s qty packed(7:2);
  dcl-s due date inz(d'2026-09-30');
  dcl-s name char(30);
  dcl-s found ind;

  imoq_reset();
  h = imoq_when('EXPRICE' : 'EX_SCHEDULE');
  imoq_returns(h : stamp);

  getDiscount(250.00 : 'SPRING');
  getDiscount(10 : *omit);
  getDiscount(20);
  schedule('A0001' : at : stamp : rush : qty : due);
  getCustomer('C0042' : name : found);

  expect(imoq_count('EXPRICE' : 'EX_DISCOUNT') = 3 : 'imoq_count');
  expect(imoq_arg('EXPRICE' : 'EX_DISCOUNT' : 1 : 1) = '250.00'
         : 'imoq_arg returns text');
  expect(imoq_argNum('EXPRICE' : 'EX_DISCOUNT' : 1 : 1) = 250
         : 'imoq_argNum');
  expect(imoq_arg('EXPRICE' : 'EX_DISCOUNT' : 1 : 2) = 'SPRING'
         : 'imoq_arg, parameter 2');
  expect(imoq_argPassed('EXPRICE' : 'EX_DISCOUNT' : 1 : 2)
         : 'imoq_argPassed: passed');
  expect(not imoq_argPassed('EXPRICE' : 'EX_DISCOUNT' : 2 : 2)
         : 'imoq_argPassed: *omit');
  expect(not imoq_argPassed('EXPRICE' : 'EX_DISCOUNT' : IMOQ_LAST : 2)
         : 'imoq_argPassed: not passed');

  expect(imoq_argTime('EXPRICE' : 'EX_SCHEDULE' : IMOQ_LAST : 2) = at
         : 'imoq_argTime');
  expect(imoq_argTimestamp('EXPRICE' : 'EX_SCHEDULE' : IMOQ_LAST : 3)
         = stamp : 'imoq_argTimestamp');
  expect(imoq_argInd('EXPRICE' : 'EX_SCHEDULE' : IMOQ_LAST : 4)
         : 'imoq_argInd');
  expect(imoq_argDate('EXPRICE' : 'EX_SCHEDULE' : IMOQ_LAST : 6) = due
         : 'imoq_argDate');
  expect(imoq_arg('EXCUST' : IMOQ_PGM : IMOQ_LAST : 1) = 'C0042'
         : 'program mocks use IMOQ_PGM');
end-proc;

// ------------------------------------------------------------------
// Resetting: forget recorded calls, stubs, or both. Setup calls that
// fail send escape IMQ0300, for example on a removed stub's handle.
// ------------------------------------------------------------------
dcl-proc resetting;
  dcl-s h int(10);
  dcl-s failed ind;

  imoq_reset();                              // everything, all mocks
  h = imoq_when('EXPRICE' : 'EX_PRICE');
  imoq_returns(h : 7.00);
  getPrice('A0001');

  imoq_reset('EXPRICE' : IMOQ_CALLS);        // calls only
  expect(imoq_count('EXPRICE' : 'EX_PRICE') = 0 : 'calls cleared');
  expect(getPrice('A0001') = 7.00 : 'stub kept');

  imoq_reset('EXPRICE' : IMOQ_STUBS);        // stubs only
  expect(getPrice('A0001') = 0 : 'stub cleared');
  expect(imoq_count('EXPRICE' : 'EX_PRICE') = 2 : 'calls kept');

  imoq_reset('EXPRICE');                     // both, one mock
  expect(imoq_count('EXPRICE' : 'EX_PRICE') = 0 : 'both cleared');

  // h pointed at a stub that is gone
  monitor;
    imoq_returns(h : 1.00);
  on-error;
    failed = *on;
  endmon;
  expect(failed and psds.excId = 'IMQ0300'
         : 'a removed stub''s handle sends IMQ0300');
  expect(%scan('no longer exists' : imoq_lastError()) > 0
         : 'imoq_lastError() says why');
end-proc;
