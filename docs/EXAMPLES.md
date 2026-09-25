# iMoq Examples

The `examples` folder has one short test program and one small CL driver for
each iMoq feature. This page
walks through them in a sensible reading order: what each one teaches, the lines
that matter, and what to notice.

For the concepts behind the examples, see the
[Programmer's Guide](PROGRAMMERS_GUIDE.md).

## Contents

- [Running the examples](#running-the-examples)
- [How the examples are set up](#how-the-examples-are-set-up)
- [Anatomy of an example](#anatomy-of-an-example)
- [Anatomy of a driver](#anatomy-of-a-driver)
- Creating mocks and answering calls
  - [EXPGM: mock a program and fill in output parameters](#expgm-mock-a-program-and-fill-in-output-parameters)
  - [EXRETURN: return a value from a service program procedure](#exreturn-return-a-value-from-a-service-program-procedure)
  - [EXMATCH: answer based on the arguments](#exmatch-answer-based-on-the-arguments)
  - [EXNEWEST: a default answer plus a special case](#exnewest-a-default-answer-plus-a-special-case)
  - [EXSERIES: different answers on successive calls](#exseries-different-answers-on-successive-calls)
  - [EXTIMES: answer only a limited number of calls](#extimes-answer-only-a-limited-number-of-calls)
  - [EXTHROW: make a dependency fail](#exthrow-make-a-dependency-fail)
  - [EXSTRICT: fail on unexpected calls](#exstrict-fail-on-unexpected-calls)
  - [EXOMIT: optional parameters](#exomit-optional-parameters)
  - [EXVALUE: parameters passed by value](#exvalue-parameters-passed-by-value)
  - [EXTYPES: varchar, zoned, float and pointer parameters](#extypes-varchar-zoned-float-and-pointer-parameters)
  - [EXFIELD: data structures, arrays and data structure returns](#exfield-data-structures-arrays-and-data-structure-returns)
- Checking what happened
  - [EXVERIFY: check how often something was called](#exverify-check-how-often-something-was-called)
  - [EXORDER: check the order of calls](#exorder-check-the-order-of-calls)
  - [EXNOMORE: make sure nothing else was called](#exnomore-make-sure-nothing-else-was-called)
  - [EXUNUSED: find stubs that no call used](#exunused-find-stubs-that-no-call-used)
  - [EXCAPT: look at the arguments](#excapt-look-at-the-arguments)
  - [EXERRMSG: read a failed verification](#exerrmsg-read-a-failed-verification)
- Test housekeeping
  - [EXRESET: clear calls or stubs between tests](#exreset-clear-calls-or-stubs-between-tests)
  - [EXCL: use the mocks from CL](#excl-use-the-mocks-from-cl)
  - [EXLIB: create a mock in another library](#exlib-create-a-mock-in-another-library)
  - [EXAPI: everything the RPG API can do](#exapi-everything-the-rpg-api-can-do)
  - [EXAMPLES: run every example](#examples-run-every-example)
- [The end-to-end demo](#the-end-to-end-demo)
- [Writing your own test](#writing-your-own-test)

---

## Running the examples

Build iMoq with the examples. `'*YES'` copies the `examples` folder into the
library and runs every example once:

```
CALL QTEMP/BUILD PARM('IMOQ' '/home/ME/imoq' '*YES')
```

Every example has its own small CL driver named after the example. To run one
example:

```
CRTBNDCL PGM(IMOQ/EXRETURN) SRCFILE(IMOQ/QCLLESRC)
CALL     IMOQ/EXRETURN PARM('IMOQ')
```

The driver ends with `EXRETURN passed`, or with an escape message naming the
expectation that failed, for example `EXRETURN failed: EX_PRICE returns 19.99`.

To run all of them, call `EXAMPLES`, which compiles and calls every driver:

```
CALL IMOQ/EXAMPLES PARM('IMOQ')
```

```
ok   EXPGM
ok   EXRETURN
...
ok   EXCL
EXAMPLES: all examples passed
```

The drivers make the library the job's current library.

## How the examples are set up

To keep each example tiny, the examples call their dependencies **directly**
instead of going through separate code under test. None of these dependencies
exists as a real object: each example's driver creates the mocks that example
needs.

| Mock | Type | Plays the part of | Interface |
|---|---|---|---|
| `EXCUST` | `*PGM` | Customer lookup | `custId char(5) const`, `name char(30)`, `found ind` |
| `EXAUDIT` | `*PGM`, strict | Audit trail | `event char(20) const` |
| `EXPRICE` | `*SRVPGM` | Pricing service | `EX_PRICE(item char(5) const) packed(7:2)`<br>`EX_DISCOUNT(amount packed(7:2) const : code char(10) const options(*nopass:*omit)) packed(7:2)`<br>`EX_LOG(text char(50) const)`<br>`EX_SCHEDULE` and `EX_CUTOFF` (`EXAPI` only: time, timestamp and date parameters) |
| `EXCALC` | `*SRVPGM` | Calculator (`EXVALUE`) | `EX_ROUND(amount packed(9:2) value : places int(10) value) packed(9:2)` |
| `EXPROF` | `*PGM` | Customer profile (`EXTYPES`) | `name varchar(30)`, `balance zoned(9:2)`, `rate float(8)`, `note pointer` |
| `EXORDER` | `*SRVPGM` | Order entry (`EXFIELD`) | `EX_ADDORDER(order likeds(order_t) const : monthly packed(9:2) dim(12) const) likeds(result_t)`<br>`EX_PRICEIT(order likeds(order_t))` |

Each example declares the prototypes it calls (`getCustomer`, `writeAudit`,
`getPrice`, `getDiscount` or `logMessage`) at its top, so everything an example
uses is in one file. The only shared piece is
[`EXAMPLE_H`](../examples/QRPGLESRC/EXAMPLE_H.rpgleinc), which holds the
`expect()` helper.

In a real project, the mocks stand in for programs and service programs that
already exist. Your tests call your own code, and that code calls the mocks.
[The end-to-end demo](#the-end-to-end-demo) shows that complete setup.

## Anatomy of an example

Every example is a small linear-main test program named `<example>_T`:

```rpgle
**free
ctl-opt main(main);

/copy QRPGLESRC,IMOQ_H              // imoq(), imoq_ok(), imoq_arg() ...

// The dependency this example calls. It is a mock created by the
// driver EXRETURN; no real object exists.

// EXPRICE (*SRVPGM), procedure EX_PRICE: price of an item
dcl-pr getPrice packed(7:2) extproc('EX_PRICE');
  item char(5) const;
end-pr;

/copy QRPGLESRC,EXAMPLE_H           // expect()

dcl-proc main;
  imoq('IMOQRESET');                // 1. start clean

  imoq('IMOQWHEN ...');             // 2. say what the mock should do

  // 3. call something and check the result
  expect(getPrice('A0001') = 19.99 : 'EX_PRICE returns 19.99');

  // 4. optionally verify the calls
  expect(imoq_ok('IMOQVERIFY ...') : imoq_lastError());
end-proc;
```

- **`imoq(cmd)`** runs any MOCK command, and stops the example with IMQ0300 if
  the command fails.
- **`imoq_ok(cmd)`** runs a MOCK command and returns `*off` if it fails. It suits
  verifications.
- **The prototype is the same one the real code would use.** The example calls
  `EX_PRICE` normally, and the mock answers.
- **`expect(condition : description)`** stops the example with that description
  when the condition is false. `EXAMPLE_H` must be copied in after the
  prototypes, because it contains a procedure.
- **Quoting:** inside an RPG string, every quote that CL needs is doubled:
  `RETURN(''19.99'')`.

## Anatomy of a driver

Each driver does the same four steps. This is `EXRETURN`, with its comment
header left out:

```
             PGM        PARM(&LIB)
             DCL        VAR(&LIB) TYPE(*CHAR) LEN(10)
             DCL        VAR(&MSG) TYPE(*CHAR) LEN(512)

/* iMoq and the example source are in &LIB                          */
             CHGCURLIB  CURLIB(&LIB)

/* 1. Create the mock                                               */
             IMOQSRVPGM OBJ(EXPRICE)
             IMOQPROC   OBJ(EXPRICE) PROC(EX_PRICE) +
                          RTNTYPE(*PACKED 7 2) PARMS((*CHAR 5 *CONST))
             IMOQBUILD  OBJ(EXPRICE)

/* 2. Compile the test program                                      */
             CRTRPGMOD  MODULE(QTEMP/EXRETURN_T) SRCFILE(&LIB/QRPGLESRC)
             CRTPGM     PGM(QTEMP/EXRETURN_T) MODULE(QTEMP/EXRETURN_T) +
                          BNDSRVPGM((*LIBL/EXPRICE) (*LIBL/IMOQENG)) +
                          ACTGRP(*NEW)

/* 3. Run it. A failed expect() arrives as escape message CPF9898.  */
             CALL       PGM(QTEMP/EXRETURN_T)
             MONMSG     MSGID(CPF9898) EXEC(DO)
             RCVMSG     MSGTYPE(*EXCP) MSG(&MSG)
             SNDPGMMSG  MSGID(CPF9898) MSGF(QCPFMSG) MSGDTA('EXRETURN +
                          failed:' *BCAT &MSG) MSGTYPE(*ESCAPE)
             ENDDO

/* 4. Remove the mock                                               */
             IMOQRMV
             SNDPGMMSG  MSGID(CPF9897) MSGF(QCPFMSG) MSGDTA('EXRETURN +
                          passed') MSGTYPE(*COMP)
             ENDPGM
```

What to notice:
- **Mocks come first.** They exist before the test program is compiled or
  activated.
- **Program mocks need one command.** A program mock is only `IMOQPGM`, while a
  service program mock is `IMOQSRVPGM` + `IMOQPROC` + `IMOQBUILD`.
- **No real object and no binder source.** By default (`SRCFILE(*NONE)`), the
  mock exports exactly the procedures declared with `IMOQPROC`, and `IMOQBUILD`
  generates everything else in QTEMP.
- **Bind through `*LIBL`.** The test program binds `*LIBL/EXPRICE`, so it
  activates the mock in QTEMP. It also binds `IMOQENG` for the `IMOQ_H`
  procedures.
- **The library can stay the current library here,** because no real `EXPRICE`,
  `EXCUST` or `EXAUDIT` exists to hide a mock. With real dependencies, put their
  library after QTEMP, as the [end-to-end demo](#the-end-to-end-demo) does.

---

## Creating mocks and answering calls

### EXPGM: mock a program and fill in output parameters

Test program [`EXPGM_T`](../examples/QRPGLESRC/EXPGM_T.rpgle), driver [`EXPGM`](../examples/QCLLESRC/EXPGM.clle)

A program "answers" by writing into the caller's parameters, which is what
`SETPARM` does.

```rpgle
// Driver: IMOQPGM OBJ(EXCUST) PARMS((*CHAR 5) (*CHAR 30) (*IND))
imoq('IMOQWHEN OBJ(EXCUST) +
      SETPARM((2 ''Ada Lovelace'') (3 ''1''))');

getCustomer('C0001' : name : found);

expect(name = 'Ada Lovelace' : 'name is set by SETPARM');
expect(found : 'found is set by SETPARM');
```

What to notice:
- **Parameters are numbered from 1.** `SETPARM((2 …))` writes the second
  parameter.
- **Values are text.** They're converted to the type declared on `IMOQPGM
  PARMS`: `'1'` becomes an indicator that is on.
- **Program mocks don't need `PROC`.**

### EXRETURN: return a value from a service program procedure

Test program [`EXRETURN_T`](../examples/QRPGLESRC/EXRETURN_T.rpgle), driver [`EXRETURN`](../examples/QCLLESRC/EXRETURN.clle)

```rpgle
// Driver: IMOQSRVPGM OBJ(EXPRICE)
//         IMOQPROC   OBJ(EXPRICE) PROC(EX_PRICE) RTNTYPE(*PACKED 7 2)
//                      PARMS((*CHAR 5 *CONST))
//         IMOQBUILD  OBJ(EXPRICE)
imoq('IMOQWHEN OBJ(EXPRICE) PROC(EX_PRICE) RETURN(''19.99'')');

expect(getPrice('A0001') = 19.99 : 'EX_PRICE returns 19.99');
expect(getPrice('B0002') = 19.99 : 'no ARGS, so every call matches');
```

What to notice:
- **Three commands create a service program mock.** `IMOQSRVPGM` starts it,
  `IMOQPROC` declares the procedure, and `IMOQBUILD` creates the object. Each
  `IMOQPROC` also adds the procedure as an export, so no real `EXPRICE` or binder
  source is needed. The end-to-end demo uses `SRCFILE(*RTV)` instead, which copies
  the exports of a real service program.
- **`RETURN` needs a return type.** It only works for procedures declared with
  `RTNTYPE`.
- **Without `ARGS`, a stub matches every call.**

### EXMATCH: answer based on the arguments

Test program [`EXMATCH_T`](../examples/QRPGLESRC/EXMATCH_T.rpgle), driver [`EXMATCH`](../examples/QCLLESRC/EXMATCH.clle)

```rpgle
imoq('IMOQWHEN OBJ(EXPRICE) PROC(EX_PRICE) +
      ARGS((1 *EQ A0001)) RETURN(''1.00'')');
imoq('IMOQWHEN OBJ(EXPRICE) PROC(EX_PRICE) +
      ARGS((1 *LIKE ''B%'')) RETURN(''2.00'')');
imoq('IMOQWHEN OBJ(EXPRICE) PROC(EX_PRICE) +
      ARGS((1 *BLANK)) RETURN(''0.50'')');
imoq('IMOQWHEN OBJ(EXPRICE) PROC(EX_DISCOUNT) +
      ARGS((1 *GT 100)) RETURN(''10.00'')');

expect(getPrice('A0001') = 1.00 : '*EQ A0001');
expect(getPrice('B7777') = 2.00 : '*LIKE B%');
expect(getPrice(' ') = 0.50 : '*BLANK');
expect(getDiscount(150.00) = 10.00 : '*GT 100');
expect(getPrice('Z9999') = 0 : 'no match returns zero');
```

What to notice:
- **`ARGS` entries are `(parameter matcher value)`.** Every entry must match for
  the stub to answer.
- **The matchers are** `*EQ`, `*NE`, `*GT`, `*GE`, `*LT`, `*LE`, `*LIKE` (`%` is
  any text, `_` is one character), `*BLANK`, `*ANY`, `*OMIT` and `*NOTPASSED`.
- **Numbers compare as numbers**, so `150.00` is greater than `100`.
- **A loose mock returns zero or blanks when nothing matches.**

### EXNEWEST: a default answer plus a special case

Test program [`EXNEWEST_T`](../examples/QRPGLESRC/EXNEWEST_T.rpgle), driver [`EXNEWEST`](../examples/QCLLESRC/EXNEWEST.clle)

```rpgle
imoq('IMOQWHEN OBJ(EXPRICE) PROC(EX_PRICE) RETURN(''5.00'')');   // default
imoq('IMOQWHEN OBJ(EXPRICE) PROC(EX_PRICE) +
      ARGS((1 *EQ GOLD1)) RETURN(''99.00'')');                 // special case

expect(getPrice('GOLD1') = 99.00 : 'special case wins for GOLD1');
expect(getPrice('PLAIN') = 5.00 : 'everything else gets the default');
```

What to notice:
- **The newest matching stub wins.** Stubs are checked from newest to oldest.
- **Typical use:** set general answers in your test setup, and add special cases
  inside individual tests.

### EXSERIES: different answers on successive calls

Test program [`EXSERIES_T`](../examples/QRPGLESRC/EXSERIES_T.rpgle), driver [`EXSERIES`](../examples/QCLLESRC/EXSERIES.clle)

```rpgle
imoq('IMOQWHEN OBJ(EXPRICE) PROC(EX_PRICE) +
      RETURN(''1.00'' ''2.00'' ''3.00'')');

expect(getPrice('A0001') = 1.00 : 'call 1 returns 1.00');
expect(getPrice('A0001') = 2.00 : 'call 2 returns 2.00');
expect(getPrice('A0001') = 3.00 : 'call 3 returns 3.00');
expect(getPrice('A0001') = 3.00 : 'call 4 repeats the last value');
```

What to notice:
- **List several values in `RETURN`.** They're returned in order, and the last
  one repeats.
- **Use this for loops and retries,** for example "fails twice, then succeeds".

### EXTIMES: answer only a limited number of calls

Test program [`EXTIMES_T`](../examples/QRPGLESRC/EXTIMES_T.rpgle), driver [`EXTIMES`](../examples/QCLLESRC/EXTIMES.clle)

```rpgle
imoq('IMOQWHEN OBJ(EXPRICE) PROC(EX_PRICE) RETURN(''10.00'')');
imoq('IMOQWHEN OBJ(EXPRICE) PROC(EX_PRICE) RETURN(''0.00'') TIMES(2)');

expect(getPrice('A0001') = 0.00 : 'call 1 is free');
expect(getPrice('A0001') = 0.00 : 'call 2 is free');
expect(getPrice('A0001') = 10.00 : 'call 3 uses the older stub');
```

What to notice:
- **`TIMES(n)` limits a stub to n calls.** After that it's skipped, and older
  stubs answer again.
- **The default is `TIMES(*ALWAYS)`.**

### EXTHROW: make a dependency fail

Test program [`EXTHROW_T`](../examples/QRPGLESRC/EXTHROW_T.rpgle), driver [`EXTHROW`](../examples/QCLLESRC/EXTHROW.clle)

```rpgle
imoq('IMOQWHEN OBJ(EXCUST) +
      THROW(CPF9898 QCPFMSG *LIBL ''Customer file is locked'')');

monitor;
  getCustomer('C0001' : name : found);
on-error;
  failed = *on;
endmon;

expect(failed and psds.excId = 'CPF9898' : 'EXCUST sends CPF9898');

imoq('IMOQWHEN OBJ(EXCUST) +
      THROW(*MOCK *MOCK *LIBL ''Customer file is locked'')');
```

What to notice:
- **The format is `THROW(message-id message-file library 'message data')`.** It
  takes one set of parentheses.
- **The caller gets a normal escape message**, so error handling can be tested
  exactly as it runs in production.
- **`THROW(*MOCK *MOCK …)`** sends iMoq's own IMQ0101 from its message file,
  with your text.
- **The program status data structure** (positions 40–46) holds the ID of the
  message `MONITOR` caught.

### EXSTRICT: fail on unexpected calls

Test program [`EXSTRICT_T`](../examples/QRPGLESRC/EXSTRICT_T.rpgle), driver [`EXSTRICT`](../examples/QCLLESRC/EXSTRICT.clle)

```rpgle
// Driver: IMOQPGM OBJ(EXAUDIT) PARMS((*CHAR 20)) BEHAVIOR(*STRICT)
imoq('IMOQWHEN OBJ(EXAUDIT) ARGS((1 *EQ LOGIN))');

writeAudit('LOGIN');              // allowed

monitor;
  writeAudit('DELETE');           // not allowed
on-error;
  rejected = *on;
endmon;

expect(rejected : 'DELETE was not expected, so the call fails');
expect(%scan('Unexpected call to EXAUDIT' : imoq_lastError()) > 0
       : 'imoq_lastError() explains the unexpected call');
```

What to notice:
- **A strict mock rejects unmatched calls.** Any call that no `IMOQWHEN` matches
  gets escape message IMQ0100.
- **A `IMOQWHEN` doesn't need an answer.** Here it only marks `LOGIN` as an
  allowed call.
- **Strictness belongs to the mock object.** Choose it on `IMOQPGM` or
  `IMOQSRVPGM`.

### EXOMIT: optional parameters

Test program [`EXOMIT_T`](../examples/QRPGLESRC/EXOMIT_T.rpgle), driver [`EXOMIT`](../examples/QCLLESRC/EXOMIT.clle)

```rpgle
// EX_DISCOUNT's second parameter is options(*nopass:*omit)
imoq('IMOQWHEN OBJ(EXPRICE) PROC(EX_DISCOUNT) +
      ARGS((1 *ANY) (2 *NOTPASSED)) RETURN(''1.00'')');
imoq('IMOQWHEN OBJ(EXPRICE) PROC(EX_DISCOUNT) +
      ARGS((2 *OMIT)) RETURN(''2.00'')');
imoq('IMOQWHEN OBJ(EXPRICE) PROC(EX_DISCOUNT) +
      ARGS((2 *EQ VIP)) RETURN(''3.00'')');

expect(getDiscount(100) = 1.00 : 'code not passed');
expect(getDiscount(100 : *omit) = 2.00 : 'code passed as *OMIT');
expect(getDiscount(100 : 'VIP') = 3.00 : 'code VIP');

expect(imoq_arg('EXPRICE' : 'EX_DISCOUNT' : 1 : 2) = '*NOTPASSED' : ...);
expect(imoq_arg('EXPRICE' : 'EX_DISCOUNT' : 2 : 2) = '*OMIT' : ...);
```

What to notice:
- **`*NOTPASSED` and `*OMIT` are different.** `*NOTPASSED` matches a parameter
  that was left off the call (`*NOPASS`). `*OMIT` matches one passed as
  `*OMIT`.
- **`*ANY` matches anything,** including missing parameters.
- **`imoq_arg` reports missing parameters** as `*NOTPASSED` or `*OMIT`.

### EXVALUE: parameters passed by value

Test program [`EXVALUE_T`](../examples/QRPGLESRC/EXVALUE_T.rpgle), driver [`EXVALUE`](../examples/QCLLESRC/EXVALUE.clle)

```
IMOQPROC   OBJ(EXCALC) PROC(EX_ROUND) RTNTYPE(*PACKED 9 2) +
             PARMS((*PACKED 9 2 *VALUE) (*INT 10 0 *VALUE))
```

```rpgle
imoq('IMOQWHEN OBJ(EXCALC) PROC(EX_ROUND) +
      ARGS((2 *EQ 0)) RETURN(''13.00'')');

expect(roundTo(12.55 : 0) = 13.00 : 'no decimal places');
expect(imoq_arg('EXCALC' : 'EX_ROUND' : 1 : 1) = '12.55' : ...);

expect(not imoq_ok('IMOQWHEN OBJ(EXCALC) PROC(EX_ROUND) +
                    SETPARM((1 ''0''))') : ...);
```

What to notice:
- **`*VALUE` goes in the layout** where the passing style goes, exactly as the
  prototype says `value`. Get it wrong and the stub reads garbage.
- **Matchers and captures work as usual.**
- **`SETPARM` is refused** with IMQ0014: the caller keeps its own copy of a
  value parameter, so there's nothing to write back to.

### EXTYPES: varchar, zoned, float and pointer parameters

Test program [`EXTYPES_T`](../examples/QRPGLESRC/EXTYPES_T.rpgle), driver [`EXTYPES`](../examples/QCLLESRC/EXTYPES.clle)

```
IMOQPGM    OBJ(EXPROF) PARMS((*VARCHAR 30) (*ZONED 9 2) (*FLOAT 8) (*PTR))
```

```rpgle
imoq('IMOQWHEN OBJ(EXPROF) ARGS((1 *EQ ''Ada'')) +
      SETPARM((2 ''1234.50'') (3 ''0.25'') (4 ''*NULL''))');
imoq('IMOQWHEN OBJ(EXPROF) ARGS((1 *EQ ''Bob'')) +
      SETPARM((1 ''Robert''))');
...
imoq('IMOQWHEN OBJ(EXPROF) +
      ARGS((2 *GT 1000) (3 *LT 1) (4 *EQ ''*NOTNULL'')) +
      SETPARM((1 ''BIG SPENDER''))');
...
expect(%float(imoq_arg('EXPROF' : IMOQ_PGM : IMOQ_LAST : 3)) = 0.5 : ...);
expect(imoq_arg('EXPROF' : IMOQ_PGM : IMOQ_LAST : 4) = '*NOTNULL' : ...);
```

What to notice:
- **Setting a varchar sets its length too:** after `SETPARM((1 'Robert'))`,
  `%len(name)` is 6.
- **Zoned and float compare as numbers,** so `*GT 1000` and `*LT 1` work.
- **Pointers are `*NULL` or `*NOTNULL`.** A matcher can test which, and a stub
  can set a pointer to `*NULL`, but not point it anywhere else.
- **A captured float is text in E notation,** such as `5.000000000000000E-001`.
  Convert it with `%float` before comparing.

### EXFIELD: data structures, arrays and data structure returns

Test program [`EXFIELD_T`](../examples/QRPGLESRC/EXFIELD_T.rpgle), driver [`EXFIELD`](../examples/QCLLESRC/EXFIELD.clle)

```
IMOQPROC   OBJ(EXORDER) PROC(EX_ADDORDER) RTNTYPE(*CHAR 12) +
             PARMS((*CHAR 28 *CONST) (*CHAR 60 *CONST))
IMOQFIELD  OBJ(EXORDER) PROC(EX_ADDORDER) PARM(1) +
             FIELDS((ITEM 1 *CHAR 5) (QTY *NEXT *PACKED 7 0) +
                    (PRICE *NEXT *ZONED 9 2) (SHIPPED *NEXT *DATE))
IMOQFIELD  OBJ(EXORDER) PROC(EX_ADDORDER) PARM(2) +
             FIELDS((AMT 1 *PACKED 9 2 12))
IMOQFIELD  OBJ(EXORDER) PROC(EX_ADDORDER) PARM(0) +
             FIELDS((STATUS 1 *CHAR 2) (TOTAL *NEXT *PACKED 11 2) +
                    (LINENO *NEXT *INT 10))
```

```rpgle
imoq('IMOQWHEN OBJ(EXORDER) PROC(EX_ADDORDER) +
      ARGS((1 *EQ A0001 ITEM) (1 *GT 10 QTY)) +
      SETPARM((0 OK STATUS) (0 ''99.50'' TOTAL) (0 7 LINENO))');
imoq('IMOQWHEN OBJ(EXORDER) PROC(EX_ADDORDER) +
      ARGS((2 *GT 1000 ''AMT(12)'')) SETPARM((0 HI STATUS))');
...
expect(imoq_arg('EXORDER' : 'EX_ADDORDER' : 1 : 1 : 'QTY') = '12' : ...);

// the same with the RPG API
h = imoq_when('EXORDER' : 'EX_ADDORDER');
imoq_with(h : 1 : IMOQ_EQ : 'B0002' : 'ITEM');
imoq_with(h : 2 : IMOQ_EQ : 0 : 'AMT(1)');
imoq_setParm(h : 0 : 12.50 : 'TOTAL');
```

What to notice:
- **A data structure or array is one `*CHAR`,** and `IMOQFIELD` describes
  its subfields: name, position (or `*NEXT`), type and length, and a number
  of elements for an array.
- **The field goes last** in an `ARGS` or `SETPARM` entry, as `FIELD()` on
  `IMOQGETARG`, and as the last argument in the RPG API. An array element
  (`AMT(12)`) needs quotes in a command.
- **Subfields compare by their own type,** so `QTY *GT 10` compares packed
  numbers.
- **Parameter 0 is the return value.** `SETPARM` on its fields builds the
  returned data structure; fields you don't set come back blank or zero.
- **`SETPARM` on an output data structure changes only that subfield.**

---

## Checking what happened

### EXVERIFY: check how often something was called

Test program [`EXVERIFY_T`](../examples/QRPGLESRC/EXVERIFY_T.rpgle), driver [`EXVERIFY`](../examples/QCLLESRC/EXVERIFY.clle)

```rpgle
logMessage('started');
logMessage('working');
logMessage('working');

expect(imoq_ok('IMOQVERIFY OBJ(EXPRICE) PROC(EX_LOG) +
                TIMES(*EXACTLY 3)') : imoq_lastError());
expect(imoq_ok('IMOQVERIFY OBJ(EXPRICE) PROC(EX_LOG) +
                ARGS((1 *EQ ''working'')) TIMES(*EXACTLY 2)')
       : imoq_lastError());
expect(imoq_ok('IMOQVERIFY OBJ(EXPRICE) PROC(EX_LOG) +
                ARGS((1 *EQ ''started'')) TIMES(*ONCE)')
       : imoq_lastError());
expect(imoq_ok('IMOQVERIFY OBJ(EXPRICE) PROC(EX_LOG) +
                ARGS((1 *EQ ''stopped'')) TIMES(*NEVER)')
       : imoq_lastError());
```

What to notice:
- **The `TIMES` forms are** `*ONCE`, `*NEVER`, `*EXACTLY n`, `*ATLEAST n` and
  `*ATMOST n`. The default is `*EXACTLY 1`.
- **Add `ARGS` to count only the matching calls.**
- **Quote mixed-case values.** An unquoted `working` would be uppercased by CL.
- **Pass `imoq_lastError()` as the assertion message** so a failure explains
  itself.

### EXORDER: check the order of calls

Test program [`EXORDER_T`](../examples/QRPGLESRC/EXORDER_T.rpgle), driver [`EXORDER`](../examples/QCLLESRC/EXORDER.clle)

```rpgle
lockCust('C0042');
getCustomer('C0042' : name : found);
unlockCust('C0042');

expect(imoq_ok('IMOQORDER OBJ(EXLOCK) PROC(EX_LOCK) +
                ARGS((1 *EQ C0042))') : imoq_lastError());
expect(imoq_ok('IMOQORDER OBJ(EXCUST) ARGS((1 *EQ C0042))')
       : imoq_lastError());
expect(imoq_ok('IMOQORDER OBJ(EXLOCK) PROC(EX_UNLOCK)')
       : imoq_lastError());
```

With the RPG API, where the code under test reads the customer after
unlocking it:

```rpgle
v = imoq_verify('EXLOCK' : 'EX_LOCK');
expect(imoq_calledInOrder(v) : imoq_lastError());
v = imoq_verify('EXCUST');
imoq_with(v : 1 : IMOQ_EQ : 'C0042');
expect(imoq_calledInOrder(v) : imoq_lastError());
v = imoq_verify('EXLOCK' : 'EX_UNLOCK');
expect(not imoq_calledInOrder(v) : 'API: the unlock came too early');
expect(imoq_calledOnce(v) : imoq_lastError());
```

What to notice:
- **Each step must come after the previous step's call.** Other calls may
  come in between.
- **Order is checked only where you ask.** `imoq_calledOnce` still passes for
  the early unlock: counting checks never look at the order.
- **`AFTER(*START)` or `imoq_startOrder()` begins a new sequence.**
  `IMOQRESET` of the recorded calls does too.
- **A failure says where the sequence stood,** such as `after
  EXLOCK.EX_UNLOCK#3('C0042')`, and lists when the matching calls happened.

### EXNOMORE: make sure nothing else was called

Test program [`EXNOMORE_T`](../examples/QRPGLESRC/EXNOMORE_T.rpgle), driver [`EXNOMORE`](../examples/QCLLESRC/EXNOMORE.clle)

```rpgle
logMessage('hello');
getPrice('A0001');

expect(imoq_ok('IMOQVERIFY OBJ(EXPRICE) PROC(EX_LOG)') : imoq_lastError());
expect(not imoq_ok('IMOQNOMORE') : 'the EX_PRICE call is not verified yet');

expect(imoq_ok('IMOQVERIFY OBJ(EXPRICE) PROC(EX_PRICE)') : imoq_lastError());
expect(imoq_ok('IMOQNOMORE') : 'every call is now verified');
```

What to notice:
- **A successful `IMOQVERIFY` marks its matching calls as verified.**
- **`IMOQNOMORE` catches surprise calls.** It fails while any recorded call is
  still unverified.
- **Limit it with `OBJ(name)`** to check just one mock.

### EXUNUSED: find stubs that no call used

Test program [`EXUNUSED_T`](../examples/QRPGLESRC/EXUNUSED_T.rpgle), driver [`EXUNUSED`](../examples/QCLLESRC/EXUNUSED.clle)

```rpgle
imoq('IMOQWHEN OBJ(EXPRICE) PROC(EX_PRICE) ARGS((1 *EQ A0001)) +
      RETURN(''9.99'')');
// A typo: the test calls with B0002, so this stub never answers
imoq('IMOQWHEN OBJ(EXPRICE) PROC(EX_PRICE) ARGS((1 *EQ B002)) +
      RETURN(''5.00'')');

expect(getPrice('A0001') = 9.99 : 'the A0001 stub answered');
expect(getPrice('B0002') = 0 : 'no stub matched B0002');

expect(not imoq_ok('IMOQUNUSED') : 'the B002 stub is unused');
```

With the RPG API:

```rpgle
expect(not imoq_noUnusedStubs('EXPRICE')
       : 'API: the B002 stub is unused');
```

What to notice:
- **A wrong matcher doesn't fail on its own.** The call gets the default
  answer of a `*LOOSE` mock, and the test may fail somewhere unrelated, or not
  at all.
- **`IMOQUNUSED` names the stub.** Escape message IMQ0203 lists each stub that
  answered no call, with its number and matchers, such as
  `stub 3 EXPRICE.EX_PRICE with (1 *EQ 'B002')`.
- **One answered call is enough,** even for a stub with `TIMES(n)` or
  `imoq_times`.
- **Limit it with `OBJ(name)`** to check just one mock.

### EXCAPT: look at the arguments

Test program [`EXCAPT_T`](../examples/QRPGLESRC/EXCAPT_T.rpgle), driver [`EXCAPT`](../examples/QCLLESRC/EXCAPT.clle)

```rpgle
getPrice('A0001');
getPrice('B0002');
getDiscount(250.00 : 'SPRING');
getCustomer('C0042' : name : found);

expect(imoq_count('EXPRICE' : 'EX_PRICE') = 2 : 'EX_PRICE called twice');
expect(imoq_arg('EXPRICE' : 'EX_PRICE' : 1 : 1) = 'A0001' : ...);
expect(imoq_arg('EXPRICE' : 'EX_PRICE' : IMOQ_LAST : 1) = 'B0002' : ...);
expect(imoq_arg('EXPRICE' : 'EX_DISCOUNT' : IMOQ_LAST : 1) = '250.00' : ...);
expect(imoq_arg('EXCUST' : IMOQ_PGM : IMOQ_LAST : 1) = 'C0042' : ...);
```

What to notice:
- **The call is `imoq_arg(mock : procedure : call number : parameter number)`.**
- **`IMOQ_LAST` picks the most recent call**, and `IMOQ_PGM` is the procedure
  name for program mocks.
- **Values come back as text:** numbers formatted like `250.00`, trailing blanks
  removed.
- **Capture when a matcher can't express the check,** such as a value computed
  by the code under test.

### EXERRMSG: read a failed verification

Test program [`EXERRMSG_T`](../examples/QRPGLESRC/EXERRMSG_T.rpgle), driver [`EXERRMSG`](../examples/QCLLESRC/EXERRMSG.clle)

```rpgle
getPrice('A0001');

expect(not imoq_ok('IMOQVERIFY OBJ(EXPRICE) PROC(EX_PRICE) +
                    ARGS((1 *EQ B0002))') : 'verification fails');

message = imoq_lastError();
```

`message` now contains:

```
Verification failed: expected EXPRICE.EX_PRICE to be called exactly 1 time(s)
with (1 *EQ 'B0002') but it matched 0 time(s). Recorded calls: #1('A0001')
```

What to notice:
- **The message lists the calls that really happened**, which is usually all
  you need to spot the bug.
- **`imoq()` sends an escape message instead.** It fails with IMQ0300, so use
  `imoq()` for setup and `imoq_ok()` for checks.

---

## Test housekeeping

### EXRESET: clear calls or stubs between tests

Test program [`EXRESET_T`](../examples/QRPGLESRC/EXRESET_T.rpgle), driver [`EXRESET`](../examples/QCLLESRC/EXRESET.clle)

```rpgle
imoq('IMOQWHEN OBJ(EXPRICE) PROC(EX_PRICE) RETURN(''7.00'')');
getPrice('A0001');

imoq('IMOQRESET OBJ(EXPRICE) SCOPE(*CALLS)');     // forget calls, keep stub
expect(imoq_count('EXPRICE' : 'EX_PRICE') = 0 : 'calls cleared');
expect(getPrice('A0001') = 7.00 : 'stub still answers');

imoq('IMOQRESET OBJ(EXPRICE) SCOPE(*STUBS)');     // forget stub, keep calls
expect(getPrice('A0001') = 0 : 'no stub left, loose mock returns zero');
expect(imoq_count('EXPRICE' : 'EX_PRICE') = 2 : 'calls were kept');
```

What to notice:
- **`IMOQRESET` with no parameters clears everything for every mock.** Put it
  in your test setup.
- **`IMOQRESET` never deletes mock objects**, so there's nothing to rebuild.
  `IMOQRMV` is the command that removes mocks.

### EXCL: use the mocks from CL

Driver and example in one: [`EXCL`](../examples/QCLLESRC/EXCL.clle)

```
IMOQWHEN   OBJ(EXCUST) ARGS((1 *EQ C0042)) +
             SETPARM((2 'Grace Hopper') (3 '1'))
CALL       PGM(EXCUST) PARM('C0042' &NAME &FOUND)

IMOQCOUNT  OBJ(EXCUST) RTNVAL(&COUNT)             /* &COUNT *DEC 10 0 */
IMOQGETARG OBJ(EXCUST) PARM(1) CALL(*LAST) RTNVAL(&ARG)   /* *CHAR 256 */

IMOQVERIFY OBJ(EXCUST) ARGS((1 *EQ C0042)) TIMES(*ONCE)
IMOQVERIFY OBJ(EXCUST) TIMES(*NEVER)
MONMSG     MSGID(IMQ0200) EXEC(CHGVAR VAR(&FAILED) VALUE('1'))
```

What to notice:
- **One program does it all:** it creates the mock, stubs, calls, verifies and
  removes the mock.
- **The same commands work in CL,** without the doubled quotes.
- **`IMOQCOUNT` and `IMOQGETARG` only work in CL programs,** because they return
  values into CL variables. RPG uses `imoq_count` and `imoq_arg`.
- **A failed `IMOQVERIFY` sends IMQ0200,** which CL can monitor.

### EXLIB: create a mock in another library

Driver and example in one: [`EXLIB`](../examples/QCLLESRC/EXLIB.clle)

```
IMOQPGM    OBJ(EXCUST) PARMS((*CHAR 5) (*CHAR 30) (*IND)) LIB(&LIB)
IMOQWHEN   OBJ(EXCUST) SETPARM((2 'Ada Lovelace') (3 '1'))
CALL       PGM(EXCUST) PARM('C0001' &NAME &FOUND)

CRTDUPOBJ  OBJ(EXLIB) FROMLIB(&LIB) OBJTYPE(*PGM) TOLIB(&LIB) +
             NEWOBJ(EXREAL)
IMOQPGM    OBJ(EXREAL) PARMS((*CHAR 5)) LIB(&LIB)
MONMSG     MSGID(IMQ0016) EXEC(CHGVAR VAR(&REFUSED) VALUE('1'))

IMOQRMV    OBJ(EXCUST)
```

What to notice:
- **`LIB(name)` puts the mock object in that library** instead of QTEMP. It
  must come before any real object of that name in the library list.
- **Stubs and calls still live in QTEMP,** so they belong to this job.
- **iMoq never replaces a real object.** `EXREAL` isn't an iMoq mock, so
  `IMOQPGM` refuses with IMQ0016 and leaves it alone.
- **`IMOQRMV OBJ(name)` removes one mock.** A mock outside QTEMP outlives the
  job, so remove it at the end of the driver.

### EXAPI: everything the RPG API can do

Test program [`EXAPI_T`](../examples/QRPGLESRC/EXAPI_T.rpgle), driver [`EXAPI`](../examples/QCLLESRC/EXAPI.clle)

The other examples run the commands through `imoq('…')`. `EXAPI` does the same
jobs with the RPG API, one test procedure per topic:

| Procedure | Shows |
|---|---|
| `stubbing` | `imoq_when`, a series of `imoq_returns`, `imoq_setParm`, `imoq_times(h : 1)` and `IMOQ_ALWAYS`, and the newest stub winning |
| `matchers` | All eleven matchers: `IMOQ_EQ`, `NE`, `LIKE`, `BLANK` on text; `GT`, `GE`, `LT`, `LE` on numbers (two on one parameter make a range); `ANY`, `OMIT`, `NOTPASSED` on an optional parameter |
| `typedValues` | Times and timestamps in `imoq_with`, numbers and dates in `imoq_setParm`, timestamp and time return values |
| `throwing` | `imoq_throws` with `IMOQ_MOCK` (IMQ0101) and with `CPF9898` from `QCPFMSG` |
| `verifying` | `imoq_verify` with `imoq_calledOnce`, `imoq_calledTimes`, `imoq_calledAtLeast`, `imoq_calledAtMost`, `imoq_neverCalled`, `imoq_matchCount`, `imoq_noMoreCalls` with and without a mock name, and a failed check's message. `imoq_noUnusedStubs` is in [EXUNUSED](#exunused-find-stubs-that-no-call-used) |
| `capturing` | `imoq_arg`, `imoq_argNum`, `imoq_argDate`, `imoq_argTime`, `imoq_argTimestamp`, `imoq_argInd`, `imoq_argPassed` and `imoq_count` |
| `resetting` | `imoq_reset()` and `imoq_reset(obj : IMOQ_CALLS / IMOQ_STUBS)`, and a removed stub's handle sending IMQ0300 |

```rpgle
h = imoq_when('EXPRICE' : 'EX_DISCOUNT');
imoq_with(h : 1 : IMOQ_GE : 50);         // two matchers: a range
imoq_with(h : 1 : IMOQ_LE : 60);
imoq_returns(h : 2);

h = imoq_when('EXPRICE' : 'EX_SCHEDULE');
imoq_with(h : 2 : IMOQ_GE : t'12.00.00');                    // time
imoq_setParm(h : 5 : 12.5);                                  // number
imoq_setParm(h : 6 : d'2026-10-15');                         // date
imoq_returns(h : z'2026-10-15-08.00.00.000000');             // timestamp

v = imoq_verify('EXPRICE' : 'EX_PRICE');
imoq_with(v : 1 : IMOQ_EQ : 'A0001');
expect(imoq_calledTimes(v : 2) : imoq_lastError());
```

What to notice:
- **No command strings.** Each keyword of `IMOQWHEN` and `IMOQVERIFY` is a
  call on a handle, and values are RPG values: `12.5`, `d'2026-10-15'`,
  `t'12.00.00'`, `'ACME CORP'`.
- **The stub answers as soon as `imoq_when` returns,** and each later call
  adds to it.
- **Checks return an indicator** and leave the reason in `imoq_lastError()`.
  Setup mistakes send escape message IMQ0300 instead.
- **Needs IBM i 7.4 TR5 or later,** for `OVERLOAD`.
- **For RPGUnit,** `IMOQRU_H` wraps the checks in `assert`; see the
  [Programmer's Guide](PROGRAMMERS_GUIDE.md#rpgunit-assertions).

### EXAMPLES: run every example

[`EXAMPLES`](../examples/QCLLESRC/EXAMPLES.clle)

`EXAMPLES` compiles each driver, calls it, and writes `ok` or `FAIL` to the job
log. It's a plain list of `CALL`s, and it's the place to add a new example.

---

## The end-to-end demo

The feature examples call mocks directly. The demo shows the real-world shape:
a service program under test (`DEMOCUT`) calls a program (`DEMODEP`) and a
service program (`DEMOSRV`). The tests (`DEMOCUT_T`) replace both dependencies
with mocks and test `DEMOCUT` itself.

| Member | Role |
|---|---|
| [`DEMOCUT`](../examples/QRPGLESRC/DEMOCUT.rpgle) | Code under test: order total = amount + tax |
| [`DEMODEP`](../examples/QRPGLESRC/DEMODEP.rpgle) | Real customer lookup program, mocked in the tests |
| [`DEMOSRV`](../examples/QRPGLESRC/DEMOSRV.rpgle) | Real tax service program, mocked strict in the tests |
| [`DEMOCUT_T`](../examples/QRPGLESRC/DEMOCUT_T.rpgle) | Tests for `DEMOCUT` |
| [`IMOQDEMO`](../examples/QCLLESRC/IMOQDEMO.clle) | Driver: builds the real objects, creates the mocks, runs the tests, checks library list and binding problems, cleans up |

Run it with `CALL IMOQ/IMOQDEMO PARM('IMOQ')`. The
[Programmer's Guide](PROGRAMMERS_GUIDE.md#4-your-first-mocked-test) walks
through the same scenario step by step.

## Writing your own test

1. **Pick an example.** Choose the one closest to what you need, and copy both
   its driver and its `_T` test program.
2. **Driver:** replace the mock commands with mocks of your real dependencies,
   and bind your code under test into the test program. If those dependencies
   exist in your library, put that library after QTEMP first (see `IMOQDEMO`).
3. **Test program:** replace the example's prototypes with your own code's
   prototypes, and `expect()` with your test framework's assertions (for example
   RPGUnit's `assert`).
4. **Keep the order:** reset → stub → call → assert → verify.
