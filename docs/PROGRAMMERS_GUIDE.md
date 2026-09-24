<p align="center">
  <img src="images/imoq-logo.svg" alt="iMoq" width="360">
</p>

# iMoq Programmer's Guide

iMoq gives your CL test driver commands that put stand-in objects in QTEMP. The code under test calls those stand-ins instead of the real programs. Your tests then decide what they answer and check how they were called.

| | |
|---|---|
| Commands and engine | `IMOQ*` commands, service program `IMOQENG` |
| Copybooks for RPG tests | `IMOQ_H` (RPG API), `IMOQRU_H` (RPGUnit assertions) |
| Requires | IBM i 7.4 or later; the RPG API's typed calls need 7.4 TR5 or later |
| Examples | [One short example per feature](EXAMPLES.md) |
| Project | [imoq on GitHub](../README.md) |

## Contents

1. [The big picture](#1-the-big-picture)
2. [Installing iMoq](#2-installing-imoq)
3. [Four rules](#3-four-rules)
4. [Your first mocked test](#4-your-first-mocked-test)
5. [Describing parameters](#5-describing-parameters)
6. [Stubbing recipes](#6-stubbing-recipes)
7. [Verifying calls](#7-verifying-calls)
8. [Writing tests in RPG](#8-writing-tests-in-rpg)
9. [Test isolation](#9-test-isolation)
10. [Troubleshooting](#10-troubleshooting)
11. [Limitations](#11-limitations)
12. [Quick reference](#12-quick-reference)

---

## 1. The big picture

A unit test should exercise one piece of code. When `ORDERSRV` calls the customer lookup program `CUSTLKUP` and the tax service program `TAXSRV`, a real test run needs real customers and real tax tables. With mocks, you replace both dependencies with objects you control:

- **Mock:** a stand-in object with the same name as the real one, created in `QTEMP`.
- **Stub:** a rule for what the mock does when it's called, such as returning `6.00`, filling an output parameter, or throwing an escape message.
- **Verification:** a check, after the code runs, that the mock was called the expected number of times with the expected arguments.

Everything happens in **one job**, driven by a CL program:

| Step | What | Commands |
|---|---|---|
| 1 | Set the library list | `CHGCURLIB *CRTDFT`, `ADDLIBLE MYLIB *LAST` |
| 2 | Create mocks | `IMOQPGM`; `IMOQSRVPGM` + `IMOQPROC` + `IMOQBUILD` |
| 3 | Compile code and tests | `CRTSRVPGM … BNDSRVPGM((*LIBL/TAXSRV))`, `RUCRTRPG` |
| 4 | Run tests | `RUCALLTST` (tests use `IMOQWHEN` / `IMOQVERIFY`) |
| 5 | Clean up | `IMOQRMV` |

The order matters: mocks must exist before anything that uses them is activated.

### Why the mocks get called instead of the real objects

| Dependency | When IBM i finds it | What the mock needs |
|---|---|---|
| `*PGM`, called with `CALLP` + `EXTPGM` or CL `CALL` | At the first call, by searching the library list | QTEMP searched before the library that holds the real program |
| `*SRVPGM` procedure | When the calling program is activated, from the library saved at bind time | The caller bound through `*LIBL`, and a matching signature: bind the caller after `IMOQBUILD`, or use `SRCFILE(*RTV)` to copy the real object's signatures. |

Stubs are stored as rows in QTEMP tables, not compiled into the mock. You create a mock *once* per driver, and each test can change what it answers without recompiling.

### What happens on each call

Every stub hands the call to `IMOQ_INVOKE` in service program `IMOQENG`:

1. The arguments are recorded in `QTEMP/IMOQ_CALL` and `QTEMP/IMOQ_CARG`, as they arrived.
2. The newest `IMOQWHEN` whose argument matchers accept the call, and that still has uses left, is chosen.
3. Its answer is applied: `SETPARM` writes output parameters, `RETURN` sets the return value, and `THROW` sends an escape message to the caller. With no matching stub, a loose mock does nothing and a strict mock throws.

---

## 2. Installing iMoq

iMoq needs IBM i 7.4 or later; it was built and tested on 7.5. It doesn't need RPGUnit, but works well with it.

### Build from the repository

1. Put the repository in the IFS, for example with git in PASE:
   ```
   git clone https://github.com/danlong005/imoq.git /home/ME/imoq
   ```
   Or download it and copy the `QRPGLESRC`, `QCLLESRC`, `QCMDSRC` and `QSRVSRC` folders to the IFS.
2. Compile the build program straight from the IFS:
   ```
   CRTBNDCL PGM(QTEMP/BUILD) SRCSTMF('/home/ME/imoq/QCLLESRC/BUILD.clle')
   ```
3. Run it, naming the library to build into and the repository directory:
   ```
   CALL QTEMP/BUILD PARM('IMOQ' '/home/ME/imoq')
   CALL QTEMP/BUILD PARM('IMOQ' '/home/ME/imoq' '*YES')
   ```

`BUILD` does the following:

1. Creates the library if it doesn't exist, plus the source files `QRPGLESRC`, `QCLLESRC`, `QCMDSRC` and `QSRVSRC`.
2. Copies every file into a member of the same name, using the extension as the source type (`IMOQENG.sqlrpgle` becomes member `IMOQENG`, type `SQLRPGLE`). The copy is logged to `build.log` in the repository directory.
3. Compiles and runs `IMOQINST`, which builds everything.
4. With `'*YES'` as the third parameter, also runs the self-tests.

- **Long paths:** a quoted `CALL` parameter is only reliable up to 32 characters. For a longer path, run `CHGCURDIR DIR('/the/long/path/imoq')` and pass `'*CURDIR'`, which is also the default.
- **Library creation:** `BUILD` creates the library only if you're authorized to `CRTLIB`. Otherwise, build into an existing library.

### What gets built

| Object | Purpose |
|---|---|
| `IMOQPGM` … `IMOQCHK` `*CMD` | The commands |
| `IMQ*C` `*PGM` | Their CL command processing programs |
| `IMOQENG` `*SRVPGM` (activation group `IMOQ`) | Engine: stub runtime, matchers, verification, source generation |
| `IMOQMSGF` `*MSGF` | `IMQnnnn` messages |

To use iMoq, a test driver needs the library in its library list (anywhere; it holds nothing that gets mocked), and test programs bind service program `IMOQENG`. Copy `IMOQ_H` from its `QRPGLESRC` into your tests, and `IMOQRU_H` too if you want the RPGUnit assertions.

### Rebuild after changing the source

If you edit members in the library (with RDi or SEU, for example), rebuild with:

```
CALL IMOQ/IMOQINST PARM('IMOQ')
```

An optional second parameter names a different library holding the four source files.

### Self-tests

| Driver | Tests | What it covers |
|---|---|---|
| `IMOQTEST` | `IMOQENG_T` | Value conversion for every type, rejected values, decimal data errors, matchers |
| `EXAMPLES` (from `examples/`) | Drivers `EXPGM` … `EXERRMSG` (test programs `EX…_T`), `EXCL` | One small example per feature; see [Examples](EXAMPLES.md) |
| `IMOQDEMO` (from `examples/`) | `DEMOCUT_T` with `DEMOCUT`, `DEMODEP`, `DEMOSRV` | End to end: hidden-mock detection, program and strict service program mocks, stubs, throws, consecutive returns, argument capture, verification messages, the CL-only commands, bad-binding detection, cleanup |

Run them with `BUILD` and `'*YES'`, which also copies the example source from the repository's `examples` folder into the library. After a build, you can also run them with `CALL IMOQ/IMOQTEST PARM('IMOQ')`, `CALL IMOQ/IMOQDEMO PARM('IMOQ')` and `CALL IMOQ/EXAMPLES PARM('IMOQ')`. Each sends a diagnostic message per test to the job log and ends with a completion message, or with an escape message giving the number of failures. `IMOQDEMO` and `EXAMPLES` change the current library and library list of the job that runs them.

---

## 3. Four rules

Almost every "the real program ran anyway" problem breaks one of these rules. iMoq checks the first two for you.

### Rule 1: QTEMP must come first

The system portion, product libraries and **the current library** are searched *before* QTEMP. Build scripts and job descriptions often make the development library `*CURLIB`. In a test driver, move it below QTEMP first. Otherwise `IMOQPGM` and `IMOQBUILD` stop with **IMQ0010**.

```
CHGCURLIB  CURLIB(*CRTDFT)
ADDLIBLE   LIB(MYLIB) POSITION(*LAST)
```

### Rule 2: Bind service programs through `*LIBL`

Code under test bound with `BNDSRVPGM((MYLIB/TAXSRV))` always activates `MYLIB/TAXSRV`. Use `BNDSRVPGM((*LIBL/TAXSRV))`, or a binding directory entry whose library is `*LIBL`. `IMOQCHK PGM(MYLIB/ORDERSRV)` reports bad bindings as **IMQ0021**.

### Rule 3: Create mocks before activation

A program that has already activated the real `TAXSRV` keeps using it until its activation group ends. Create every mock before the first call into the code under test. RPGUnit test programs usually run in `*NEW`, so each `RUCALLTST` starts clean.

### Rule 4: One job

QTEMP belongs to a job. Creating mocks in one SSH session and running tests in another won't work. Put the mocks, compiles and test runs in a single CL driver, and run that driver.

---

## 4. Your first mocked test

The walkthrough uses a small order-pricing service. The same scenario ships as a runnable example in the repository's `examples` folder: `DEMOCUT`, `DEMODEP`, `DEMOSRV` and `DEMOCUT_T` in `examples/QRPGLESRC`, driver `IMOQDEMO` in `examples/QCLLESRC`. `BUILD` with `'*YES'` copies it into the library, and then `CALL IMOQ/IMOQDEMO` shows it passing.

### Step 1: Read the code under test

`ORDERSRV` looks the customer up with a program call, then adds tax from a bound procedure. Note each dependency's parameter list; you'll describe those next.

```rpgle
dcl-pr custLkup extpgm('CUSTLKUP');
  custId   char(10) const;
  custName char(50);
  found    ind;
end-pr;

dcl-pr calcTax packed(11:2) extproc('CALCTAX');
  amount packed(11:2) const;
  state  char(2) const;
end-pr;

dcl-proc order_total export;
  dcl-pi *n packed(11:2);
    custId char(10) const; amount packed(11:2) const;
    state char(2) const;   custName char(50);
  end-pi;
  dcl-s found ind inz(*off);

  monitor;
    custLkup(custId : custName : found);
  on-error;
    return -2;                 // lookup failed
  endmon;
  if not found;
    return -1;                 // unknown customer
  endif;
  return amount + calcTax(amount : state);
end-proc;
```

### Step 2: Write the driver and create the mocks

`IMOQPGM` needs the program's parameter layout. `IMOQSRVPGM` starts a service program mock; by default it needs no real object or binder source. `IMOQPROC` declares each procedure the code under test calls, and `IMOQBUILD` creates the object. The code under test is compiled in the next step, after `IMOQBUILD`, so it binds to the mock.

```
             PGM
             CHGJOB     INQMSGRPY(*DFT)
             CHGCURLIB  CURLIB(*CRTDFT)
             ADDLIBLE   LIB(MYLIB) POSITION(*LAST)
             ADDLIBLE   LIB(RPGUNIT) POSITION(*LAST)

/* Mocks: before anything is compiled against or activated */
             IMOQPGM    OBJ(CUSTLKUP) +
                          PARMS((*CHAR 10) (*CHAR 50) (*IND))
             IMOQSRVPGM OBJ(TAXSRV) BEHAVIOR(*STRICT)
             IMOQPROC   OBJ(TAXSRV) PROC(CALCTAX) +
                          RTNTYPE(*PACKED 11 2) +
                          PARMS((*PACKED 11 2 *CONST) (*CHAR 2 *CONST))
             IMOQBUILD  OBJ(TAXSRV)
```

### Step 3: Compile the code under test and the tests

Bind the service program through `*LIBL`, check with `IMOQCHK`, and bind the test program to `IMOQENG` so it can use `IMOQ_H`.

```
             CRTRPGMOD  MODULE(QTEMP/ORDERSRV) SRCFILE(MYLIB/QRPGLESRC)
             CRTSRVPGM  SRVPGM(MYLIB/ORDERSRV) MODULE(QTEMP/ORDERSRV) +
                          EXPORT(*ALL) BNDSRVPGM((*LIBL/TAXSRV))
             IMOQCHK    PGM(MYLIB/ORDERSRV)

             RUCRTRPG   TSTPGM(MYLIB/ORDERSRV_T) SRCFILE(MYLIB/QRPGLESRC) +
                          BNDSRVPGM(MYLIB/ORDERSRV MYLIB/IMOQENG)
             RUCALLTST  TSTPGM(MYLIB/ORDERSRV_T)

             IMOQRMV
             ENDPGM
```

### Step 4: Write a test (stub, act, assert, verify)

Each test resets the mocks, says what they should answer, calls the code, then checks the result and the calls.

```rpgle
**free
ctl-opt nomain;
/include RPGUNIT/RPGUNIT1,TESTCASE
/copy MYLIB/QRPGLESRC,IMOQ_H
/copy MYLIB/QRPGLESRC,ORDERSRV_H

dcl-proc SETUP export;
  imoq_reset();                      // no stubs or calls left from earlier tests
end-proc;

dcl-proc test_total_adds_tax_for_known_customer export;
  dcl-s name char(50);
  dcl-s h int(10);
  dcl-s v int(10);

  // arrange
  h = imoq_when('CUSTLKUP');
  imoq_with(h : 1 : IMOQ_EQ : 'C001');
  imoq_setParm(h : 2 : 'ACME CORP');
  imoq_setParm(h : 3 : '1');

  h = imoq_when('TAXSRV' : 'CALCTAX');
  imoq_returns(h : 6.00);

  // act + assert
  aEqual('106.00' : %char(order_total('C001' : 100 : 'PA' : name)));
  aEqual('ACME CORP' : name);

  // verify
  v = imoq_verify('TAXSRV' : 'CALCTAX');
  imoq_with(v : 1 : IMOQ_EQ : 100);
  imoq_with(v : 2 : IMOQ_EQ : 'PA');
  assert(imoq_calledOnce(v) : imoq_lastError());
end-proc;
```

Each `imoq_…` call takes RPG values, so there are no command strings to build. The same test can also run the `IMOQWHEN` and `IMOQVERIFY` commands through `imoq()`; see [Writing tests in RPG](#8-writing-tests-in-rpg).

### Step 5: Run the driver and read the result

Compile and call the driver in one job, for example `CALL MYLIB/ORDERDRV` from a 5250 session or with `SBMJOB CMD(CALL MYLIB/ORDERDRV)`. When a verification fails, `assert` reports iMoq's explanation:

```
Verification failed: expected TAXSRV.CALCTAX to be called exactly 1 time(s)
with (1 *EQ '100', 2 *EQ 'PA') but it matched 0 time(s).
Recorded calls: #7('100.00', 'NJ')
```

---

## 5. Describing parameters

iMoq doesn't read prototypes. You describe each parameter as `(type length decimals)`, plus a passing style for service program procedures. Copy the layout straight from the prototype:

| RPG declaration | `IMOQPGM PARMS` / `RTNTYPE` | `IMOQPROC PARMS` |
|---|---|---|
| `char(10)` | `(*CHAR 10)` | `(*CHAR 10)` |
| `char(10) const` | `(*CHAR 10)` | `(*CHAR 10 *CONST)` |
| `varchar(50)` | `(*VARCHAR 50)` | `(*VARCHAR 50)` |
| `packed(11:2) const` | `(*PACKED 11 2)` | `(*PACKED 11 2 *CONST)` |
| `zoned(7:0)` | `(*ZONED 7 0)` | `(*ZONED 7 0)` |
| `int(10) value` | n/a (programs pass by reference) | `(*INT 10 0 *VALUE)` |
| `uns(5)` / `float(8)` | `(*UNS 5)` / `(*FLOAT 8)` | same |
| `ind` | `(*IND)` | `(*IND)` |
| `date` / `time` / `timestamp` (*ISO) | `(*DATE)` `(*TIME)` `(*TIMESTAMP)` | same |
| `pointer` | `(*PTR)` | `(*PTR)` |
| `likeds(cust_t)` (all-character subfields) | `(*CHAR 120)` using `%size(cust_t)` | same |

### Things to know

- **The passing style can go in the decimals slot.** `(*CHAR 2 *CONST)` and `(*PACKED 11 2 *CONST)` both work. The full form is `(*CHAR 2 0 *CONST)`.
- **You only need to declare what you use.** A program mock records extra parameters as `*UNDECLARED`. You can still use `*ANY`, `*OMIT` and `*NOTPASSED` matchers on them, but not value matchers or `SETPARM`.
- **Declare every export whose return value matters.** A service program export without `IMOQPROC` gets a stub with no parameters and no return value. It records calls and can throw, but a caller that reads its return value gets unpredictable data.
- **Data structures:** describe a DS parameter as one `*CHAR` of its size. Matching and `SETPARM` then work on the whole record as text, which only makes sense when the subfields are character.
- **Export names:** `PROC` is matched exactly first, then case-insensitively. RPG exports are uppercase unless the prototype uses `EXTPROC(*DCLCASE)` or a quoted name.
- **Changed an interface?** Run `IMOQPROC` again, then `IMOQBUILD`. Stubs alone never need a rebuild.
- **Where the exports come from.** `IMOQSRVPGM SRCFILE` chooses the source of the export list:

  | `SRCFILE` | Exports | Signature | Needs |
  |---|---|---|---|
  | `*NONE` (default) | Exactly the procedures you declare with `IMOQPROC` | `SIGNATURE(*GEN)` (default) or `SIGNATURE('text')` | Nothing: no real object, no binder source |
  | `*RTV` | Every export of the real service program, retrieved with `RTVBNDSRC` | The real object's signatures, so already-bound programs activate the mock | The real `*SRVPGM` in the library list |
  | `lib/file` + `SRCMBR` | The `*CURRENT` block of that binder source; every `*PRV` block is kept | From the binder source | A binder source member |

  With `*NONE`, programs that use the mock must be bound after `IMOQBUILD` (they bind to the mock itself), and the names you give `PROC` are the exact export symbols, which are usually uppercase. Use `*RTV` when the code under test is already compiled against the real service program and you don't want to rebind it.

---

## 6. Stubbing recipes

Every recipe is an `IMOQWHEN` command, written here as you'd write it in CL. From RPG, build the same stub with the [RPG API](#8-writing-tests-in-rpg): each keyword has a matching call, such as `ARGS` → `imoq_with` and `RETURN` → `imoq_returns`.

Values are checked against the declared layout when `IMOQWHEN` runs, so a mistake such as `RETURN('12345678901.99')` for `*PACKED 11 2` fails right away with **IMQ0014** instead of at call time.

### Return a value

Service program procedures with a declared `RTNTYPE`:

```
IMOQWHEN OBJ(TAXSRV) PROC(CALCTAX) RETURN('6.00')
```

### Fill output parameters

This is how program mocks "answer": they write into the caller's variables.

```
IMOQWHEN OBJ(CUSTLKUP) SETPARM((2 'ACME CORP') (3 '1'))
```

Values are text, converted to the declared type: `'12.50'` for packed, `'1'`/`'0'` or `'*ON'`/`'*OFF'` for indicators, `'2026-09-13'` for dates. Parameters passed `*VALUE` or `*OMIT` can't be set.

### Answer only for certain arguments

```
IMOQWHEN OBJ(TAXSRV) PROC(CALCTAX) ARGS((2 *EQ NY)) RETURN('8.88')
IMOQWHEN OBJ(TAXSRV) PROC(CALCTAX) ARGS((1 *GT 1000)) RETURN('99.00')
IMOQWHEN OBJ(CUSTLKUP) ARGS((1 *LIKE 'C_9%')) SETPARM((3 '1'))
```

The matchers are `*EQ` (default), `*NE`, `*GT`, `*GE`, `*LT`, `*LE`, `*LIKE` (`%` any text, `_` one character), `*BLANK` (blanks, or zero for numbers), `*ANY`, `*OMIT` and `*NOTPASSED`. Numeric parameters compare as numbers, so `100` matches `100.00`. Character comparisons ignore trailing blanks. All matchers in one `ARGS` must match.

### A default answer plus special cases

The newest matching stub wins.

```
IMOQWHEN OBJ(TAXSRV) PROC(CALCTAX) RETURN('5.00')                  /* default  */
IMOQWHEN OBJ(TAXSRV) PROC(CALCTAX) ARGS((2 *EQ NY)) RETURN('8.88') /* override */
```

iMoq checks stubs from newest to oldest and uses the first one that matches and has uses left. Define broad stubs first (for example in `SETUP`) and narrow ones in the test.

### Different answers on successive calls

```
IMOQWHEN OBJ(TAXSRV) PROC(CALCTAX) RETURN('1.00' '2.00')
/* calls return 1.00, 2.00, 2.00, 2.00 ... */
```

The last value repeats. Use this for retry loops and paging. You can list up to 32 values.

### Answer only a limited number of times

```
IMOQWHEN OBJ(CUSTLKUP) SETPARM((3 '1')) TIMES(1)
/* first call: found; later calls fall through to older stubs or the default behavior */
```

### Simulate a failure

`THROW` sends an escape message to the caller.

```
IMOQWHEN OBJ(CUSTLKUP) THROW(CPF9898 QCPFMSG *LIBL 'Customer DB down')
IMOQWHEN OBJ(TAXSRV) PROC(CALCTAX) THROW(*MOCK *MOCK *LIBL 'rate table locked')
```

The code under test sees an ordinary escape message, so `MONITOR` and `MONMSG` behave exactly as in production. `THROW` takes **one** set of parentheses. `*MOCK` sends **IMQ0101**.

### Fail on any call you didn't expect

Use `BEHAVIOR(*STRICT)` on `IMOQPGM` or `IMOQSRVPGM`.

A `*LOOSE` mock (the default) answers an unmatched call by leaving parameters untouched and returning zero or blanks. A `*STRICT` mock sends **IMQ0100** `Unexpected call to TAXSRV.CALCTAX('100.00', 'TX')`, which fails the test at the call that shouldn't have happened.

---

## 7. Verifying calls

Every call to a mock is recorded with a snapshot of its arguments as they arrived. Verification checks that record.

```
IMOQVERIFY OBJ(TAXSRV) PROC(CALCTAX) TIMES(*ONCE)
IMOQVERIFY OBJ(TAXSRV) PROC(CALCTAX) TIMES(*NEVER)
IMOQVERIFY OBJ(TAXSRV) PROC(CALCTAX) ARGS((2 *EQ PA)) TIMES(*EXACTLY 3)
IMOQVERIFY OBJ(CUSTLKUP) ARGS((1 *LIKE 'C%')) TIMES(*ATLEAST 1)
IMOQVERIFY OBJ(CUSTLKUP) TIMES(*ATMOST 2)
IMOQNOMORE                    /* every recorded call has been verified */
```

| Command | What it does |
|---|---|
| `IMOQVERIFY` | Sends **IMQ0200** when the count of matching calls is wrong. On success, the matching calls are marked verified. |
| `IMOQNOMORE` | Sends **IMQ0201** listing any call no successful `IMOQVERIFY` covered. Use it to catch surprise interactions. |
| `IMOQGETARG` | Returns one captured argument to a CL variable (`*CHAR 256`). Use `CALL(*FIRST\|*LAST\|n)`. |
| `IMOQCOUNT` | Returns the number of matching calls to a CL variable (`*DEC 10 0`). |

### Capturing arguments

When a matcher can't express the check, for example a computed value, capture the argument and assert on it.

From an RPG test:

```rpgle
aEqual('25.50' : imoq_arg('TAXSRV' : 'CALCTAX' : IMOQ_LAST : 1));
assert(imoq_argNum('TAXSRV' : 'CALCTAX' : IMOQ_LAST : 1) = 25.5);
iEqual(2 : imoq_count('CUSTLKUP' : IMOQ_PGM));
```

From a CL driver:

```
             DCL        VAR(&ARG) TYPE(*CHAR) LEN(256)
             DCL        VAR(&CNT) TYPE(*DEC) LEN(10 0)
             IMOQGETARG OBJ(CUSTLKUP) PARM(1) CALL(*LAST) RTNVAL(&ARG)
             IMOQCOUNT  OBJ(CUSTLKUP) RTNVAL(&CNT)
             IMOQVERIFY OBJ(CUSTLKUP) TIMES(*NEVER)
             MONMSG     MSGID(IMQ0200) EXEC(GOTO FAILED)
```

Captured values are text: numbers are normalized (`25.50`, `-1`), trailing blanks are removed, and missing arguments come back as `*OMIT` or `*NOTPASSED`.

---

## 8. Writing tests in RPG

Copy `IMOQ_H` into the test module and bind service program `IMOQENG`. For a complete working example, see `examples/QRPGLESRC/DEMOCUT_T.rpgle` (driven by `examples/QCLLESRC/IMOQDEMO.clle`), and [EXAPI](EXAMPLES.md#exapi-everything-the-rpg-api-can-do) for every procedure, one topic at a time.

RPG tests stub and verify through **handles**. `imoq_when` and `imoq_verify` return a handle, and each later call adds one piece to it. Values are ordinary RPG values: numbers, dates, times and timestamps are passed as they are, and text needs no doubled quotes. `imoq_with`, `imoq_returns` and `imoq_setParm` use `OVERLOAD`, which needs **IBM i 7.4 TR5 or later**.

```rpgle
// stub: when TAXSRV.CALCTAX gets 100 and 'PA', return 6.00
h = imoq_when('TAXSRV' : 'CALCTAX');
imoq_with(h : 1 : IMOQ_EQ : 100);
imoq_with(h : 2 : IMOQ_EQ : 'PA');
imoq_returns(h : 6.00);

// verify: CUSTLKUP was called once with 'C001'
v = imoq_verify('CUSTLKUP');
imoq_with(v : 1 : IMOQ_EQ : 'C001');
assert(imoq_calledOnce(v) : imoq_lastError());
```

### Stubbing

| Procedure | What it does | Command equivalent |
|---|---|---|
| `h = imoq_when(obj : proc)` | Starts a stub and returns its handle. Omit `proc` for a program mock. The stub answers calls straight away | `IMOQWHEN OBJ PROC` |
| `imoq_with(h : parmNo : matcher : value)` | Adds an argument matcher. `IMOQ_ANY`, `IMOQ_BLANK`, `IMOQ_OMIT` and `IMOQ_NOTPASSED` take no value | `ARGS((n matcher value))` |
| `imoq_returns(h : value)` | Adds a return value. Call it again for a series: one value per call, and the last one repeats | `RETURN(v …)` |
| `imoq_setParm(h : parmNo : value)` | Fills an output parameter | `SETPARM((n value))` |
| `imoq_throws(h : msgId : msgDta : msgf : msgfLib)` | Sends an escape message instead of answering. `msgId` `IMOQ_MOCK` sends **IMQ0101**; for another message ID, pass its message file (`msgfLib` defaults to `*LIBL`) | `THROW(…)` |
| `imoq_times(h : n)` | Answers only `n` calls (default `IMOQ_ALWAYS`) | `TIMES(n)` |

Matcher constants are `IMOQ_EQ`, `IMOQ_NE`, `IMOQ_GT`, `IMOQ_GE`, `IMOQ_LT`, `IMOQ_LE`, `IMOQ_LIKE`, `IMOQ_BLANK`, `IMOQ_ANY`, `IMOQ_OMIT` and `IMOQ_NOTPASSED`. They work exactly like the command matchers in [Stubbing recipes](#6-stubbing-recipes).

Every call checks its piece against the declared layout and saves the stub again. When a call fails, the stub keeps its earlier pieces and keeps answering.

### Verifying

| Procedure | Returns | Command equivalent |
|---|---|---|
| `v = imoq_verify(obj : proc)` | A verification handle. Add matchers with `imoq_with(v : …)` | – |
| `imoq_calledOnce(v)` / `imoq_neverCalled(v)` | `*on` if the count is right | `IMOQVERIFY TIMES(*ONCE)` / `TIMES(*NEVER)` |
| `imoq_calledTimes(v : n)` · `imoq_calledAtLeast(v : n)` · `imoq_calledAtMost(v : n)` | `*on` if the count is right | `TIMES(*EXACTLY n)` · `*ATLEAST` · `*ATMOST` |
| `imoq_matchCount(v)` | The number of matching calls. Unlike the checks, it doesn't mark them verified | `IMOQCOUNT` |
| `imoq_noMoreCalls(obj)` | `*on` if every recorded call (to `obj`, or to any mock) was verified | `IMOQNOMORE` |
| `imoq_reset(obj : scope)` | Forgets stubs and recorded calls. Both parameters are optional; scope is `IMOQ_ALL`, `IMOQ_CALLS` or `IMOQ_STUBS` | `IMOQRESET` |

A successful check marks the calls it matched as verified, as `IMOQVERIFY` does. A verification handle stays usable until 16 newer `imoq_verify` calls have been made.

### Capturing arguments

| Procedure | Returns |
|---|---|
| `imoq_arg(obj : proc : call : parm)` | The argument as text; `*OMIT` or `*NOTPASSED` for missing ones |
| `imoq_argNum` · `imoq_argDate` · `imoq_argTime` · `imoq_argTimestamp` · `imoq_argInd` | The argument as a `packed(31:9)`, date, time, timestamp or indicator |
| `imoq_argPassed(obj : proc : call : parm)` | `*off` if the argument was `*OMIT` or not passed |
| `imoq_count(obj : proc)` | The number of recorded calls, or `-1` if the mock or procedure is unknown |

`call` is 1 for the first call or `IMOQ_LAST` for the most recent one. `proc` is `IMOQ_PGM` for program mocks.

### When something goes wrong

- **Setup calls** (`imoq_when`, `imoq_with`, `imoq_returns`, `imoq_setParm`, `imoq_throws`, `imoq_times`, `imoq_verify`, `imoq_reset` and the typed `imoq_arg…` procedures) send escape message **IMQ0300** with the reason. RPGUnit reports the test as an error. That includes using a stub handle after `imoq_reset` removed the stub.
- **Checks** (`imoq_called…`, `imoq_neverCalled`, `imoq_noMoreCalls`) return `*off`. `imoq_lastError()` explains why, so pass it to `assert`.

### RPGUnit assertions

`IMOQRU_H` wraps the checks in RPGUnit's `assert`. Copy it after `IMOQ_H`, RPGUnit's `TESTCASE` copybook and the module's own global declarations:

```rpgle
/copy MYLIB/QRPGLESRC,IMOQRU_H
…
v = imoq_verify('TAXSRV' : 'CALCTAX');
imoq_with(v : 2 : IMOQ_EQ : 'PA');
imoq_assertCalledOnce(v);
imoq_assertNoMoreCalls();
```

It provides `imoq_assertCalledOnce`, `imoq_assertCalledTimes`, `imoq_assertCalledAtLeast`, `imoq_assertCalledAtMost`, `imoq_assertNeverCalled` and `imoq_assertNoMoreCalls`.

### Running commands directly

Any `IMOQ*` command also runs from RPG, which works on every supported release:

| Procedure | On failure | Use it for |
|---|---|---|
| `imoq(cmd)` | Sends escape **IMQ0300**; RPGUnit reports the test as an error | Setup: `IMOQWHEN`, `IMOQRESET` |
| `imoq_ok(cmd)` | Returns `*off` | Assertions: `assert(imoq_ok('IMOQVERIFY …') : imoq_lastError())` |
| `imoq_lastError()` | n/a | The message behind the last failure, including strict-mode calls |

### Quoting inside RPG strings

- Command values that contain blanks or lowercase letters need CL quotes, and inside an RPG literal each one is doubled: `SETPARM((2 ''ACME CORP''))`.
- Split long commands with `+` at the end of the line. Leading blanks on the next line are skipped, so leave the space before the `+`.
- Lists of entries use two sets of parentheses: `ARGS((1 *EQ C001) (2 *ANY))`. Single groups use one: `THROW(CPF9898 QCPFMSG *LIBL ''text'')`. If `imoq_lastError()` starts with `CPF0006` (errors in command), check the quotes and parentheses; running the same command from a command line shows the exact problem.

> **Tip: create mocks in CL, stub in RPG.** Creating mocks belongs in the CL driver (it compiles objects). Stubbing and verification usually belong in the test procedure, next to the assertion they support.

---

## 9. Test isolation

| Command | Clears | Keeps | When |
|---|---|---|---|
| `IMOQRESET` | Stubs and recorded calls for all mocks | Mock objects and layouts | In `SETUP`, before every test |
| `IMOQRESET SCOPE(*CALLS)` | Recorded calls | Stubs | Between the arrange and act phases of a long test |
| `IMOQRESET OBJ(TAXSRV) SCOPE(*STUBS)` | One mock's stubs | Everything else | Switching one dependency's behavior |
| `IMOQRMV OBJ(TAXSRV)` | The mock object and its state | Other mocks | The real object is needed again in this job |
| `IMOQRMV` | All mocks, QTEMP tables and generated source | n/a | At the end of the driver |

- Remove mocks *after* the test program has ended. A program still active in the job keeps whatever it activated.
- Rerunning `IMOQPGM` or `IMOQSRVPGM` for an existing name replaces the mock and forgets its stubs and calls.
- If the driver ends without `IMOQRMV`, nothing is left behind: QTEMP is discarded with the job.

### Creating mocks in another library

Mocks go in QTEMP unless you say otherwise. `IMOQPGM` and `IMOQSRVPGM` take `LIB(name)` to create the mock object somewhere else:

```
IMOQPGM    OBJ(CUSTLKUP) PARMS((*CHAR 10) (*CHAR 50) (*IND)) LIB(TESTLIB)
```

- **Safety:** iMoq gives every mock object the text `iMoq mock`, and only replaces or deletes objects with that text. If `TESTLIB` already holds a real `CUSTLKUP`, the command fails with **IMQ0016** instead of overwriting it.
- **Library list:** the mock library must come before the real object's library, just as QTEMP must. `IMOQPGM`, `IMOQBUILD` and `IMOQCHK` check this.
- **Lifetime:** the mock *object* stays in the library after the job ends, but its stubs and recorded calls live in QTEMP and belong to the job. Run `IMOQRMV` at the end of the driver so no mock is left behind for other jobs to call.

---

## 10. Troubleshooting

### Symptoms

| What you see | Likely cause | Fix |
|---|---|---|
| The real program or service program runs | Its library is `*CURLIB` or a product library; a hard-coded binding; or it was activated before the mock existed | Run `IMOQCHK PGM(lib/caller)`, then follow rules 1–3 |
| Stubbed values never show up | The matcher doesn't match what was actually passed | Inspect with `imoq_arg`, or read the recorded calls in the `IMOQVERIFY` message |
| Return value is always zero or blank | No stub matched a `*LOOSE` mock, or the export has no `IMOQPROC` | Declare `RTNTYPE`; use `*STRICT` to catch unmatched calls |
| Signature violation when activating the code under test | It was bound before `IMOQBUILD` (or against another version), so its signature doesn't match the mock | Bind the code under test after `IMOQBUILD`, or create the mock with `SRCFILE(*RTV)` to copy the real object's signatures |
| `imoq()` fails with CPF0006 | Command syntax: quotes or parentheses | See [Quoting inside RPG strings](#quoting-inside-rpg-strings), or use the RPG API, which needs no quoting |
| Job waits on an inquiry message | An unmonitored error in a driver run over SSH | Start drivers with `CHGJOB INQMSGRPY(*DFT)` and a program-level `MONMSG` |

### Messages

| ID | Meaning |
|---|---|
| IMQ0010 | The mock is hidden by an object earlier in the library list |
| IMQ0011 | No mock with that name exists in this job |
| IMQ0012 | Unknown export, a `PROC` given for a program mock, or a data export used as a procedure |
| IMQ0013 | With `SRCFILE(*RTV)` or a binder source member: the real service program or its binder source couldn't be found |
| IMQ0014 | Invalid layout or value, such as an overflow, a bad indicator, or an undeclared parameter |
| IMQ0015 | The stub didn't build. The listing is spooled; the source is in `QTEMP/IMOQSRC` |
| IMQ0016 | The `LIB()` library already holds a real object with the mock's name; iMoq won't replace it |
| IMQ0020 / IMQ0021 | `IMOQCHK` finding / summary |
| IMQ0100 | A strict mock received a call no stub matched |
| IMQ0101 | Sent by `THROW(*MOCK …)` |
| IMQ0200 / IMQ0201 | Verification failed / unverified interactions |
| IMQ0202 | `IMOQGETARG`: no call with that number |
| IMQ0300 | A command run through `imoq()`, or an RPG API setup call, failed; the text explains why |

### Looking inside

A mock's state is kept in ordinary QTEMP tables, which you can query from the driver's job (for example with STRSQL in an interactive session that ran the commands):

```sql
select * from qtemp.imoq_call order by callid;       -- every recorded call
select * from qtemp.imoq_carg where callid = 7;     -- its arguments
select * from qtemp.imoq_stub;                         -- active stubs
select * from qtemp.imoq_sig;                          -- declared layouts
```

---

## 11. Limitations

iMoq replaces a dependency by putting an object with the same name where IBM i looks first: earlier in the library list, or in the service program the caller activates through `*LIBL`. Anything IBM i finds some other way can't be replaced.

### What can't be mocked

| Dependency | Why | What to do instead |
|---|---|---|
| A procedure in a module bound by copy (`CRTPGM MODULE(…)`), or a subprocedure in the same module | It's bound into the caller when the caller is created, so there's no separate object to replace | Move it into a service program bound through `*LIBL`, or test it directly |
| A program called by qualified name: `CALL PGM(MYLIB/CUSTLKUP)`, `EXTPGM('MYLIB/CUSTLKUP')` | IBM i looks only in the named library, never in QTEMP. `IMOQCHK` doesn't detect this | Call the program unqualified, through the library list |
| A service program bound with a library name | The caller always activates the object in that library ([Rule 2](#rule-2-bind-service-programs-through-libl)). `IMOQCHK` reports this as **IMQ0021** | Bind with `BNDSRVPGM((*LIBL/name))` |
| A program or service program in QSYS or a product library, such as `QCMDEXC` or a system API | Those libraries are searched before QTEMP, so the mock would be hidden (**IMQ0010**) | Call it through your own wrapper program or procedure, and mock the wrapper |
| Files, SQL tables, data areas, data queues | They aren't program calls | Put the access in a program or procedure and mock that, or point the test at test data |

### Only the driver's job

Stubs and recorded calls live in QTEMP, so they belong to the job that ran the iMoq commands ([Rule 4](#rule-4-one-job)). Code under test that runs in another job, for example a program it submits with `SBMJOB`, or a server job or data queue listener it sends work to, doesn't see them:

- A mock in QTEMP isn't visible there at all, so the real object runs.
- A mock created with `LIB()` is visible, but finds no stubs in that job. The call does nothing: parameters are left unchanged, and the call isn't recorded, even for a strict mock.

To test that code, call it directly from the driver job.

### Parameters that can't be described exactly

- **Data structures and arrays** are described as one `*CHAR` of their total size. Matchers, `SETPARM` and captured values then treat the whole thing as text, which only makes sense when every subfield or element is character. With packed, zoned or binary subfields, you can still count calls and use `*ANY`, `*OMIT` and `*NOTPASSED`.
- **`*VARCHAR` passed `*VALUE`** isn't supported.
- **Sizes:** up to 64 parameters, command values of at most 256 characters (1,024 through the RPG API), and captured values cut at 1,024 characters. See [Limits](#limits) for the full list.

### Not supported yet

Some things Mockito and Moq can do aren't in iMoq yet. The planned work is tracked in [todo.md](../todo.md).

- **Answers built from the arguments.** Every answer is a fixed value; a stub can't copy an input to an output or call your own procedure.
- **Checking call order.** `IMOQVERIFY` counts calls but can't check that one call came before another.
- **Unused stubs.** A stub that no call matched isn't reported, so a wrong matcher shows up only as a missing answer.
- **Either-or matchers.** All matchers in one `ARGS` must match. For alternatives, define one stub per alternative.

iMoq also never passes a call on to the real object, as a Mockito spy or Moq's `CallBase` would. That's deliberate: a test that can reach the real program can also change real data.

---

## 12. Quick reference

The mock is identified by `OBJ(name)`. Service program mocks also take `PROC(exportName)`; for program mocks, omit `PROC`.

| Command | Key parameters | Mockito / Moq equivalent |
|---|---|---|
| `IMOQPGM` | `OBJ` · `PARMS((type len dec) …)` · `BEHAVIOR(*LOOSE\|*STRICT)` · `LIB(QTEMP\|name)` | `mock(X.class)` / `new Mock<X>(behavior)` |
| `IMOQSRVPGM` | `OBJ` · `BEHAVIOR` · `SRCFILE(*NONE\|*RTV\|lib/file)` · `SRCMBR(*OBJ\|name)` · `SIGNATURE(*GEN\|'text')` · `LIB(QTEMP\|name)` | `mock(X.class)` |
| `IMOQPROC` | `OBJ` · `PROC` · `RTNTYPE(type len dec)` · `PARMS((type len dec\|passing [passing]) …)` | – |
| `IMOQBUILD` | `OBJ` | – |
| `IMOQWHEN` | `OBJ` · `PROC(*PGM\|name)` · `ARGS((n matcher value) …)` · `RETURN(v …)` · `SETPARM((n value) …)` · `THROW(msgid msgf lib data)` · `TIMES(*ALWAYS\|n)` | `when().thenReturn()/thenThrow()` / `Setup().Returns()/Callback()/Throws()` |
| `IMOQVERIFY` | `OBJ` · `PROC` · `ARGS` · `TIMES(*ONCE\|*NEVER\|*EXACTLY n\|*ATLEAST n\|*ATMOST n)` | `verify(m, times(n))` / `Verify(Times)` |
| `IMOQNOMORE` | `OBJ(*ALL\|name)` | `verifyNoMoreInteractions()` / `VerifyNoOtherCalls()` |
| `IMOQGETARG` | `OBJ` · `PARM(n)` · `RTNVAL(&char256)` · `PROC` · `CALL(*LAST\|*FIRST\|n)` · CL programs only | `ArgumentCaptor` |
| `IMOQCOUNT` | `OBJ` · `RTNVAL(&dec10)` · `PROC` · `ARGS` · CL programs only | – |
| `IMOQRESET` | `OBJ(*ALL\|name)` · `SCOPE(*ALL\|*CALLS\|*STUBS)` | `reset()` / `clearInvocations()` |
| `IMOQRMV` | `OBJ(*ALL\|name)` | – |
| `IMOQCHK` | `PGM(*NONE\|lib/name)` | – |

From RPG, the same stubbing and verification is available as the [RPG API](#8-writing-tests-in-rpg):

| RPG API | Command |
|---|---|
| `h = imoq_when(obj : proc)` · `imoq_with` · `imoq_returns` · `imoq_setParm` · `imoq_throws` · `imoq_times` | `IMOQWHEN` |
| `v = imoq_verify(obj : proc)` · `imoq_with` · `imoq_calledOnce` / `imoq_calledTimes` / `imoq_calledAtLeast` / `imoq_calledAtMost` / `imoq_neverCalled` | `IMOQVERIFY` |
| `imoq_matchCount(v)` · `imoq_count(obj : proc)` | `IMOQCOUNT` |
| `imoq_noMoreCalls(obj)` | `IMOQNOMORE` |
| `imoq_arg` · `imoq_argNum` / `Date` / `Time` / `Timestamp` / `Ind` · `imoq_argPassed` | `IMOQGETARG` |
| `imoq_reset(obj : scope)` | `IMOQRESET` |

### Limits

- Up to 64 parameters per program or procedure, 64 `ARGS`/`SETPARM` entries and 32 `RETURN` values. Command values are at most 256 characters; RPG API values up to 1,024.
- Captured argument text is cut at 1,024 characters. Dates and times use ISO format.
- `*VARCHAR` can't be passed `*VALUE`. A data export is mocked as `char(n)` storage of the real size.
- Each stub call runs a few SQL statements against QTEMP. That's fast enough for unit tests, but mocks aren't meant for performance runs.

---

iMoq is developed in the [imoq repository](../README.md). See [Installing iMoq](#2-installing-imoq) to build it and run its self-tests.
