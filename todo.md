# iMoq to-do list

Work still to do on iMoq, from a review of its features and gaps
(2026-09-22, updated 2026-09-25 after *IN and *BETWEEN). Items are
roughly in priority order within each section.

## Features

- [ ] **Answers built from the arguments.** For example, set parameter 2 from
      parameter 1, or call a user procedure like Moq's `Callback`. Today every
      answer is a fixed value.
- [ ] **OR between matchers.** All `ARGS` entries must match today. `*IN`
      covers one parameter with several values; OR across parameters needs
      a syntax. Two stubs with the same answer work in the meantime.
- [ ] **More parameter types.** `*VARCHAR` passed `*VALUE`, captured
      arguments longer than 1,024 characters, arrays of data structures
      (`likeds(x) dim(n)`: a field group repeating with a stride) and nested
      data structures.
- [ ] **Detect qualified calls.** Have `IMOQCHK` report code that calls a mocked
      program with a qualified name (`CALL MYLIB/X`, `EXTPGM('MYLIB/X')`), which
      bypasses the mock.

### Decided against

- **Call the real object** (like Moq's `CallBase` or Mockito's `spy`). Letting
  a test reach the real program or procedure is too risky: a test could update
  real data.

## Testing

- [ ] Unit tests for the RPG API (`imoq_when`, `imoq_verify` and the typed
      getters). `IMOQCMD_T` covers the engine through the commands; the API
      is tested only through `EXAPI` and the demo.
- [ ] Test `IMOQRU_H`, the RPGUnit assertions. RPGUnit isn't installed on
      pub400, so nothing has compiled or run it yet.

## Repository

- [ ] CHANGELOG, version tags and GitHub releases.
- [ ] CI. A full build needs an IBM i, but a GitHub Action could check the docs
      and repository layout, or run the build on a self-hosted IBM i runner.
      `tools/pub400-build.sh` already does a full build and test run on
      pub400 by hand.
