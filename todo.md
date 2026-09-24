# iMoq to-do list

Work still to do on iMoq, from a review of its features and gaps
(2026-09-22, updated 2026-09-24 after the RPG API). Items are roughly in
priority order within each section.

## Next up

- [ ] Add in-order verification and unused-stub detection.

## Features

- [ ] **Answers built from the arguments.** For example, set parameter 2 from
      parameter 1, or call a user procedure like Moq's `Callback`. Today every
      answer is a fixed value.
- [ ] **In-order verification.** Check that one call happened before another,
      across mocks. Recorded calls already have a global `CALLID` to order by.
- [ ] **Unused-stub detection.** Report stubs that no call used, like
      Mockito's strict stubs. Today a stub with a wrong matcher fails silently.
- [ ] **More flexible matchers.** OR between matchers (all `ARGS` must match
      today), a value-list matcher, and a between matcher.
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

- [ ] Unit tests for command-level behavior (stub selection, `TIMES`, strict
      mode, verification counts, reset scopes). `IMOQENG_T` covers only value
      conversion and matchers; the rest is tested only through the examples
      and the demo.
- [ ] Test `IMOQRU_H`, the RPGUnit assertions. RPGUnit isn't installed on
      pub400, so nothing has compiled or run it yet.

## Repository

- [ ] CHANGELOG, version tags and GitHub releases.
- [ ] CI. A full build needs an IBM i, but a GitHub Action could check the docs
      and repository layout, or run the build on a self-hosted IBM i runner.
      `tools/pub400-build.sh` already does a full build and test run on
      pub400 by hand.
