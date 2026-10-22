# Agda #8860 implementation progress

## Current status

The latest revision is implemented, tested, and installed as `agda-8860`: goal-specific interactive computation and normalized output now respect the saved unfolding policy, including nested replacement and resets. Each displayed constraint and solved goal uses its own policy. Result reduction is read-only and does not broaden structural checking or meta-write authority. Every pragma still replaces its predecessor, allow/deny lists must be nonempty, and the argument-free `UNFOLD_EVERYTHING` resets unfolding. The original `EvalTest.agda`, home demos, and Cubical import smoke check pass. The initial prototype is recorded in commit `4c587067be`; this snapshot includes all subsequent revisions. On 22 October 2026 the user authorized committing the current version and pushing the branch to `mjtg`.

## Local installation

Installed the prototype under the alternative command `agda-8860`, as subsequently requested:

- Launcher: `/Users/marcin/.local/bin/agda-8860` (already on `PATH`).
- Binary snapshot: `/Users/marcin/.local/lib/agda-8860/agda`.
- Dedicated builtin and runtime data: `/Users/marcin/.local/share/agda-8860`, extracted using the binary's `--setup` command.
- `agda-8860 --version` reports `2.10.0`; the existing `agda` remains `2.9.0` and its executable hash is unchanged.
- Verified the installed binary matches the working build and successfully checks all success demos from a temporary directory outside the repository with `--ignore-all-interfaces`.
- This is a copied snapshot; rebuilding or changing the local branch does not automatically update the installed command.
- Refreshed the snapshot after the interactive-output revision, using an atomic replacement. Source and installed binary SHA-256: `9a25e340c20996305fbe568d3765d8735cf4d23eb3ae68d5f8d77ffe00e59402`. The launcher and dedicated data directory are unchanged. The regular `agda` hash remains `e69f3672be767d32d280ad7ce5e4dfcdd24d6ce5b0366a566b6c6eb1de068fff`.
- An already-running Emacs backend retains the previous executable until restarted. Use `C-c C-x C-r`, then reload with `C-c C-l`. No Emacs settings or active buffers were changed.

## Scope and decisions

- Branch: `codex/issue-8860-reduction-pragmas`, based on `ef326bb97c238796ee7ef0552d381666435d4714`.
- Implement `DONT_UNFOLD` (nonempty deny list), `ONLY_UNFOLD` (nonempty allow list), and `UNFOLD_EVERYTHING` (no arguments), attached before a function signature.
- Support nesting and composition with analogous reflection reduction controls, including `withReduceDefs`.
- Every nested annotation replaces the enclosing policy. The last annotation attached to one declaration wins. Unannotated helpers inherit; leaving a scope restores its parent's policy.
- Preserve ordinary transparency at use sites and ordinary structural validation.
- Use each goal or constraint's saved policy for interactive result reduction through a read-only `ReduceM` boundary. Restore the relevant closure before activating display; retain the saved checking metadata and caller's phase.
- Each explicitly annotated definition owns metas from its signature, body, and unannotated helpers; nested annotations start new regions, even for the same policy or an explicit reset. Preserve ownership through delayed work and refinement.
- Reject foreign assignment without clearing the region on postponed constraints. Independent solving in the foreign meta's own context may unblock those constraints.
- Per the user's latest instruction, do not gate this feature on meta-solution uniqueness or introduce a uniqueness option requirement.
- Proceed autonomously without further design questions. The user's 22 October 2026 request to commit and push the current version supersedes the earlier local-review-only restriction. Publish the existing feature branch to `mjtg`.

## Subsequently requested standalone demos and timing

- Created `/Users/marcin/demos-8860` with four independent successful examples (vector batching, selective interpreter specialization, nested policies, and macro composition), plus an intentional proof failure. Each imports only Agda builtins. `run-demos.py` checks them and evaluates their comparison values using the installed compiler; `RESULTS.md` records the actual side-by-side results. No meta-specific demonstrations were added.
- At the user's further request for a noticeable speed difference, added three standalone variants under `speed/`, differing only in module name and reduction pragma. Each checks `adapt : Vec A (capacity + capacity) → Vec A (twice capacity)` with body `adapt xs = xs`, where `capacity = fib 28` and `twice n = n + n`. They use no reflection.
- `benchmark.py` performs one warm-up and three measured runs per variant in rotating order. It uses `--no-libraries --ignore-interfaces --no-write-interfaces`; every benchmark module is rechecked, while builtin interfaces are shared and warmed. All invocations succeeded.
- Whole-process median times on this machine: no pragma **3.800 s**; `DONT_UNFOLD capacity` **0.074 s** (**51.2×**); `ONLY_UNFOLD twice` **0.074 s** (**51.0×**). Individual timings and environment are saved in `/Users/marcin/demos-8860/speed/RESULTS.md` and `timings.json`.
- This demonstrates avoiding unnecessary index evaluation during elaboration using the installed unoptimized prototype. It does not establish a general speedup or faster compiled Fibonacci evaluation. The implementation was not changed for the demos.

## Work log

### 22 October 2026 — current snapshot prepared for publication

- The user explicitly requested committing the current version and pushing it to `mjtg` (`https://github.com/marcinjangrzybowski/agda`). The publication target is `codex/issue-8860-reduction-pragmas`.
- Verified that the remote branch is at the initial prototype commit `4c587067be`, so the current snapshot can be published as a normal fast-forward without rewriting history.
- Included the compiler changes, regression tests and expected outputs, manual/changelog updates, and research/design/progress records. The compiler source matches the already validated and installed revision. During publication preparation, updated the status documentation and removed insignificant trailing whitespace from the two empty-list parse-error expectations; the harness compares these diagnostics ignoring whitespace.
- Both affected parse-error tests pass after that cleanup, and the complete staged diff passes `git diff --cached --check`.

### 22 October 2026 — interactive goal reduction implemented

- Implemented the recommended shared backend fix after the user requested it. Added `reduceForDisplay`, `normalFormForDisplay`, and explicit closure-aware constraint normalization in `Interaction/BasicOps.hs`. The display boundary accepts only `ReduceM`, so it cannot assign metas or run type checking.
- Resolved the structural-phase edge case without weakening `withoutElaborationReduction`: display starts a fresh, scoped reduction operation even if a saved goal or constraint was captured during a disabled structural phase. Original closure metadata and the caller's phase/write authority remain unchanged.
- Updated interactive computation (including head computation), delayed goal rendering for both clients, context/let values, inferred and checked terms, helper signatures, solved goals, module/record contents, and Cubical boundaries. Elaborate-give keeps projection-like postprocessing inside the same boundary. Mimer uses it only for final solution output; search and structural operations are unchanged.
- Added three interaction fixtures and two internal properties. The fixtures check visible results, nested replacement/restoration, solved goals with different policies, reload, Cubical actual boundaries, and unchanged give/case-split/intro behavior. Internal tests check a disabled caller and real equality-constraint closures with conflicting policies and saved authorities.
- Documented that display cannot refold applications already reduced during checking. In the Cubical fixture, wanted endpoints are already stored as `3`; newly inferred actual endpoints distinguish `f 0` under denial from `3` under the allow list.
- Rebuilt, ran the validation below, refreshed only the `agda-8860` executable, and verified installed JSON behavior, home demos, the user's original `EvalTest.agda`, and the Cubical experiment. The ordinary custom compiler and its separate checkout were not modified. No commit or push was performed.

### 22 October 2026 — interactive goal reduction analysis

- Investigated the report that unfolding pragmas do not affect goal-specific command output. Confirmed on the installed compiler through both JSON and Emacs protocols: computation, simplified/normalized goal types, context entries, and inferred types unfold a denied function. Giving `refl` to the same goal correctly rejects it. An inner allow list also fails to keep an unlisted function folded during interactive computation.
- Traced the cause to missing activation at interactive result-reduction boundaries, rather than lost lexical policy. Audited nested closure restoration, delayed goal rendering, constraint normalization, Cubical boundaries, and result-producing tactics.
- Recorded observations, alternatives, the recommended shared backend implementation, phase/structural boundaries, and proposed regressions in [the interactive unfolding analysis](issue-8860-interactive-unfolding.md). Temporary probe files and transcripts are in `/tmp/agda-8860-interactive-policy`.
- This follow-up was analysis only. Compiler source, tests in the repository, installed binaries, and user demo files were not changed.

### 22 October 2026 — Cubical compatibility and parallel-installation check

- Reproduced the reported `NoParseForApplication` for `i ∨ ~ i` in `Cubical/Core/Primitives.agda` with `agda-8860` outside Emacs. The existing custom `agda` (2.9.0) accepted the same file. The initial commands used `--ignore-interfaces --no-write-interfaces`.
- Verified the alternative installation: its launcher selects `/Users/marcin/.local/share/agda-8860`, all 41 installed builtin `.agda` sources match this checkout, and the binary still matches the working build at SHA-256 `5cd402437b5c7329688ee5b642eceecaa3871853de8a72db1bd1df5333082c2b`. The running Emacs backend uses `/Users/marcin/.local/lib/agda-8860/agda`. The regular compiler uses its separate Cabal data directory.
- Identified the upstream breaking change: [Agda commit `9f2e1843e6`](https://github.com/agda/agda/commit/9f2e1843e6ca266a694e3681a8d64c1975249ae4), dated 18 September 2026, removed the fixities of `primINeg`, `primIMin`, and `primIMax`. The old Cubical checkout inherited those fixities when renaming the primitives. Without them, both `∨` and `~` default to precedence 20 and the reported expression fails to parse. This change predates the unfolding-pragma branch.
- Tested the three-line fix prescribed by that commit: give `primIMin` and `primIMax` `infixr 20`, and `primINeg` `infix 30`, in Cubical's import-renaming directive. The primitive module then passed with both installed compilers. Cubical had already adopted precisely this fix in [PR #1325](https://github.com/agda/cubical/pull/1325), commit `c2d05f7909c2254e2dfa5783b1bc88d99b878b87`.
- At the user's request, fetched Cubical upstream and fast-forwarded `/Users/marcin/agdaLibs/cubical` from `d4a2af62de40a6ca9a0b51981e41f804d879a1b9` to current upstream master `c37782bb4e382dc41035e0970409a0c17b55e6ce` (20 commits). The temporary local fix is now supplied by upstream; no tracked local Cubical patch remains. The previous tip is preserved as local branch `codex/pre-agda-master-20261022`.
- Preserved the user's untracked `Cubical/Experiments/Unfold.agda` byte-for-byte (SHA-256 `afad17c3a97448fdaca76342bd76601a26b7950173a060712d6abd230ae011a8`). It imports `Cubical.Foundations.Prelude` and `Cubical.Data.Nat`. Normal command-line checks of that file passed with both `/Users/marcin/.cabal/bin/agda` and `/Users/marcin/.local/bin/agda-8860`, including the affected primitives and their dependencies.
- The user's custom compiler target is the `mlttdb-mode` branch of `marcinjangrzybowski/shadow-agda` (remote `shadow` in this repository, `origin` in `/Users/marcin/mlttdb/proof-assistants/agda`). Any compiler patch for this follow-up is restricted to that fork. No compiler patch or reinstall was necessary to resolve this compatibility error; the custom checkout's existing edits and both installed executables were preserved.
- An initial attempt to check the larger experiment with both `--ignore-interfaces` and `--no-write-interfaces` timed out after 90 seconds per compiler while repeatedly checking shared imports. Retried using normal interface caching: both checks passed (about 4.35 seconds for the custom compiler and 49.79 seconds for the alternative compiler). These timings have different optimization/cache conditions and are not a performance comparison.
- A fresh `agda-8860 --interaction --interaction-exit-on-error` process also loaded the experiment successfully through the Emacs protocol and computed `i0 ∨ ~ i0` to `i1`. The existing GUI session was not restarted: `emacsclient` found no server socket. Reload with `C-c C-l`; if that session retains stale state, restart its Agda backend with `C-c C-x C-r` first.
- Logs and the update manifest are in `/tmp/agda-8860-cubical-diagnosis`. Validation covers the reported module and the experiment's import graph, not the entire Cubical library. Nothing was pushed.

### 21 October 2026 — replacement, explicit reset, and meta regions

- Implemented replacement for every source annotation, both nested and stacked before the same signature. Removed the now-unused intersection helper; source/reflection filters still compose independently at reduction sites.
- Added `UNFOLD_EVERYTHING` to the lexer, parser, policy type, and printer. Changed allow/deny payloads to `List1`; grammar requires a first name and the reset grammar accepts no names. Updated placement diagnostics and fixed the misplaced pragma constructor comment.
- Re-read the merged [PR #8837](https://github.com/agda/agda/pull/8837), its discussion, and local merge commit `8eaa55d1877a09fa8e387dec238e22ecd855fc36`. Its opaque-block identity check motivates giving each explicit annotation a separate meta region while keeping unannotated helpers in the enclosing region.
- Removed the fallback that retried cross-region constraints with cleared authority. Deferred obligations keep their creation context. Administrative eta expansion is queued in the target meta's saved context, preserving its policy and region.
- Added malformed-argument regressions, a cross-region failure module, replacement/reset examples, a reset interaction hole, and low-level tests for nested regions and deferred authority. Updated old empty-list tests so they continue testing their intended placement, conversion, and inference behavior.
- Verified the new meta-region counterexamples are accepted by the previously installed prototype (using its equivalent old empty-deny reset syntax). This provides a concrete before/after check for the strengthened region boundary.
- Updated current manual/design text and home demos. The user's current `EvalTest.agda` is the original proof-only example; its contents are preserved. Historical research and earlier validation remain below as records of the superseded semantics.
- Rebuilt the compiler and test runner, inspected and updated the affected expected diagnostics, completed the checks below, and refreshed the installed binary. Regenerated the home comparison results with that binary.

### 21 October 2026 — revised lexical nesting

- Revisited the initial intersection behavior after the user's `EvalTest.agda` example failed at an inner `y : 8 ≡ 2^ 3; y = refl` beneath an outer denial of `2^_`.
- The user first requested nested replacement, then refined it: consecutive deny lists accumulate until an allow list; allow lists replace rather than accumulate; mode switches discard earlier policies. Implemented the refined rule in declaration entry, leaving source/reflection composition unchanged.
- Saved contexts now restore their captured lexical policy verbatim instead of intersecting it with the caller's policy. The caller's active write authority and durable structural-checking phase are still preserved.
- Added source regressions for all four mode combinations, both nested empty-deny cases, deny → deny → allow → deny, sibling restoration, and the original power-proof nesting pattern. Added an interaction scenario for a reopened hole and a sibling retaining the denial, repeated after reload.
- Updated the manual, changelog, design/research records, and home demos. Restored the original nested proof in `EvalTest.agda`; its observable snapshots now show successful reopening. The pipeline demo shows accumulated denials and fresh policies after mode switches.
- Rebuilt the compiler and test executable, refreshed the installed snapshot, and completed the targeted validation below.

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

### Interactive-output revision (current)

- Compiler and test runner build successfully using `cabal build exe:agda exe:agda-tests --offline -O0 -f-debug -f-optimise-heavily -j4` with GHC 9.12.2. These flags disable debug output and heavy optimization.
- All **551 internal tests** pass on the final code, including the two new display/constraint properties.
- The broad simple-interaction suite runs **479 tests: 475 pass**. Four existing tests (`Issue1353`, `Issue7863`, `Issue8609`, `Positivity-not-even-once`) expect debug messages absent from this non-debug build. Rerunning those four against the previous installed executable reproduces identical differences; an assertion verifies that every changed line is a missing `agda2-verbose` message. Their goldens were not changed. No new behavioral failure was found in this suite.
- All **5 issue-specific interaction scenarios** pass with both reduction engines. The three new golden outputs were reviewed before creation; the broad fast-reducer run and targeted `--no-fast-reduce` run used no acceptance flag. Related existing tests for elaborate-give/projection-like output, goal constraints, solving, computation through `show`, and Mimer pass in the broad run.
- Both issue-specific success modules and all **13 issue-specific expected failures** pass with both reducers, using the harness's `--double-check`. The **5 related abstract/opaque/meta regressions** also pass with the default reducer (18 expected-failure tests in that run).
- JSON probes on the built and installed executables assert deny, allow, reset, inherited and unrelated-goal computation, goal/context/inferred-type output, and unchanged give acceptance/rejection. The installed output matches the validated build. Both Emacs and JSON paths are covered.
- Extracted actual elaborate-give output (`identity (f 0)`) and solve-all output (`f 0`, `3`, `3`), inserted them into complete temporary source examples, and checked those examples with `--double-check`. The separate `HiddenNat` fixture tests structural constructor discovery only; it is not an insertion round-trip under a denied type alias.
- The installed binary passes `run-demos.py` without rewriting the user's result record: all four successful examples and the exact expected failure. It also checks the unchanged original `/Users/marcin/demos-8860/EvalTest.agda` and `/Users/marcin/agdaLibs/cubical/Cubical/Experiments/Unfold.agda` with normal import caching.
- Build, test, baseline-comparison, round-trip, and installation records are in `/tmp/agda-8860-interactive-build`; JSON transcripts are in `/tmp/agda-8860-interactive-policy`. The previous installed binary is retained in the former directory as `agda-before-interactive-fix`.
- `git diff --check` passes. No debug-enabled rebuild, complete compiler/ecosystem suite, manual rendering, fresh speed benchmark, commit, or push was performed. The validation matrix in the interactive analysis remains a review checklist; not every proposed edge case has a dedicated new test.

### Replacement/reset/meta-region revision

- Build succeeded with the existing GHC 9.12.2 / Cabal `--offline -O0 -f-debug -f-optimise-heavily -j4` configuration. No debug-dependent tests were enabled.
- All **549 internal tests** passed, including foreign assignment, copied-meta lineage, closure authority, nested regions, deferred constraints retaining authority, and eta listeners queued in their own creation contexts.
- Both success modules pass with the fast reducer and with `--no-fast-reduce`, in each case with the harness's `--double-check`. They assert same-declaration replacement, all four nesting combinations, resets under allow and deny policies, sibling restoration, macro-filter composition after reset, and permitted local inference.
- All **13 issue-specific failure tests** pass with both reducers and `--double-check`: the original 9, plus empty allow, empty deny, names supplied to reset, and cross-region meta assignment. Changed placement/conversion/let diagnostics and the four new expected outputs were inspected before acceptance; the final runs used no acceptance flag.
- The new region test leaves all three prohibited assignments unsolved: from an unannotated outer scope, from an annotated parent with the same policy, and through an inner reset. The equivalent test with the old reset syntax passed on the previous installed binary. The positive `shared-region` example still lets an unannotated helper solve an enclosing-region meta.
- All **5 related failure regressions** pass without changes: `Issue8704-false`, `Issue8828-abstract`, `Issue8828-module`, `Issue8828-opaque`, and `MetasSolvedInAbstractBlock` (18 failure tests total with the feature cases).
- Both issue-specific interaction scenarios pass. The updated nested scenario accepts `refl` in both an inner allow scope and an explicit reset scope, rejects it in the sibling inheriting the outer denial, and repeats successfully after reload. The updated expected output was inspected and the final run used no acceptance flag.
- The installed compiler checks the user's original, proof-only `EvalTest.agda` with its original large exponents and inner `y = refl` in about **0.27 seconds** on this run. The source file was left intact.
- `./run-demos.py --write-results` passes with the refreshed installed command: four successful modules and their asserted/evaluated comparisons, plus the exact intended proof failure. Results include deny/deny replacement and both explicit reset cases. See `/Users/marcin/demos-8860/RESULTS.md`.
- `git diff --check` passes. No exhaustive compiler/ecosystem suite, manual rendering, fresh speed benchmark, commit, or push was performed for this revision. Earlier timing measurements below describe an earlier snapshot.

### Nesting revision

- Rebuilt `exe:agda` and `exe:agda-tests` with the existing offline, non-debug `-O0` configuration.
- The issue-specific harness run passes: 2 success modules, 9 expected-failure cases, and 2 simple interaction scenarios. Both success modules also pass with `--no-fast-reduce --double-check`.
- All 5 tests in `Internal.TypeChecking.Monad.Base` pass, including restoration of a saved allow policy under a caller's deny policy while retaining write authority and the disabled structural phase.
- Inspected the new interaction golden output: the inner allow-list hole accepts `refl`, the unannotated sibling rejects `refl` and accepts an established proof, and the sequence repeats after reload. Existing interaction behavior remains passing.
- `/Users/marcin/demos-8860/EvalTest.agda` checks with the original powers 50, 40, and 30 and the inner `y : 8 ≡ 2^ 3; y = refl`. A direct fresh source check took about 0.4 seconds. Verified it again with the refreshed installed command. Its evaluated `nested-demo` is `"8" ∷ "2^ 3" ∷ "pickThird 2 4 8" ∷ "8" ∷ []`.
- `./run-demos.py --write-results` passes with the installed command: all four comparison modules check afresh, their asserted normal forms are evaluated, and the intentional proof failure occurs exactly where expected. Updated `/Users/marcin/demos-8860/RESULTS.md` records the new nested behavior.
- The first automated power example used the original huge exponents. The harness enables `--double-check`, whose ordinary validation computes those powers; stopped that expensive run and reduced only the regression's exponents to 10, 9, and 8. The full original values remain in the home demo. This is the documented structural-validation boundary, not a claim that the pragma suppresses every reduction.
- `git diff --check` passes. No broad suite, fresh speed benchmark, commit, or push was performed for this revision. The earlier timing report below remains a measurement of the previous snapshot.

### Initial implementation

- Built with GHC 9.12.2 using `cabal build exe:agda exe:agda-tests --offline -O0 -f-debug -f-optimise-heavily -j4`. These Cabal flags disable debug output and heavy optimization.
- The complete success demo module passes with the default reducer and with `--no-fast-reduce --double-check`.
- All nine new expected-failure tests pass with the slow reducer and double checking, including rejection of a false absurd-pattern argument. Golden diagnostics were inspected.
- The new interaction test passes: `refl` is rejected under the retained deny policy, an existing proof is accepted, and the signature meta can be solved from the hole. The same sequence works after reload with the declaration cache populated.
- All 548 internal tests passed, including the new low-level assignment, copied-meta lineage, closure authority, foreign constraint deferral, and eta-listener tests.
- Earlier broad run: 2,047 existing success cases passed (42 debug-output cases disabled). Among 1,872 existing failure cases, two could not launch the executable during a concurrent relink; both passed on rerun, and the remaining cases passed (16 debug-output cases disabled). This was not a final exhaustive run over every suite.
- Test-development corrections: fixed the expected reflected hidden argument for the polymorphic identity example; discarded an accidentally accepted success-test failure expectation. Installed GNU `sed` 4.10 with Homebrew because the macOS interaction harness requires its regular-expression syntax. Discarded the initial interaction output containing unparsed commands and regenerated it successfully with GNU `sed` on `PATH`. An accidentally invoked custom interaction suite stopped on the missing tool before installation; it was not rerun.
- Not performed at the implementation stopping point: full debug-enabled suite, complete custom interaction/compiler/ecosystem suites, manual rendering/checking, policy-edit cache invalidation, performance benchmarks, or a final comprehensive correctness audit. The user explicitly requested stopping once demos worked. The subsequently requested standalone timing demonstration is recorded above.

## Working examples

All the following live in [the success demo](../../test/Succeed/Issue8860.agda), with equality proofs checking their results:

| Example | Demonstrated behavior |
|---|---|
| `deny`, `allow`, `none`, `all` | Nonempty deny/allow lists and explicit reset |
| `mixed`, `replace-allow`, `replace-deny`, `replace-reset`, `after-reset` | The last attached pragma replaces the previous policy |
| `nested`, `nested-allow`, `nested-deny`, `nested-deny-deny` | All four nested mode combinations use replacement |
| `nested-reset`, `nested-allow-reset`, `nested-new-denial` | Explicit reset of both kinds of list and repeated nested replacement |
| `inherited`, `nested-restored` | Unannotated helpers inherit; a sibling regains the enclosing policy after an override |
| `macro-allow`, `macro-deny`, `macro-reset` | `withReduceDefs` composes with the source pragma, including after a reset |
| `inferred`, `helper-inference`, `shared-region`, `reset-inferred` | Signature and unannotated helper metas can be solved in their own region |
| `ordinary`, `ordinary-result` | Completed definitions remain transparent at use sites |
| `cast` | Definitional vector-index conversion with `big` kept folded |
| `with-helper`, `lambda-helper` | Generated with-functions and extended lambdas inherit the policy |
| `earlier`, `later` | An independently solved foreign meta unblocks a retained obligation |
| `projection-like` | An ordinary polymorphic identity function can be kept folded |

[The interaction demo](../../test/Interaction/Issue8860.agda) and its `.in`/`.out` files demonstrate hole resumption and reload.
The [nested proof regression](../../test/Succeed/Issue8860Nested.agda) demonstrates reopening for `refl`; the [nested interaction scenario](../../test/Interaction/Issue8860Nested.agda) checks resumption and restoration of the outer policy.
The new interactive fixtures `test/Interaction/Issue8860Interactive`, `Issue8860InteractiveSolved`, and `Issue8860InteractiveCubical` record computation/display results, solved-goal insertion, and Cubical boundary behavior respectively.

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
- Deferred work retains its creation region. Restricting assignment does not establish a general uniqueness theorem for locally inferred solutions.
- The [short design](issue-8860-design.md) states the correctness argument and review priorities. Passing these examples is not a proof of full implementation correctness or a claim of production readiness.
