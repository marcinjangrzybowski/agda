# Goal-specific unfolding controls: investigation and implementation

22 October 2026. **Implemented following the user's approval of the recommendation.** The first sections preserve the original investigation and design reasoning; the final section records the implementation. Exact validation and installation status are in the [progress log](issue-8860-progress.md).

This extends the [current pragma design](issue-8860-design.md). The initial investigation used the local `codex/issue-8860-reduction-pragmas` checkout and the then-installed `agda-8860` binary, SHA-256 `5cd402437b5c7329688ee5b642eceecaa3871853de8a72db1bd1df5333082c2b`.

## Finding and reproduction

Before this change, the goal remembered its declaration's unfolding policy, but interactive result reduction usually did not activate it. Checking a supplied solution and displaying a normalized goal could therefore disagree about which functions unfold.

For a function `f` whose application `f 0` reduces to `3`, consider:

```agda
{-# DONT_UNFOLD f #-}
blocked : (p : f 0 ≡ 3) → f 0 ≡ 3
blocked p = {!!}
```

Observed on the previous installed compiler, using both the JSON and Emacs interaction protocols; the last column is now implemented and tested:

| Operation in this hole | Before the change | Implemented result |
|---|---|---|
| Compute `f 0` | `3` | `f 0` |
| Compute `f 0` to weak head normal form | `3` | `f 0` |
| Simplified or normalized goal type | `3 ≡ 3` | `f 0 ≡ 3` |
| Simplified or normalized context | `p : 3 ≡ 3` | `p : f 0 ≡ 3` |
| Infer the simplified or normalized type of `p` | `3 ≡ 3` | `f 0 ≡ 3` |
| Give `refl` | Rejected with `UnequalTerms` | Still rejected |

`AsIs` already preserved `f 0 ≡ 3`. `HeadNormal` also preserved this particular equality type because its head was already the equality datatype; this did not demonstrate that the pragma was respected. Direct `HeadCompute` of `f 0` returned `3`.

A five-hole probe also tested nested replacement and restoration. There were inner `ONLY_UNFOLD f` and `UNFOLD_EVERYTHING` holes, an unannotated helper inheriting the outer denial, the outer hole itself, and an unrelated top-level hole. Previously every hole computed both `f 0` and an independent `g 0` to numerals. In particular, `ONLY_UNFOLD f` failed to keep `g 0` folded. Giving `refl` succeeded in the inner allow, reset, and unrelated holes, and failed in the two deny holes, as intended. The new compiler preserves these give outcomes while fixing result reduction.

The probe source, command transcripts, raw responses, and asserted observation table are under `/tmp/agda-8860-interactive-policy`. Holes are allocated in checking order, not source order: allow = 0, reset = 1, inherited deny = 2, outer deny = 3, unrelated = 4. Combined goal/context commands were also checked against outer hole 3. No source files in the user's demos were edited.

## Cause in the previous implementation

Relevant code is in `src/full/Agda/`:

1. `TypeChecking/Rules/Decl.hs`, `withDeclarationReduction`, stores the lexical filter in `eElaborationReduceDefs` but ordinarily sets the phase to `ElaborationInactive`. This is intentional: a declaration must not restrict every structural reduction performed while checking it.
2. `TypeChecking/Monad/MetaVars.hs`, `withInteractionId` → `withMetaId` → `withMetaInfo`, restores the meta's saved closure. `Monad/Closure.hs`, `enterClosure`, restores the lexical policy and its saved phase, while preserving an active caller's meta-write restriction and disabled structural phase.
3. `TypeChecking/Conversion.hs`, `compareAs`, explicitly calls `withElaborationReduction`. Consequently `give` checks conversion under the restored policy. Refine also goes through the give/checking path.
4. `Interaction/BasicOps.hs`, `evalInCurrent`, previously called `reduceB` and `normalise` directly. The source filter was inactive at those calls. `normalForm` similarly calls `reduce`, `simplify`, or `normalise` without activating the filter. Goal types, context entries, and inferred types used that helper without an activation boundary.
5. Reflection's `tcNormalise` and `tcReduce` already explicitly activate the policy for object-term reduction. The corresponding interactive operations are missing that boundary.

There are two additional reasons a wrapper around command dispatch is insufficient:

- Entering another meta or constraint closure can restore an inactive phase, replacing an outer activation. Activation must follow restoration of the relevant context.
- `Cmd_goal_type` mainly emits `Goal_CurrentGoal`. Both `EmacsTop.hs` and `JSONTop.hs` later call `prettyTypeOfMeta` to produce the type. The shared `BasicOps` implementation must carry the behavior; changing only the dispatcher or the Emacs frontend would miss paths.

## Recommended behavior

Use the selected goal's saved lexical policy when reducing an interactive result. Preserve the existing distinction between no normalization, simplification, weak head normalization, and full normalization. “Fully normalized” then means normalized using the permitted unfolding steps, and a deliberately folded function can remain in the result.

| Situation | Proposed policy source |
|---|---|
| Goal type, context, inferred type, evaluated expression, checked-term display | Selected goal's saved policy |
| Unannotated helper | Inherited saved policy |
| Nested allow, deny, or reset | That nested annotation's replacement policy |
| Multiple goals or solved-goal results | Each goal's own saved policy |
| Display of deferred constraints | Each constraint's saved policy; do not import another goal's policy |
| Top-level evaluation without a selected goal | Ordinary behavior |

The current command runner begins with a fresh environment; top-level evaluation does not select a declaration merely because its definition name appears in the expression. Completed definitions remain ordinarily transparent at use sites.

Keep computation depth, abstract visibility, and source unfolding policy as separate choices. In particular, retain the documented meaning of `IgnoreAbstract`: it changes abstract/nonterminating visibility, not this pragma policy. The [official Emacs-mode documentation](https://agda.readthedocs.io/en/latest/tools/emacs-mode.html) describes the existing normalization and visibility controls. If a way to bypass the pragma for inspection is later wanted, give it an explicit separate option. No new command or keybinding is needed for the initial default behavior.

`UseShowInstance` needs an explicit expectation: evaluating `show e` under a restrictive allow list can leave the `show` implementation folded. Recommend respecting the policy and reporting the existing failure to obtain a string, rather than silently performing unrestricted evaluation. Ordinary pretty printing remains available.

## Implementation approach

Introduce a shared policy-aware result-normalization helper in `Interaction/BasicOps.hs`. Reuse the existing filter and reducers; do not duplicate the policy in an interaction-point table or add syntax/AST fields.

The ordinary hole path should have this ordering (schematic, not a proposed verbatim patch):

```haskell
withInteractionId ii $ do
  (term, ty) <- inferExpr expression
  result <- withElaborationReduction $ normalizeRequestedResult term
  reify result
```

Only the requested result reduction is newly activated here. Inference still uses the existing checking boundaries. Reification and the type-shape inspection it needs should not acquire a blanket new restriction.

Concrete work:

1. Route interactive evaluation's `reduceB` and full `normalise` through this boundary. Fix the head-only path as well as ordinary full computation. Cover the actual `Cmd_compute` → `computeInCurrent` route; changing the separate `evalInMeta` helper alone would not fix that route.
2. Use the policy-aware helper for goal-type, context/let-binding, inferred-type, and checked-term output. Implement this in shared `BasicOps` functions so delayed Emacs and JSON rendering both benefit. Keep `AsIs`/`Instantiated` as instantiation-only modes.
3. Handle constraint closures explicitly. Existing `Reduce`, `Simplify`, and `Normalise` instances for `Closure a` call `enterClosure` internally. Merely activating around `normalForm norm constraintClosure` loses the activation again. A display-only helper must enter each closure, activate for its payload, and return a view with the original closure metadata preserved. Do not overwrite stored constraints or capture a display phase into their checking environments.
4. Audit all remaining result producers: solved-goal insertion, helper signatures, Mimer's final solutions, module contents shown inside a hole, and Cubical boundary terms. `typeAndFacesInMeta` has a direct `simplify` call in addition to `normalForm`. `elaborate_give` also runs `reduceProjectionLike` after normalization to address the reload issue #6203; it needs a round-trip test rather than assuming one wrapper is enough.
5. Preserve ordinary structural operations: case splitting, coverage, emptiness, telescope/type-shape inspection, termination, and internal validation. Give/refine retain their current conversion and meta-assignment behavior. Keep the existing local-state isolation of inspection commands and both meta-owner fields unchanged.

A specific phase edge case must be settled during implementation: a meta or constraint may have been captured during `ElaborationDisabled`. The current activation helper deliberately cannot override that phase. For the common interactive holes in the probe, activating after restoration is sufficient. If a fresh display operation must normalize a diagnostic meta captured in a disabled phase, establish a separate, explicitly scoped presentation operation; do not globally weaken the durable disabled guard or mutate the captured checking context. Test this case directly.

Prefer a result-specific helper over immediately changing every use of the generic `normalForm`: the latter is also used by helper construction and Mimer. Call sites should distinguish reducing the user-visible result from inspecting types needed to construct/check it.

## Alternatives and tradeoffs

| Approach | Assessment |
|---|---|
| Activate in every `withInteractionId`/`withMetaInfo` | Small patch, but changes structural operations, inference preparation, and tactics; nested restoration still needs care. Too broad. |
| Wrap only `Cmd_compute` | Useful narrow fix, but leaves goal/context/type output inconsistent and can accidentally include inference in the new phase. Insufficient. |
| Explicit shared result helpers, including a closure-aware helper | Recommended. Reuses current representation, reaches both clients, and makes the structural boundary reviewable. Requires a complete call-site audit. |
| Add a separate dynamic presentation-policy mode that survives closures | Could make future display paths more uniform, but adds environment state and changes how closure restoration and reduction interact. Consider only if the localized helpers become unwieldy. |

## Correctness argument and validation plan

This proposal changes which ordinary reductions are performed to produce an interactive result. Keeping `f 0` instead of reducing it to `3` preserves its ordinary type and definitional equality. It changes presentation/computation strategy, not the logical equality judgment. It cannot recover a function application already unfolded in a stored term.

The important conditions are that inspection does not gain new meta-write authority, normalization does not change saved policy/region metadata, and structural checking continues to use its established rules. Output inserted into source by elaborate-give, solve, or tactics must still check after reload; pretty-printing and projection-like reconstruction make that a substantive regression test.

Proposed tests:

- The observed examples above, with assertions on actual displayed/evaluated results and unchanged give outcomes.
- Both filters, explicit reset, nested replacement in every mode combination, inherited helpers, siblings, and switching between unrelated goals.
- `AsIs`, `Instantiated`, `Simplified`, `HeadNormal`, full computation, head computation, abstract visibility, and `show` mode.
- Context variables and let bindings; inferred and checked-term display; helper signatures; solved goals and final tactic output.
- Constraints with different saved policies, plus inactive/active/disabled captured phases; ensure no policy or meta-authority leak.
- Cubical boundary display while retaining ordinary boundary/type checks; projection-like output that survives reload.
- Reload and declaration-cache reuse, policy edits followed by reload, generated/refined holes, and holes produced through macro elaboration.
- Both reduction engines and both Emacs and JSON protocols. Top-level evaluation and unannotated goals retain baseline results.

## Implemented solution

The initial investigation made no compiler changes. After approval, the result-specific approach above was implemented on the existing local branch. No new AST constructors, meta fields, interaction commands, or frontend protocol changes were needed.

`BasicOps.reduceForDisplay :: ReduceM a -> TCM a` is the activation boundary. It runs only the read-only reducer, with `ElaborationActive` set locally. This resolves the disabled-phase edge case: displaying a meta captured during structural checking is a new presentation operation, while the durable disabled guard still governs checking. The helper cannot perform meta assignment, constraint solving, or type checking, and it does not change the saved closure or the caller's phase. `normalForm` was generalized to `MonadReduce`; `normalFormForDisplay` applies the existing normalization-depth choices inside the new boundary.

`normalFormClosureForDisplay` enters a saved constraint closure before activating the payload reducer, then returns a view with the original closure metadata. Both all-constraints display and constraints mentioning a selected meta use this helper. This avoids accidentally normalizing every constraint under the selected goal's policy or capturing the display phase as checking state.

The audited output paths now include computation, delayed goal-type rendering, context and let values, inferred/checked expressions, helper signatures, solved interaction points, module/record contents, Cubical boundary terms, elaborate-give, and Mimer's final solutions. `elaborate_give` places both normalization and its subsequent projection-like reduction inside the boundary; otherwise the second stage could immediately unfold an excluded function again. Inference, reification, helper construction, Mimer search, case splitting, and constructor introduction retain their existing checking/reduction behavior.

New regression fixtures:

- `test/Interaction/Issue8860Interactive`: actual output under deny/allow/reset policies, inheritance and scope restoration, full/head/ignore-abstract computation, goal/context/type display, let values, give rejection/acceptance, projection-like elaborate-give, case splitting, constructor introduction, and reload.
- `test/Interaction/Issue8860InteractiveSolved`: simultaneous solved goals with different saved policies, in normalized and simplified modes.
- `test/Interaction/Issue8860InteractiveCubical`: wanted/actual boundary output under deny and allow. Wanted endpoints are already `3` in the stored term; the denied actual expression remains `f 0`, whereas the allowed actual expression becomes `3`. This explicitly records the limit that display cannot refold earlier structural reductions.
- Two internal properties exercise read-only display from a disabled structural phase and real equality-constraint closures with conflicting saved/caller policies. They verify preserved caller phase, saved metadata, and foreign-meta write restrictions.

The exploratory JSON probes are also rerun against the changed compiler. The larger validation matrix above remains a review checklist, not a claim that every proposed combination received a dedicated new regression; completed runs and deliberate omissions are listed in the progress log.
