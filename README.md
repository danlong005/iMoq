<p align="center">
  <img src="docs/images/imoq-logo.svg" alt="iMoq" width="480">
</p>

# iMoq

**iMoq** is a mocking framework for RPG unit tests on IBM i, in the spirit of
Mockito and Moq.

Your CL test driver runs a few commands. They replace the programs and service
programs your code calls with **mocks in QTEMP**, or in a library you choose.
Your tests decide what those mocks return, check how they were called, and
remove them when done. It needs no changes to the code under test, and no real
customers, tax tables or files.

```
IMOQPGM    OBJ(CUSTLKUP) PARMS((*CHAR 10) (*CHAR 50) (*IND))
IMOQWHEN   OBJ(CUSTLKUP) ARGS((1 *EQ C001)) SETPARM((2 'ACME') (3 '1'))
   ... run the code under test ...
IMOQVERIFY OBJ(CUSTLKUP) ARGS((1 *EQ C001)) TIMES(*ONCE)
IMOQRMV
```

## Features

- **Mocks for `*PGM` and `*SRVPGM` dependencies.** A service program mock
  either copies the real object's exports and signatures, or is defined entirely
  by commands. Either way you don't write any stub source: no binder source and
  no dummy programs.
- **Stubbing:**
  - return values, output parameters and escape messages
  - argument matchers (`*EQ`, `*GT`, `*LIKE`, `*OMIT`, …)
  - consecutive answers and `TIMES(n)` limits
  - loose or strict mocks
  - data structure subfields, array elements and data structure return
    values, each matched and set by its own type
- **Verification:** exact, at-least, at-most and never counts,
  `IMOQNOMORE`, unused-stub detection (`IMOQUNUSED`) and argument capture.
  Failure messages list the calls that actually happened.
- **No recompiles between tests.** Stubs are stored as data, so you create
  mocks once per driver and restub them in every test.
- **Works from CL and RPG.** The commands run in CL drivers. RPGUnit (or any
  RPG) tests use the `IMOQ_H` copybook, whose RPG API takes typed values
  instead of command strings.
- **Mocks in QTEMP or any library.** Mocks go in QTEMP by default, so they
  disappear with the job. `IMOQPGM` and `IMOQSRVPGM` take `LIB(name)` to create
  them in another library instead. iMoq never replaces a real object: it only
  touches objects it created (text `iMoq mock`). See
  [Creating mocks in another library](docs/PROGRAMMERS_GUIDE.md#creating-mocks-in-another-library).
- **Built-in safety checks.** iMoq tells you when a mock would be ignored
  because the library list or a hard-coded binding bypasses it.

## Quick start

On the IBM i (IBM i 7.4 or later):

```
git clone https://github.com/danlong005/imoq.git /home/ME/imoq

CRTBNDCL PGM(QTEMP/BUILD) SRCSTMF('/home/ME/imoq/QCLLESRC/BUILD.clle')
CALL     QTEMP/BUILD PARM('IMOQ' '/home/ME/imoq' '*YES')
```

`BUILD` creates the library and its source files, copies the repository into
source members, compiles everything, and (with `'*YES'`) runs the self-tests.
Then add library `IMOQ` to your test driver's library list, and bind your test
programs to service program `IMOQ/IMOQENG`.

A test in RPG looks like this:

```rpgle
dcl-proc test_total_adds_tax export;
  dcl-s name char(50);
  dcl-s h int(10);
  dcl-s v int(10);

  h = imoq_when('TAXSRV' : 'CALCTAX');
  imoq_returns(h : 6.00);

  aEqual('106.00' : %char(order_total('C001' : 100 : 'PA' : name)));

  v = imoq_verify('TAXSRV' : 'CALCTAX');
  imoq_with(v : 2 : IMOQ_EQ : 'PA');
  assert(imoq_calledOnce(v) : imoq_lastError());
end-proc;
```

The RPG API's typed calls need IBM i 7.4 TR5 or later. On any release, tests can
also run the commands themselves:
`imoq('IMOQWHEN OBJ(TAXSRV) PROC(CALCTAX) RETURN(''6.00'')')`.

## Documentation

New to mocking on IBM i? Start with the **[Examples](docs/EXAMPLES.md)**:
about twenty short programs, each showing one feature, with the key code
explained.

The **[Programmer's Guide](docs/PROGRAMMERS_GUIDE.md)** covers everything:
- how mocks replace real objects, and the rules that make that work
- installing and rebuilding
- a step-by-step first test
- stubbing and verification recipes
- writing tests in RPG
- troubleshooting and messages
- a command reference

## Repository layout

The repository is laid out like an IBM i library: each folder is a source
physical file.

| Folder | Contents |
|---|---|
| `QRPGLESRC` | Engine (`IMOQENG`, `IMOQGEN`, `IMOQCDC`, `IMOQAPI`), copybooks `IMOQ_H`, `IMOQRU_H` and `IMOQENG_H` |
| `QCLLESRC` | `BUILD`, the `IMOQINST` installer, command processing programs `IMQ*C` |
| `QCMDSRC` | Command definitions `IMOQPGM` … `IMOQCHK` |
| `QSRVSRC` | Binder source for `IMOQENG` |
| `examples` | Example code ([documented here](docs/EXAMPLES.md)), in the same source-file folders (`QRPGLESRC`, `QCLLESRC`, `QSRVSRC`) |
| `docs` | Programmer's Guide and Examples |
| `tools` | `pub400-build.sh`: the maintainer's build-and-test run on pub400. It clears its build library first, so point `LIB` at scratch space only |

The engine's unit tests, `IMOQTEST` and `IMOQENG_T` (with the `IMOQTST_H`
harness), stay with the library code. The `examples` folder holds two kinds of
example:
- **Feature examples:** one feature each, as a test program `EX…_T` (RPG)
  plus a small CL driver `EX…` that creates the mocks and runs it. Most run
  the commands through `imoq()`; `EXAPI` shows the whole RPG API. `EXAMPLES`
  runs them all.
- **End-to-end demo:** code under test `DEMOCUT`, its dependencies `DEMODEP`
  and `DEMOSRV`, tests `DEMOCUT_T`, and driver `IMOQDEMO`.

`BUILD` copies and runs the examples only when you pass `'*YES'`.

## License

iMoq is released under the [MIT License](LICENSE).
