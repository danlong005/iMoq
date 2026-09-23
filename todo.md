# iMoq to-do list

Work still to do on iMoq, from a review of its features and gaps
(2026-09-22). Items are roughly in priority order within each section.

## Next up

- [x] Add a LICENSE file. Without one, the public repository isn't open source
      and nobody can legally reuse it.
- [ ] Add a "Limitations" section to the Programmer's Guide (see
      [Limits of the approach](#limits-of-the-approach)).
- [ ] Add examples for `LIB()`, `*VALUE` passing and the non-character types.
- [ ] Support data structure subfields (see [Features](#features)).
- [ ] Add in-order verification and unused-stub detection.

## Features

- [ ] **Data structure subfields.** A data structure can only be described as
      one `*CHAR`, so packed or zoned subfields can't be matched or set. Let
      `ARGS` and `SETPARM` address a subfield by offset, type and length.
- [ ] **Call the real object.** Let a stub pass the call on to the real program
      or procedure, like Moq's `CallBase` or Mockito's `spy`.
- [ ] **Answers built from the arguments.** For example, set parameter 2 from
      parameter 1, or call a user procedure like Moq's `Callback`. Today every
      answer is a fixed value.
- [ ] **In-order verification.** Check that one call happened before another,
      across mocks. Recorded calls already have a global `CALLID` to order by.
- [ ] **Unused-stub detection.** Report stubs that no call used, like
      Mockito's strict stubs. Today a stub with a wrong matcher fails silently.
- [ ] **More flexible matchers.** OR between matchers (all `ARGS` must match
      today), a value-list matcher, and a between matcher.
- [ ] **More parameter types.** Arrays (`DIM`), data structures as return
      values, `*VARCHAR` passed `*VALUE`, and captured arguments longer than
      1,024 characters.
- [ ] **Typed RPG helpers.** Procedures such as `imoq_when(...)` so RPG tests
      don't have to build command strings with doubled quotes.
- [ ] **Detect qualified calls.** Have `IMOQCHK` report code that calls a mocked
      program with a qualified name (`CALL MYLIB/X`, `EXTPGM('MYLIB/X')`), which
      bypasses the mock.

## Documentation

- [ ] Limitations section in the Programmer's Guide.
- [ ] Example that creates mocks in another library with `LIB()`.
- [ ] Example of a `*VALUE` parameter.
- [ ] Example of `THROW(*MOCK …)`.
- [ ] Example of `IMOQRMV OBJ(name)` (removing a single mock).
- [ ] Examples using varchar, date, timestamp, zoned, float and pointer
      parameters. Today only the conversion unit tests (`IMOQENG_T`) use them.

### Limits of the approach

These probably can't be fixed, but they should be documented together:

- Procedures in modules bound by copy, or in the same program, can't be mocked.
- Programs called with a qualified name bypass the library list and the mock.
- Objects in QSYS and product libraries can't be mocked, because those
  libraries are searched before QTEMP.
- Code submitted to another job (`SBMJOB`) doesn't see the mocks.
- Files, SQL, data areas and data queues are out of scope.

## Testing

- [ ] Unit tests for command-level behavior (stub selection, `TIMES`, strict
      mode, verification counts, reset scopes). `IMOQENG_T` covers only value
      conversion and matchers; the rest is tested only through the examples
      and the demo.

## Repository

- [x] LICENSE file (MIT).
- [ ] CHANGELOG, version tags and GitHub releases.
- [ ] CI. A full build needs an IBM i, but a GitHub Action could check the docs
      and repository layout, or run the build on a self-hosted IBM i runner.
