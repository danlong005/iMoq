# iMoq to-do list

Work still to do on iMoq, from a review of its features and gaps
(2026-09-22, updated 2026-10-06). Nothing is planned right now.

### Decided against

- **Call the real object** (like Moq's `CallBase` or Mockito's `spy`). Letting
  a test reach the real program or procedure is too risky: a test could update
  real data.
