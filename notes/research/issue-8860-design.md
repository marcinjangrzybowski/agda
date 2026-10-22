# Agda #8860: implementation design for local review

22 October 2026 · Branch `codex/issue-8860-reduction-pragmas`

Working prototype installed as `agda-8860`. The initial implementation is recorded in commit `4c587067be`; this snapshot includes the subsequent nesting, reset, meta-region, and interactive-output revisions. The user authorized committing the current version and pushing this branch to `mjtg` on 22 October 2026. Validation completed and checks deliberately not pursued are listed in the progress log.

[Issue](https://github.com/agda/agda/issues/8860) · [Research record](issue-8860-research.md) · [Progress and validation](issue-8860-progress.md)

## Result and accepted decisions

`ONLY_UNFOLD`, `DONT_UNFOLD`, and `UNFOLD_EVERYTHING` set declaration-local elaboration policies. They control ordinary function unfolding during conversion, explicit reflected object-term reduction, and goal-specific interactive result reduction, without changing the completed definition's transparency. Every annotation replaces the previous policy, including a preceding annotation on the same declaration. Allow and deny lists require names; the reset pragma accepts none. Macros compose with the resulting policy. Each explicitly annotated definition establishes its own meta region, following the creation-context approach of PR #8837. There is no new uniqueness option requirement.

```agda
{-# DONT_UNFOLD expensive #-}
cast : Vec A (expensive + expensive) → Vec A (double expensive)
cast xs = xs
```

Here `double n = n + n`. The issue's original `2 * n` example is not definitionally equal to `n + n` for a neutral natural number with the builtin arithmetic definitions; the regression uses the definitional version above.

| Decision | Implementation and reason |
|---|---|
| Attachment | Before the function signature. Both signature and body carry the policy, including in cached abstract syntax. |
| Arguments | Nonempty allow/deny lists, represented by `List1` in the AST. `UNFOLD_EVERYTHING` is a separate constructor with no arguments. |
| Nesting | Replace the enclosing policy. Unannotated helpers inherit; siblings regain the enclosing policy. |
| Several pragmas on one declaration | Last pragma wins; every annotation is still checked for valid names and targets. |
| Ownership | Each annotated declaration starts a new region, shared by its signature, clauses, and unannotated helpers. An explicit reset also starts a region. |
| Foreign metas | Reject assignment and preserve the original constraint context. Independent solving of the foreign meta may unblock the constraint. |
| Delays and holes | Restore the captured lexical policy verbatim. Do not recombine it with the resuming caller. Preserve an active caller's write restriction and disabled structural-checking phase. |
| Interactive output | Activate the saved policy only for read-only result reduction, after entering the goal or constraint closure. Case splitting and other structural operations retain their existing behavior. |
| Targets | Ordinary functions, including projection-like functions. Exclude primitives, proper record projections, and module-copy indirections. |
| Initial unsupported placements | Explicit user `mutual` groups and annotated `let` bindings. Generated mutual structures and inherited `where` checking remain supported. |
| Publication | The user authorized committing the current version and pushing the branch to `mjtg` on 22 October 2026. |

## Composition, including macros

Source nesting uses the following rules, where A and B are the listed names:

| Outer / inner | Effective permission |
|---|---|
| Allow A / allow B | Allow B |
| Allow A / deny B | Deny B |
| Deny A / allow B | Allow B |
| Deny A / deny B | Deny B |
| Any / unfold everything | Ordinary unfolding |

For example, deny `f`, then deny `g`, keeps only `g` folded inside the second scope. `UNFOLD_EVERYTHING` restores ordinary unfolding inside either an allow or a deny scope. These are lexical scopes, so returning to a sibling restores its enclosing policy. The former empty-list syntax is rejected.

The implementation keeps the declaration policy separate from Agda's existing reflection filter. Effective object-term permission is their intersection. This preserves `withReduceDefs`' existing behavior: a nested call replaces the reflection filter, while the active source policy remains a ceiling for that macro. `askReduceDefs` still reports the reflection filter. The older reflection wrappers retain their existing composition rules. `UNFOLD_EVERYTHING` changes only the source filter; ordinary visibility, termination rules, and an active macro filter still apply.

A macro's own evaluator runs even when the source policy excludes its functions. Reflection input rechecking also uses ordinary reduction. The source policy is activated for `TC.normalise`, `TC.reduce`, and conversion; it is not a global filter on the metaprogram's execution. No new reflection builtin is needed.

## Meta ownership and deferred work

The assignment rule follows the meta's creation region:

```text
restricted checking of D may refine m only when owner(m) = D
```

An older meta can be read, but an equation created in a different region cannot acquire permission to assign it merely by being postponed. It keeps its region when resumed outside the declaration. Once the foreign meta is independently solved, the equation may become checkable. This replaces the prototype's earlier fallback that cleared ownership and retried foreign obligations with ordinary reduction.

Ownership lives in the meta's creation environment. Copying `MetaInfo` during pruning preserves the original owner, avoiding the unsound shortcut “all recently allocated IDs are local.” Guards cover low-level assignment, ordinary assignment, pruning, modality promotion, eta expansion, and postulation. Bookkeeping such as registering listeners remains possible.

Two environment fields distinguish creation provenance from active write authority. A caller entering another meta's closure retains its authority; it cannot acquire permission to refine that older meta simply by restoring the saved environment. An explicit nested declaration intentionally starts a new region; an unannotated helper inherits. Foreign eta listeners become deferred constraints in the target meta's own creation context instead of being lost or run with the caller's authority.

[PR #8837](https://github.com/agda/agda/pull/8837), merged on 15 October 2026, checks meta creation environments when assigning under abstract/opaque visibility. Its opaque-block identity check is the direct model for the per-annotation region here. Re-read the merged diff and discussion for this revision. Those existing checks remain intact; definition ownership supplements them. This does not claim that restricting unfolding makes every locally inferred solution unique.

## Interactive goals

Computation, displayed goal/context/inferred types, elaborated terms, and solved-goal output use the selected goal's saved policy. Each displayed deferred constraint uses its own policy. The implementation lives in shared backend helpers, covering both Emacs and JSON, including goal types rendered after command dispatch. Top-level computation remains ordinary; `IgnoreAbstract` does not bypass source pragmas.

The new `reduceForDisplay :: ReduceM a -> TCM a` boundary can only run the read-only reducer. It starts a fresh display phase even if the goal was captured during a structural check, then restores the caller's phase. It cannot assign metas or run type checking. Constraint normalization enters the closure first and preserves its original checking metadata. Reification and structural type inspection stay outside this new boundary.

For example, under `DONT_UNFOLD f`, computing `f 0` and normalizing a goal `f 0 ≡ 3` retain the application; an inner `ONLY_UNFOLD f` computes it to `3`. This does not refold applications already reduced during checking, such as some stored Cubical endpoints. See the [interactive investigation and implementation record](issue-8860-interactive-unfolding.md).

## Correctness argument and its limits

Restricting function unfolding selects a subset of ordinary reduction steps. An equality established using those steps remains an ordinary definitional equality. This supports positive conversion results and the resulting elaborated term. It is not a proof that failure of restricted conversion establishes disequality or an impossible pattern.

Accordingly, pattern unification, coverage, emptiness, termination, positivity, and internal validation run with ordinary reduction. A durable disabled phase prevents a nested conversion or restored closure from accidentally reactivating the source policy during those checks. Type-shape inspection and discrimination-tree keys also retain baseline reduction. Existing abstract and opaque visibility boundaries still apply.

Replacing a source policy can re-enable reductions disabled by an enclosing pragma, but every enabled step is still an ordinary reduction. The nesting rule changes elaboration strategy, not the underlying equality. Restoring captured lexical policies for deferred work ensures that resuming a task does not accidentally intersect away a permitted inner override or import a sibling's restrictions.

The policy can affect inference and can reject a program that ordinary checking accepts. It is not a promise that a name never unfolds anywhere during elaboration. Primitives and intrinsic projections are deliberately outside the initial target set, avoiding inconsistent promises across reduction engines. There is no formal machine-checked proof of the implementation; confidence rests on the phase argument, mutation audit, and executable regression tests. `--double-check` is useful validation by the same checker, not an independent kernel.

## Implementation map

1. **Syntax and scope:** parse all three pragmas with their argument requirements, attach them through nicification, resolve names strictly, preserve them in `DefInfo`, pretty printing, highlighting, and cache comparison.
2. **Reduction:** represent policies with `ReduceDefs`; intersect native and reflected permissions in both reducer implementations. Use explicit active/inactive/disabled phases.
3. **Lifecycle:** establish a region before each annotated signature and body; inherit it in unannotated helpers; preserve policy and authority through closures and deferred constraints.
4. **Mutation boundary:** reject foreign assignment and refinement before mutation, retain obligations under their captured authority, and queue administrative eta expansions in the target meta's context.
5. **Interactive output:** shared read-only result helpers in `Interaction/BasicOps.hs`, closure-aware constraint display, and final-result call sites in `InteractionTop` and Mimer. No new syntax or meta metadata.
6. **Validation:** positive and negative Agda examples, direct TCM tests of ownership and deferral, both reduction engines, internal checking, and existing regression suites. Exact commands and results are in the progress log.

## Review priorities and future extensions

The highest-value review is the boundary between ordinary validation and restricted conversion, followed by closure restoration and constraint scheduling. The semantic tests should verify those boundaries, not only that syntax parses.

Explicit mutual-group ownership can be added later with an intentional group-scoped surface syntax. Broader primitive/projection support needs a separate agreement about intrinsic reductions and parity between reducers. The standalone vector-index benchmark recorded in the progress log measures a substantial gain on one synthetic example using the earlier installed snapshot. Real elaboration workloads still need benchmarking before making broader performance claims.
