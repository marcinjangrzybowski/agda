# Agda #8860: implementation design for local review

21 October 2026 · Branch `codex/issue-8860-reduction-pragmas`

Working prototype, stopped after several successful demos at the user's request. Changes remain uncommitted and local for review. Validation completed and checks deliberately not pursued are listed in the progress log.

[Issue](https://github.com/agda/agda/issues/8860) · [Research record](issue-8860-research.md) · [Progress and validation](issue-8860-progress.md)

## Result and accepted decisions

`ONLY_UNFOLD` and `DONT_UNFOLD` are declaration-local elaboration policies. They restrict ordinary function unfolding during conversion and explicit reflected object-term reduction. They do not change the completed definition's transparency. Both forms are implemented; nesting intersects permissions; macros compose with the policy. The latest user instructions supersede the research-stage proposal to start with a deny list and uniqueness gating. There is no new uniqueness requirement.

```agda
{-# DONT_UNFOLD expensive #-}
cast : Vec A (expensive + expensive) → Vec A (double expensive)
cast xs = xs
```

Here `double n = n + n`. The issue's original `2 * n` example is not definitionally equal to `n + n` for a neutral natural number with the builtin arithmetic definitions; the regression uses the definitional version above.

| Decision | Implementation and reason |
|---|---|
| Attachment | Before the function signature. Both signature and body carry the policy, including in cached abstract syntax. |
| Empty lists | Empty allow list permits no ordinary function unfolding; empty deny list adds no restriction. |
| Nesting | Intersect permissions, so inner scopes cannot reopen a forbidden name. |
| Ownership | Signature, clauses, generated helpers, and local implementation declarations share the enclosing annotated definition's owner. |
| Foreign metas | Restricted checking cannot directly refine them. Preserve obligations for later ordinary solving. |
| Delays and holes | Creation closures retain policy and owner; entering a closure cannot discard an active caller's write restriction. |
| Targets | Ordinary functions, including projection-like functions. Exclude primitives, proper record projections, and module-copy indirections. |
| Initial unsupported placements | Explicit user `mutual` groups and annotated `let` bindings. Generated mutual structures and inherited `where` checking remain supported. |
| Publication | Local review first. Do not push until the user authorizes it after review. |

## Composition, including macros

Treat a policy as the set of names permitted to unfold. Combining two policies means intersection:

| Outer / inner | Effective permission |
|---|---|
| Allow A / allow B | A ∩ B |
| Allow A / deny B | A ∖ B |
| Deny A / allow B | B ∖ A |
| Deny A / deny B | Deny A ∪ B |

The implementation keeps the declaration policy separate from Agda's existing reflection filter. Effective object-term permission is their intersection. This preserves `withReduceDefs`' existing behavior: a nested call replaces the reflection filter, while the enclosing source policy remains a ceiling. `askReduceDefs` still reports the reflection filter. The older reflection wrappers retain their existing composition rules.

A macro's own evaluator must run even under an empty source allow list. Reflection input rechecking also uses ordinary reduction. The source policy is activated for `TC.normalise`, `TC.reduce`, and conversion; it is not a global filter on the metaprogram's execution. No new reflection builtin is needed.

## Meta ownership and deferred work

The accepted guarantee is **direct containment**, not independence from every later consequence:

```text
restricted checking of D may refine m only when owner(m) = D
```

An older meta can be read. A preserved equation `older = local` may later propagate `local := t` to `older := t` during ordinary solving. The implementation does not discard that equation or pretend it was solved.

Ownership lives in the meta's creation environment. Copying `MetaInfo` during pruning preserves the original owner, avoiding the unsound shortcut “all recently allocated IDs are local.” Guards cover low-level assignment, ordinary assignment, pruning, modality promotion, eta expansion, and postulation. Bookkeeping such as registering listeners remains possible.

Two environment fields distinguish creation provenance from active write authority. A caller entering another meta's closure retains its authority; it cannot acquire permission to refine that older meta simply by restoring the saved environment. Constraint solving postpones foreign work. Foreign eta listeners become deferred constraints instead of being lost when a local assignment clears its listener set.

[PR #8837](https://github.com/agda/agda/pull/8837), merged on 15 October 2026, is the closest precedent: it checks meta creation environments when assigning under abstract/opaque visibility. Those checks remain intact. Definition ownership is an additional boundary, not a replacement for opacity, scope, occurs, modality, or frozen-meta checks.

## Correctness argument and its limits

Restricting function unfolding selects a subset of ordinary reduction steps. An equality established using those steps remains an ordinary definitional equality. This supports positive conversion results and the resulting elaborated term. It is not a proof that failure of restricted conversion establishes disequality or an impossible pattern.

Accordingly, pattern unification, coverage, emptiness, termination, positivity, and internal validation run with ordinary reduction. A durable disabled phase prevents a nested conversion or restored closure from accidentally reactivating the source policy during those checks. Type-shape inspection and discrimination-tree keys also retain baseline reduction. Existing abstract and opaque visibility boundaries still apply.

The policy can affect inference and can reject a program that ordinary checking accepts. It is not a promise that a name never unfolds anywhere during elaboration. Primitives and intrinsic projections are deliberately outside the initial target set, avoiding inconsistent promises across reduction engines. There is no formal machine-checked proof of the implementation; confidence rests on the phase argument, mutation audit, and executable regression tests. `--double-check` is useful validation by the same checker, not an independent kernel.

## Implementation map

1. **Syntax and scope:** parse both pragmas, attach them through nicification, resolve names strictly, preserve them in `DefInfo`, pretty printing, highlighting, and cache comparison.
2. **Reduction:** represent policies with `ReduceDefs`; intersect native and reflected permissions in both reducer implementations. Use explicit active/inactive/disabled phases.
3. **Lifecycle:** establish an owner before signature checking; inherit it in helpers; preserve policy and authority through closures and deferred constraints.
4. **Mutation boundary:** reject foreign assignment and refinement before mutation, retain obligations, and process them later with ordinary reduction.
5. **Validation:** positive and negative Agda examples, direct TCM tests of ownership and deferral, both reduction engines, internal checking, and existing regression suites. Exact commands and results are in the progress log.

## Review priorities and future extensions

The highest-value review is the boundary between ordinary validation and restricted conversion, followed by closure restoration and constraint scheduling. The semantic tests should verify those boundaries, not only that syntax parses.

Explicit mutual-group ownership can be added later with an intentional group-scoped surface syntax. Broader primitive/projection support needs a separate agreement about intrinsic reductions and parity between reducers. Performance benchmarking on real elaboration workloads should precede claims about speedup; the current regression demonstrates controlled unfolding and acceptance, not a measured performance gain.
