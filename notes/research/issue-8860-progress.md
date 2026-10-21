# Agda #8860 implementation progress

## Current status

Stopped at the working-demo stage at the user's request on 21 October 2026. The compiler builds and several feature examples work. No further implementation hardening or exhaustive testing is being pursued. Changes are uncommitted on the local branch for review; nothing has been pushed.

## Local installation

Installed the prototype under the alternative command `agda-8860`, as subsequently requested:

- Launcher: `/Users/marcin/.local/bin/agda-8860` (already on `PATH`).
- Binary snapshot: `/Users/marcin/.local/lib/agda-8860/agda`.
- Dedicated builtin and runtime data: `/Users/marcin/.local/share/agda-8860`, extracted using the binary's `--setup` command.
- `agda-8860 --version` reports `2.10.0`; the existing `agda` remains `2.9.0` and its executable hash is unchanged.
- Verified the installed binary matches the working build and successfully checks all success demos from a temporary directory outside the repository with `--ignore-all-interfaces`.
- This is a copied snapshot; rebuilding or changing the local branch does not automatically update the installed command.

## Scope and decisions

- Branch: `codex/issue-8860-reduction-pragmas`, based on `ef326bb97c238796ee7ef0552d381666435d4714`.
- Implement both `DONT_UNFOLD` (deny list) and `ONLY_UNFOLD` (allow list), attached before a function signature.
- Support nesting and composition with analogous reflection reduction controls, including `withReduceDefs`.
- Preserve ordinary transparency at use sites and ordinary structural validation.
- Own metas from the signature, body, generated helpers, and local implementation declarations; preserve ownership through delayed work and meta refinement.
- Restrict direct writes to foreign metas; permit later ordinary propagation through preserved constraints.
- Per the user's latest instruction, do not gate this feature on meta-solution uniqueness or introduce a uniqueness option requirement.
- Proceed autonomously without further design questions. The latest instruction revokes the earlier push request: keep the branch local for review and do not push to `mjtg` until the user authorizes it after reviewing.

## Work log

### 21 October 2026 — implementation started

- Created the implementation branch after access was enabled.
- Inspected the parser/nicifier, declaration metadata, reduction environment, closure restoration, meta assignment, and build/test setup.
- Existing research and design documents are retained as the research record; decisions above supersede the original deny-only and uniqueness-gating recommendations.
- Implemented parser, scoped declaration metadata, compositional reduction policies, meta ownership guards, and preservation through closures.
- Added initial success and failure regressions for both policies, nesting, reflection, inference, and structural checks.
- The baseline and changed compiler and test runner built successfully.
- Added deferred eta-listener handling so an assignment cannot discard work belonging to an older meta.
- Added tests for inherited policies, generated with-functions, extended lambdas, inferred mutual declarations, projection-like functions, and interactive hole resumption.
- Updated the manual, changelog, short design document, and historical research record.
- The user then narrowed completion to several working demos and requested stopping without exhaustive testing. That condition has been met.

## Validation

- Built with GHC 9.12.2 using `cabal build exe:agda exe:agda-tests --offline -O0 -f-debug -f-optimise-heavily -j4`. These Cabal flags disable debug output and heavy optimization.
- The complete success demo module passes with the default reducer and with `--no-fast-reduce --double-check`.
- All nine new expected-failure tests pass with the slow reducer and double checking, including rejection of a false absurd-pattern argument. Golden diagnostics were inspected.
- The new interaction test passes: `refl` is rejected under the retained deny policy, an existing proof is accepted, and the signature meta can be solved from the hole. The same sequence works after reload with the declaration cache populated.
- All 548 internal tests passed, including the new low-level assignment, copied-meta lineage, closure authority, foreign constraint deferral, and eta-listener tests.
- Earlier broad run: 2,047 existing success cases passed (42 debug-output cases disabled). Among 1,872 existing failure cases, two could not launch the executable during a concurrent relink; both passed on rerun, and the remaining cases passed (16 debug-output cases disabled). This was not a final exhaustive run over every suite.
- Test-development corrections: fixed the expected reflected hidden argument for the polymorphic identity example; discarded an accidentally accepted success-test failure expectation. Installed GNU `sed` 4.10 with Homebrew because the macOS interaction harness requires its regular-expression syntax. Discarded the initial interaction output containing unparsed commands and regenerated it successfully with GNU `sed` on `PATH`. An accidentally invoked custom interaction suite stopped on the missing tool before installation; it was not rerun.
- Not performed: full debug-enabled suite, complete custom interaction/compiler/ecosystem suites, manual rendering/checking, policy-edit cache invalidation, performance benchmarks, or a final comprehensive correctness audit. The user explicitly requested stopping once demos worked.

## Working examples

All the following live in [the success demo](../../test/Succeed/Issue8860.agda), with equality proofs checking their results:

| Example | Demonstrated behavior |
|---|---|
| `deny`, `allow`, `none`, `all` | Deny/allow lists and both empty-list cases |
| `mixed`, `intersection` | Repeated directives intersect permissions |
| `nested`, `inherited` | Nested and unannotated `where` helpers inherit the outer restriction |
| `macro-allow`, `macro-deny` | `withReduceDefs` composes with the source pragma |
| `inferred`, `helper-inference` | Signature and helper metas can be solved |
| `ordinary`, `ordinary-result` | Completed definitions remain transparent at use sites |
| `cast` | Definitional vector-index conversion with `big` kept folded |
| `with-helper`, `lambda-helper` | Generated with-functions and extended lambdas inherit the policy |
| `earlier`, `later` | Cross-owner obligations can be resolved by later ordinary checking |
| `projection-like` | An ordinary polymorphic identity function can be kept folded |

[The interaction demo](../../test/Interaction/Issue8860.agda) and its `.in`/`.out` files demonstrate hole resumption and reload.

From the repository root, rerun the success examples with the existing local build:

```sh
make \
  AGDA_BIN="$PWD/dist-newstyle/build/aarch64-osx/ghc-9.12.2/Agda-2.10.0/x/agda/noopt/build/agda/agda" \
  AGDA_TESTS_BIN="$PWD/dist-newstyle/build/aarch64-osx/ghc-9.12.2/Agda-2.10.0/x/agda-tests/noopt/build/agda-tests/agda-tests" \
  AGDA_TESTS_OPTIONS='-j4 -p Issue8860' succeed
```

## Intentional boundaries for this prototype

- Ordinary functions only; listed primitives, proper record projections, and module-copy aliases are unsupported.
- Annotated explicit `mutual` blocks and `let` bindings are unsupported.
- Structural checks use ordinary reduction. This feature does not promise that a listed function never unfolds anywhere during elaboration.
- Ownership provides direct containment. Later ordinary solving may propagate local choices to older metas.
- The [short design](issue-8860-design.md) states the correctness argument and review priorities. Passing these examples is not a proof of full implementation correctness or a claim of production readiness.
