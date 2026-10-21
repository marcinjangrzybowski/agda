# Agda #8860: research record and implementation analysis

Research date: 21 October 2026. The sections below preserve the research-stage design study. Implementation was subsequently authorized; see the update immediately below and the companion documents for current decisions.

Companion: [short design proposal and decisions](issue-8860-design.md).

## Subsequent implementation decision

The user subsequently requested implementation of both allow and deny pragmas, nesting, and composition with analogous macro reduction controls; accepted direct meta containment and common signature/body ownership; and explicitly removed uniqueness concerns and option gating from the implementation scope. Those instructions supersede the historical deny-only and uniqueness-gating recommendations below. Work is on local branch `codex/issue-8860-reduction-pragmas`. The latest instruction requires local review before any push. The [current design](issue-8860-design.md) describes the implementation choices, and the [progress log](issue-8860-progress.md) records changes, validation, and limitations.

The issue was open with no comments when retrieved. Source inspection used Agda commit [`ef326bb97c238796ee7ef0552d381666435d4714`](https://github.com/agda/agda/commit/ef326bb97c238796ee7ef0552d381666435d4714). Links to implementation files below are pinned to that revision. Issue status, documentation on `latest`/`master`, and paper versions are observations as of the research date.

Evidence is separated into **observed source behavior**, **small experiments**, **deductions**, and **proposed design**. During this research stage, no compiler implementation, tests in the repository, options, or dependencies were changed. The experiments were standalone clients of an already installed executable; its provenance limitation is recorded in §10. Subsequent implementation validation uses a compiler built from the working branch and is recorded separately.

## 1. Problem and main conclusions

[#8860, “Control over reduction during elaboration”](https://github.com/agda/agda/issues/8860) asks for control over which definitions unfold while elaborating one definition, without making the resulting definition opaque at its uses. The motivation is avoiding expensive reduction and the quotation/rechecking overhead of a reflection workaround. The issue explicitly raises nonunique metavariable solutions and leaves the syntax open.

The user's additional proposal is central to this analysis: **allow restricted elaboration to resolve only metas that arose while checking the definition in question**.

The feature is plausible without a new core reduction rule, but the implementation is more substantial than introducing a pragma around `checkFunDef`:

1. Agda already has a name filter, `ReduceDefs`, and reflection operations that use it. Reuse this mechanism, after defining its boundaries precisely.
2. Definition-owned metas are a good containment boundary. Ownership must include the signature and generated helpers, persist through postponed checking, and survive pruning. Allocation time alone is insufficient.
3. Ownership does **not** restore unique inference. A fresh, entirely local meta can have multiple solutions under ordinary reduction while restricted checking selects one. Keep this distinction explicit in both implementation and documentation.
4. Restricted conversion may soundly establish equalities. Failure to establish equality must not become evidence of impossibility or injectivity in dependent pattern checking.
5. The existing filter is not uniform across all computational paths. Primitive reduction, projections, module copies, reflection, and indexing need separate treatment.
6. The best initial design is a declaration-local deny list for ordinary functions, a durable restriction on meta writes, and explicit phase boundaries. Start the inference-changing form under `--no-require-unique-meta-solutions`. A pure comparison shortcut is a separate, more conservative option.

### A correction to the motivating arithmetic example

The issue's example compares indices of the forms `n + n` and `2 * n`. With the standard builtin natural-number definitions and `n` kept neutral, these are not definitionally equal: `2 * n` reduces to `n + (n + 0)`, and `n + 0` is stuck. This does not invalidate the motivation, but it matters when selecting an acceptance test.

Use a deliberately definitional example instead:

```agda
double : Nat → Nat
double n = n + n

-- Hypothetical annotation: keep big neutral when checking cast.
cast : Vec A (big + big) → Vec A (double big)
cast xs = xs
```

Alternatively compare `big + (big + 0)` with `2 * big`, or supply a propositional right-unit proof. The neutral arithmetic behavior was checked experimentally (§10); the proposed annotation was not implemented.

## 2. What is being controlled?

Four notions should remain distinct:

| Mechanism | What it changes | Fit for this request |
|---|---|---|
| Semantic opacity, including Agda `opaque`/`abstract` | Which bodies are available to definitional equality in particular contexts | Relevant theory and precedent, but different use-site behavior |
| Elaboration reduction policy | Which available computations the elaborator attempts in a designated checking task | Direct fit |
| Inference heuristic, such as `INJECTIVE_FOR_INFERENCE` | How a solver chooses substitutions before or instead of unfolding | Related, narrower alternative |
| Presentation or runtime optimization | Printed terms or generated executable behavior | Does not itself control elaboration work |

“No change to the core” should mean: **for a fixed elaborated term, its typing and reduction rules are unchanged**. It cannot mean that the same source always elaborates to the same term. Choosing a different implicit argument can change the completed program and its runtime result.

There are also two different promises a user might expect:

- **Restriction:** do not unfold listed names in the documented elaboration phases; report when this prevents progress.
- **Preference:** try without unfolding them, then use ordinary conversion if needed.

A pragma named `DONT_UNFOLD` suggests the first. Silently implementing the second can hide large performance regressions. Conversely, an absolute promise covering every structural check and macro computation is difficult to support and is not needed for an initial conversion-focused feature.

## 3. Theoretical background and its limits

### 3.1 Local unfolding and semantic opacity

[Gratzer, Sterling, Angiuli, Coquand and Birkedal, *Controlling unfolding in type theory*](https://arxiv.org/abs/2210.05420), first circulated in 2022 and published in [MSCS in 2025](https://doi.org/10.1017/S0960129525100327), develops local unfolding using extension types and proposition symbols, with metatheory and a cooltt implementation. The paper also discusses Agda's elaborator-level approximation. It explains why controlled unfolding deserves a coherent theory; it does not prove that an arbitrary name filter inserted into Agda is sound.

[Danielsson and Geng, *A Formalization of Opaque Definitions for a Dependent Type Theory*](https://doi.org/10.1145/3759538.3759653), TyDe 2025 ([full text](https://research.chalmers.se/publication/549312/file/549312_Fulltext.pdf)), mechanizes opacity in a graded dependent type theory. Particularly relevant are §5.1's context/well-formedness results and counterexample concerning nontransitive unfolding. Signatures, dependencies, and reduction environments cannot be chosen independently. Its formal results concern the specified calculus, not all Agda features or the proposed inference heuristic.

These sources motivate an important distinction: a checking strategy may be incomplete while still producing terms valid in the original theory; a new restricted equality relation used as if it were a complete type theory needs stronger closure properties.

### 3.2 Why simply deleting delta reductions is not a complete soundness argument

Consider this schematic ordinary context:

```text
Alias : Set
Alias = Nat
value : Alias
value = 0
```

Keep `Alias` folded but allow `value` to unfold. The declaration says `value : Alias`; its reduct `0` naturally has type `Nat`, and restricted conversion may no longer relate `Nat` and `Alias`. Thus subject reduction for the **restricted** typing relation does not follow merely because every permitted reduction is an ordinary reduction. This is the same shape of problem discussed in [#433](https://github.com/agda/agda/issues/433#issuecomment-391674588).

There are two defensible responses:

1. Engineer a coherent semantic opacity discipline, with the associated dependency/context requirements.
2. Keep the ordinary typing relation authoritative, treat restricted conversion as partial evidence, and audit every consumer that assumes it has obtained a genuine neutral or canonical form.

The second matches #8860 better. It still requires work: typed normalization, type-shape inspection, eta expansion, and structural algorithms may rely on stronger invariants than “every individual reduction was valid.”

### 3.3 Inference unification is not dependent index unification

[Cockx, Devriese and Piessens, *Unifiers as Equivalences: Proof-Relevant Unification of Dependently Typed Data*](https://doi.org/10.1145/2951913.2951917) ([paper](https://jesper.cx/files/unifiers-as-equivalences.pdf)) explains why dependent pattern matching needs more than a substitution satisfying an equation: successful index unification must carry the appropriate equivalence information. Agda's [LHS unifier explicitly describes this distinction][lhs]. Consequently, a heuristic acceptable for choosing an implicit argument cannot automatically justify deleting a pattern-matching case or treating a function as logically injective.

For an ordinary constant-valued function `f`, restricted comparison of `f 0` and `f 1` can get stuck although ordinary conversion equates them. That failure is not a proof that an indexed constructor is impossible. Likewise, comparing the arguments of two applications of `f` is a sufficient way to establish equality, but equality of the applications does not imply equality of the arguments.

### 3.4 Heuristic elaboration and contextual metas

[Ziliani and Sozeau, *A Unification Algorithm for Coq Featuring Universe Polymorphism and Overloading*](https://beta-ziliani.github.io/assets/papers/unicoq.pdf), ICFP 2015, provides relevant examples of reduction strategy, first-order approximations, contextual metavariables, and pruning. The [2017 extended article](https://doi.org/10.1017/S0956796817000028) was identified bibliographically; this study read the 2015 paper, not the complete 2017 text. The useful lesson is to specify choices and failure behavior explicitly, rather than confuse heuristic success with a complete or principal solution procedure.

[de Moura, Avigad, Kong and Roux, *Elaboration in Dependent Type Theory*](https://arxiv.org/html/1505.04324v2), 2015, explains constraint scheduling, postponed problems, reduction, and backtracking in elaboration. Its account supports treating policy as part of a suspended checking problem, rather than just a temporary stack setting. It describes an earlier Lean implementation and is not a current Lean specification.

### 3.5 Other proof assistants: useful comparisons, limited transfer

The current [Lean reference on controlling reduction](https://lean-lang.org/doc/reference/latest/Definitions/Recursive-Definitions/) describes reducibility, local attributes, and sealing/unsealing. Its cautions about reducibility changes and cached elaboration information are relevant. Lean's separation between elaboration transparency and kernel checking is an architectural comparison, not evidence that Agda already has an equivalent independent kernel boundary.

The [Rocq reference on controlling reduction strategies](https://docs.rocq-prover.org/master/refman/proofs/writing-proofs/equality.html) describes `Opaque`, `Transparent`, `Strategy`, and local `with_strategy`. These controls have different scope and interactions with final proof checking; they should not be presented as interchangeable with Agda opacity or as an off-the-shelf design for this feature.

## 4. Previous issues, discussions, and changes

The table records what was actually read and the design implication. “Open” and “closed” refer to the research date. A closed issue is not a claim that all neighboring problems are solved.

| Source | Evidence examined | Relevance |
|---|---|---|
| [#433: Local abstraction barriers](https://github.com/agda/agda/issues/433), closed | Issue and discussion, including the subject-reduction example and later paper/opaque links | Long history of demand; warns against inconsistent local visibility |
| [#1625: lossy unification](https://github.com/agda/agda/issues/1625), closed | Issue and discussion | Category-theory examples expose expensive reduction; congruence-first heuristics can help or lose useful solutions; doing less unfolding is not always faster |
| [#6546: Injective for unification](https://github.com/agda/agda/issues/6546), closed; [PR #6640](https://github.com/agda/agda/pull/6640), merged 18 April 2024 | Issue/discussion and PR metadata/body | Separates inference injectivity from logical injectivity; precedent for the nonunique-solutions option |
| [PR #6628: Opaque/unfolding take 2](https://github.com/agda/agda/pull/6628), merged 12 May 2023 | PR body/merge metadata; predecessor #6354 followed as a reference | Existing implementation lineage, but a different semantic contract |
| [#5469: onlyReduceDefs must not stop macro evaluation](https://github.com/agda/agda/issues/5469), closed | Issue, discussion, and existing regression test | Object-language reduction policy cannot indiscriminately disable computation of the macro that implements it |
| [PR #5898: reflection environment queries/modifiers](https://github.com/agda/agda/pull/5898), closed | PR body and current API | `withReduceDefs`/`askReduceDefs` are the current vocabulary; legacy wrappers are not the right abstraction boundary for new syntax |
| [#8566: withReduceDefs and projections](https://github.com/agda/agda/issues/8566), open | Issue and maintainer comment | Some projection computation is intrinsic to internal syntax; arbitrary projection freezing is not a realistic initial promise |
| [#8777: unsound canonicalName assumption](https://github.com/agda/agda/issues/8777), closed | Issue/discussion and current fail tests | Restricted unfolding exposed module-copy assumptions; alias expansion must preserve the argument substitution |
| [#8704: abstract/lazy matching reduction bug](https://github.com/agda/agda/issues/8704), closed | Issue report and source context | A blocked match must not become a failed match that falls through to another clause; compare reduction engines and clause representations |
| [#8828: meta solutions leaking abstract/opaque information](https://github.com/agda/agda/issues/8828), closed | Issue, examples, current source, and fail tests | Meta creation environment matters independently of the environment where a solver happens to run |
| [PR #8827](https://github.com/agda/agda/pull/8827), closed **unmerged**; [PR #8837](https://github.com/agda/agda/pull/8837), adopted fix | Alternative proposal, discussion, and current source | Do not mistake the rechecking proposal for the merged implementation; the [14 October meeting decision](https://github.com/agda/agda/pull/8827#issuecomment-6169514938) favors the revised restriction-based fix |
| [#7304: instance search with opaque definitions](https://github.com/agda/agda/issues/7304), closed | Issue/discussion and discrimination-tree source | An index built under one transparency environment can miss candidates queried under another |
| [#8006: definitional equality and opaque signatures](https://github.com/agda/agda/issues/8006), closed | Issue and discussion | Signatures have their own checking boundary; following the behavior of an opaque body is not sufficient |
| [#8230: caching pragmas for imported functions](https://github.com/agda/agda/issues/8230), open | Issue body | Elaboration-affecting pragmas require explicit incremental-cache dependencies |
| [#6934: opaque by default](https://github.com/agda/agda/issues/6934), open; [#8757: opaque usability](https://github.com/agda/agda/issues/8757), open | Issue bodies | Useful syntax/usability context; not the same use-site semantics |
| [#8861: reflected opacity/local unfolding](https://github.com/agda/agda/issues/8861), open | Issue body | Related same-day request; should not silently enlarge #8860 into reflection support for semantic opacity |
| [#4727: modality errors in meta solutions](https://github.com/agda/agda/issues/4727), closed | Issue body and the linked generalization-source warning | Meta mutation includes modality and provenance, not only assigning a term |

The Zulip discussion linked from #6546 was located at [the original topic](https://agda.zulipchat.com/#narrow/stream/238741-general/topic/injective.20and.20rewriting.20.3F), but its messages were not directly accessible in the available web result. Conclusions here use the public GitHub discussion, not an asserted reading of that thread. No private discussions were consulted.

## 5. Existing implementation: reusable mechanisms and traps

### 5.1 Policy representation and reducer entry points

[Monad/Base.hs][base-policy] already defines:

```text
ReduceDefs = OnlyReduceDefs (Set QName) | DontReduceDefs (Set QName)
```

`shouldReduceDef` performs membership/complement testing. `locallyReduceDefs` replaces this environment setting; `locallyReduceAllDefs` sets an empty deny list. The latter clears the name filter, not semantic opacity, abstract visibility, or every reduction restriction. `AllowedReduction` separately controls categories such as projections, functions, recursion, and type-level reduction.

The ordinary [reducer][reduce] obtains both categories and the name decision. For a denied ordinary function it returns a non-reduced term marked `ReallyNotBlocked`. This is convenient for conversion but important semantically: “deliberately left folded” can look like “genuinely neutral” to downstream code.

The [fast reducer][fast] constructs compact definitions using the filter. Its name memo table is created within `fastReduce'`; this inspection did **not** find a persistent global fast-reducer cache that demonstrably omits the policy. Broader indexing and incremental caching still need attention.

Three limitations prevent promising arbitrary names immediately:

- **Primitives:** the slow reducer can execute a primitive before the `dontUnfold` decision reaches clause fallback; the fast reducer applies its gate before producing the compact primitive operation. A focused experiment observed different results (§10).
- **Projections:** projection application to a constructor can compute through internal term construction, not just a named definition's delta step. The maintainer explanation in [#8566](https://github.com/agda/agda/issues/8566#issuecomment-5343455469) makes this a representation issue.
- **Copies and aliases:** `reduceDefCopy`/`reduceDefCopies` have dedicated paths. A module copy may alter parameters; canonicalizing only the QName is invalid. #8777 is direct evidence.

Inlining and rewrite rules also belong in the audit. A name may disappear before the filtered comparison begins. A promise about a function's unfolding must say whether its rewrite rules are suppressed as well, and must not accidentally suppress or enable unrelated builtin computation.

### 5.2 Reflection is precedent, not a complete specification

The [reflection API][reflection-api] exposes `withReduceDefs` and `askReduceDefs`. Its Boolean selects an allow list or deny list. Legacy `onlyReduceDefs`/`dontReduceDefs` wrappers combine restrictions and are deprecated; the direct environment modifier replaces the reflection setting.

[Unquote.hs][unquote] deliberately clears the name filter at several boundaries:

| Operation | Relevant behavior at the inspected revision |
|---|---|
| Decode/execute reflected computations | `reduceQuotedTerm` uses `locallyReduceAllDefs` |
| `unify` | Rechecks reflected inputs with the filter cleared, then compares under the current filter |
| `normalise` / `reduce` | Reconstructs/rechecks reflected input with the filter cleared, then performs the requested reduction under the filter |
| Type and parameter reconstruction | Several paths clear the filter |
| `defineFun` | Invokes `checkFunDef` with the filter cleared |

Consequently, native declaration control can remove overhead and cover a different interval of checking. It should not be described as equivalent to blindly wrapping a reflection primitive. Conversely, a new lexical policy must not prevent the macro language itself from executing, repeating #5469.

A practical design is to distinguish **lexical source policy**, **reflection's temporary policy**, and **the purpose of the current reduction**. Object-language requests compose with the lexical restriction; trusted meta-language execution and baseline validation use their specified environments. `withReduceDefs` must not become an accidental escape from the new meta-ownership rule.

### 5.3 Conversion can infer through a supposedly rigid head

[Conversion.hs][conversion-shortcut] has a first-order shortcut controlled by lossy unification or an inference-injectivity annotation plus the uniqueness option. However, [ordinary comparison of residual `Def` heads][conversion-head] also compares their eliminations when the heads agree. If a reducible function is deliberately left folded, it can reach this ordinary rigid-head path.

Therefore, checking only the explicit first-order shortcut is insufficient to enforce a uniqueness policy. The experiment in §10 demonstrates a fresh local meta being selected under a deny list even without the lossy option.

[Conversion/Pure.hs][pure-conversion] offers useful infrastructure for a conservative alternative: conversion runs with state restoration and rejects meta/constraint effects. A restricted, state-free success followed by ordinary conversion on failure can preserve the baseline solver's choices, subject to auditing what “state-free” covers.

### 5.4 Metas, closures, and delayed checking

`MetaInfo` contains a closure, and the [closure representation][closures] captures the full `TCEnv`, scope, and checkpoints. [Entering a closure][enter-closure] restores its environment. Constraint handling and postponed checking use these closures. This provides an existing carrier for a declaration policy and logical owner across delays and interaction holes.

It is not a complete correctness argument. Entering a closure does not restore an immutable snapshot of the entire world, and it can change the environment while executing within a solver called from another definition. Reduction policy, meta provenance, and authority to mutate metas are related but distinct pieces of state.

The current [meta-assignment checks][assignment] already restrict assignments across abstract/opaque boundaries following #8828. They do not inspect `ReduceDefs`. Extending that idea to a definition owner is sensible, but must cover more than this single function.

The adopted change is [PR #8837](https://github.com/agda/agda/pull/8837), merged on 15 October 2026 as `8eaa55d1877a09fa8e387dec238e22ecd855fc36`. Opaque checking requires the meta to originate in the same opaque block. Abstract checking requires an abstract meta and checks that the current module is a parent of, or equal to, the meta's module, after dropping anonymous modules. This is a visibility condition, not literal identity of syntactic abstract blocks. It is the direct implementation precedent for the user's ownership proposal. It addresses both uniqueness and home-context typing failures caused by extra unfolding authority; §6.4 explains the different, local nonuniqueness introduced by suppressing ordinary unfolding.

### 5.5 Why a “new metas since entry” test is insufficient

[Monad/MetaVars.hs][meta-service] provides `metasCreatedBy`, which records an allocation boundary and collects later local meta IDs. It is useful bookkeeping, not a complete ownership relation. The [generalization code][generalization] explicitly warns that a pruned replacement of an old meta can be mistaken for a new one.

Concrete mutation paths found during inspection:

| Path | Consequence for ownership |
|---|---|
| `assignV` / ordinary assignment | Guard the target meta, retaining existing scope, modality, frozen, abstract, and opaque checks |
| `assignTerm'` | Explicitly bypasses pattern, occurs, and frozen checks; a freeze-only design leaves this path uncovered |
| Pruning in `performKill` | Creates a replacement using the original `MetaInfo`, then assigns the old meta to it; replacement must inherit the old owner |
| Modality promotion in the occurs checker | Currently modifies the existing meta's modality in place; it is a mutation even without a new term assignment |
| Eta expansion and listeners | May refine metas and wake other work; ownership must apply to the complete effect |
| Generalization, levels, sizes, and postponed problems | Can run outside the immediately visible expression checker; all writes need the same policy |

`withFrozenMetas` temporarily freezes the open store and later thaws what it froze. It is helpful as an experimental guard, but does not establish persistent provenance, protect every direct assignment path, or solve the delayed-work problem.

### 5.6 Declaration scope, caching, and structural checks

Signatures and bodies are separate abstract declarations. [Declaration checking][declarations] handles an `Axiom` signature separately from `FunDef`. A wrapper around only `checkFunDef` would miss signature metas and policies captured while checking the signature. Generated with-functions and where declarations pass through additional contexts in [Rules/Def.hs][function-check].

The parser, concrete syntax, nicifier, scope checker, abstract syntax, and declaration cache must all preserve the annotation. `DefInfo` is a candidate carrier. Existing `UnfoldingDecl` nodes are used for highlighting and should not be mistaken for a ready-made elaboration annotation. The cache compares abstract declarations; policy changes must participate in invalidation.

The [discrimination tree][discrim] already treats abstract heads conservatively to avoid missing instances across opacity environments (#7304). A denied ordinary function remains a `Function`, so the existing special case is not automatically sufficient for the new feature. An overapproximate candidate set with final conversion checking is preferable to a fast index that silently excludes a valid candidate.

Finally, the post-definition pipeline includes positivity, termination, coverage-related work, record-pattern processing, injectivity, projection analysis, and cubical checks. An outer environment wrapper can affect more than intended. Agda's `--double-check` rechecks some RHS terms using the same machinery and current environment; it does not by itself restore ordinary reduction, check every absent RHS, or provide an independent kernel certificate.

## 6. Definition-owned metavariables: proposed contract

### 6.1 Recommended meaning of “arose during checking this definition”

Use a **logical checking owner**, rather than wall-clock allocation time or a bare numeric range of meta IDs:

```text
Owner = the elaboration unit rooted at one annotated source definition
```

**Decision D2, agreed during the interactive design discussion:** the unit includes both the signature and body. Metas created while checking the signature, including its implicit arguments, may be solved during restricted body checking. Establish the owner and attach the policy before checking the signature; the concrete syntax remains undecided.

The proposed full scope, with helper ownership and delayed-work behavior still pending discussion, is:

- its type signature and implicit arguments created while checking it;
- all of its clauses and RHS elaboration;
- generated with-functions, extended lambdas, and implementation helpers;
- nested where declarations checked as part of that definition;
- postponed work and interaction holes originating in those parts.

It should exclude pre-existing module-parameter metas, metas belonging to an earlier declaration, and metas belonging to a separately checked sibling. An owner is a checking identity with appropriate revision/cache lifetime, not just an unqualified source name.

Pruned replacements, eta-expanded descendants, twins, and other refinements inherit the provenance of the meta being refined. A helper created while processing somebody else's postponed constraint must not acquire the caller's owner merely because allocation happened during the caller's execution.

Explicit mutual definitions are a real design decision. The strict reading gives each source definition its own owner, but shared signature inference may then be blocked. For an initial version, reject annotated user mutual groups with a specific diagnostic until either per-member checking is supported or an explicit **group-scoped** form is designed. Do not silently equate “one definition” with an entire mutual block. Generated auxiliaries are different: they implement the annotated definition.

### 6.2 Assignment rule and all associated effects

During restricted inference owned by `D`, a proposed mutation of meta `m` must satisfy:

```text
owner(m) = D
and all ordinary assignment/refinement conditions hold.
```

This must cover instantiation, pruning, eta refinement, modality changes, and solver-specific defaulting. It must be enforced below the convenient high-level `assign` entry point. Local failures should restore speculative state, including constraints and listener effects, before trying another branch.

Older metas may still be **read**. An equation between a local meta and an older meta can sometimes be oriented as `local := old`, leaving the older meta untouched. An occurs check that tries to prune or promote the older meta must instead stop or postpone. A new proxy cannot be used to evade the restriction by first rewriting an old meta to that proxy.

The owner and policy should be captured with suspended local work. Authority to mutate should also respect the currently active restriction: entering a foreign constraint's closure must not silently erase the caller's restriction and authorize a foreign write. One manageable scheduling design is to queue unrelated wakeups and resume them separately under ordinary checking, after leaving the restricted operation.

### 6.3 Direct containment versus future noninterference

There are two different guarantees:

1. **Direct containment:** restricted checking writes only owned metas. Any cross-owner equation remains an obligation and cannot be discarded merely because the restricted attempt stopped.
2. **Strong noninterference:** choices made for local metas cannot influence any older meta, even through constraints solved later.

The first does not imply the second. Suppose an older pending constraint is `old = local`. Restricted checking chooses `local := 0`. A later ordinary solver can then choose `old := 0` without any forbidden direct write during the restricted operation.

**Decision D1, agreed during the interactive design discussion:** promise direct containment, preserve the original obligations, and run cross-owner work under ordinary checking. The user selected option A: later ordinary solving may propagate local choices to older metas. Complete semantic independence of earlier holes is not required.

If strict future noninterference is required, use a stronger boundary: require an externally closed interface, reject constraints connecting local choices to unresolved external metas, or track dependency/provenance across the connected constraint component. Those alternatives reduce applicability or add substantial solver complexity. They are not achieved by freezing a store for one stack frame.

### 6.4 Why local ownership does not recover uniqueness

Let `f : Nat → Nat` compute to `0` for every argument. While checking a new definition, create a fresh local meta `?x` and encounter:

```text
f ?x = f 0
```

Keeping `f` folded permits rigid-head comparison to choose `?x := 0`. Under ordinary reduction, `?x := 1` also satisfies the original equation. Both are well typed; the restricted procedure has chosen among multiple ordinary solutions. No older meta participates.

Thus ownership and uniqueness are independent controls. The initial inference-changing feature should still require `--no-require-unique-meta-solutions`, or an equally explicit local acknowledgment if Agda chooses to introduce one. This is an inference-policy issue, not itself an argument that the resulting term is logically unsound. Existing [`INJECTIVE_FOR_INFERENCE` documentation][pragma-doc] makes a similar separation.

## 7. Correctness argument and obligations

Let `Γ ⊢₀ t : A` and `Γ ⊢₀ t ≡ u : A` be the ordinary judgements for the user's existing Agda configuration, including its actual abstract/opaque boundaries. “Baseline” does not mean forcing open otherwise inaccessible definitions.

Let `P` be a local reduction policy and `D` its checking owner. Treat restricted conversion as a partial procedure: success, blocked/unknown, or rejection. It is not a new complete equality decision procedure.

### 7.1 Positive conversion evidence

Required property:

```text
restricted conversion succeeds on (t, u, A)
    ⇒ Γ ⊢₀ t ≡ u : A
```

An argument can be built from ordinary-valid reductions, reflexivity, and congruence. Comparing equal-headed applications by equating their arguments is sound in this direction. It is not a justification for the reverse implication or for completeness.

This argument depends on typed contexts and typed substitutions; it does not excuse algorithms that mistake an artificially folded head for a canonical type constructor. Such consumers must retain baseline validation or be shown to handle partial reduction correctly.

### 7.2 Meta solutions

Each committed substitution must be well typed in the meta's own context, satisfy modality/scope/occurs conditions, and satisfy the original ordinary constraints. The ownership guard adds a separate invariant:

```text
each meta refined by the restricted operation belongs to D
```

Proof obligations include low-level assignments, refinements, rollback, and listener scheduling. For cross-owner constraints, retain the original obligation until an authorized ordinary solver discharges it. Treating failure as success, or losing the obligation during a policy change, would invalidate the argument.

For intuition, a restricted constraint transformation may retain a subset of the original solutions. A singleton subset does not imply the original set was a singleton. This is exactly why soundness of chosen solutions does not establish unique inference.

### 7.3 Negative and structural reasoning

Restricted failure supplies no evidence that ordinary conversion must fail. Coverage, impossible cases, dependent index unification, positivity, termination, and rewrite/cubical validity checks must either use the baseline semantics or have a separate justification for the restricted result.

In particular:

- do not derive an absurd clause from a policy-induced mismatch;
- do not use inference injectivity as a proof-relevant injectivity principle;
- do not turn an intentionally unreduced match into a clause mismatch;
- do not assume that selecting an arbitrary subset of rewrite steps preserves confluence or canonical forms.

For the initial implementation, keep these checks on baseline reduction and preserve all ordinary obligations. If they need meta writes, honor ownership during the restricted transaction or run them as an explicit baseline phase.

### 7.4 Export and conditional preservation claim

No source-policy annotation should alter the resulting definition's ordinary delta rule or grant extra unfolding authority to its users. Importing the completed definition should not reactivate its checking policy at call sites.

Under the preceding obligations, an induction over elaboration can argue that a successful annotated definition yields a term/declaration accepted by the existing typing rules. This is a **conditional preservation argument**, not a new proof of consistency or normalization for full Agda, including all optional features.

Baseline rechecking with metas frozen is valuable as a development oracle, and potentially as a deliberate production validation phase. It is not sufficient by itself: internal checking shares implementation, structural obligations extend beyond RHS terms, and full rechecking may incur the expensive reductions the feature was meant to avoid. If production correctness depends on it, its cost must be included in the feature's performance claim.

## 8. Approaches, tradeoffs, and design choices

### 8.1 Implementation approaches

| Approach | Benefits | Costs and limitations | Assessment |
|---|---|---|---|
| Keep the reflection workaround | Existing API; no new syntax | Quote/recheck overhead, uneven scope, macro execution exceptions | Useful reference and experiment harness |
| Wrap the entire declaration checker in existing `ReduceDefs` | Small apparent patch; broad effect | Changes structural algorithms, signature boundaries, wakeups, and reflection behavior; inherits reducer discrepancies | Not an adequate final design |
| Phase-aware declaration policy plus meta ownership | Directly addresses the request; avoids permanent opacity; supports local inference choices | Requires end-to-end policy propagation and mutation audit | Recommended initial implementation direction |
| Restricted pure comparison, ordinary fallback | Avoids new meta choices; may work under ordinary uniqueness requirements | Does not guarantee names remain folded; misses inference-changing uses | Useful conservative mode, separate contract |
| Local inference-injectivity hint | Narrower change for equal-headed applications | Does not generally control normalization, casts, or with-abstraction; still nonunique | Alternative if concrete examples only require congruence-first inference |
| New semantic opacity discipline | Stronger theoretical account of visibility | Changes the requested semantics and dependency discipline; larger language design | Do not use as the default solution to #8860 |

### 8.2 Recommended initial scope

Start with a declaration-attached **deny list of ordinary function names**. Exclude primitives, projections, constructors, datatype/record copies, and unresolved alias cases until their semantics are explicitly supported. Diagnose unsupported targets; silently ignoring them creates a misleading performance contract.

Apply it to documented conversion/unification and object-term normalization operations during the definition's signature/body elaboration. Retain baseline type-shape inspection and mandatory structural validation. If those phase boundaries cannot be made precise, narrow the initial feature further rather than claiming that every reduction during checking is controlled.

This initial profile may not cover all normalization associated with with-abstraction. Broader normalization control should be a measured extension with dedicated examples, not an accidental consequence of an outer wrapper.

Require `--no-require-unique-meta-solutions` for the inference-changing profile. Enforce owner-limited writes regardless of temporary reflection settings. Ordinary opacity and reduction-category restrictions continue to apply; the new feature can remove permission to unfold, not grant it.

### 8.3 Syntax and scope

An attached pragma placed **before the signature** is the least disruptive candidate:

```agda
-- Proposed syntax only; not accepted by current Agda.
{-# DONT_UNFOLD expensiveName anotherName #-}
example : T
example = rhs
```

It should attach to the logical definition, not merely the next low-level declaration. A pragma appearing only between signature and clauses should either be rejected or have an explicitly distinct body-only meaning. The recommended initial choice is rejection with a relocation hint.

A block syntax can later express multiple definitions and explicit group ownership. Reusing bare `unfolding` is attractive visually but easy to confuse with the existing permission to unfold opaque bodies. Syntax should communicate whether names are denied, allowed, or merely deprioritized.

For nested restrictions, combine allowed sets by intersection; two deny lists therefore combine by union. Do not silently change the existing replacement semantics of reflection's `withReduceDefs`. A separate lexical field, composed with reflection at object-language reduction sites, is one implementation option.

### 8.4 Names, caching, and diagnostics

Resolve names during scope checking and store resolved identities plus source ranges. Decide whether the policy applies to a surface alias, its origin, or both; parameterized module copies require term-level substitution, not just QName canonicalization. Until resolved, limit the supported targets.

Policy metadata must be included in declaration equality/cache dependencies. Cache restoration must preserve the owner of surviving metas and suspended work; stale owner identities cannot be reused after source changes. Inspect serialization requirements if any new metadata reaches interfaces or remote metas. Exporting elaboration metadata for tooling is acceptable; exporting a new call-site reduction rule is not.

Diagnostics should distinguish:

- a comparison stopped because a listed definition was kept folded;
- a constraint blocked on an unresolved meta;
- an attempted write to a meta owned by another definition;
- an unsupported declaration or target kind;
- an ordinary baseline type error.

Do not repeatedly reschedule a policy-stuck constraint when no changing blocker exists. A useful error names the policy, the blocked definition or foreign meta, its origin, and the source annotation. For owner failures, suggest an explicit signature/implicit argument or a future explicit group scope, rather than quietly weakening the boundary.

## 9. Practical implementation and validation plan

This is a plan for future work. None of the changes below were made during this study.

### Step 1: settle the observable contract

Prepare a small specification covering: deny versus prefer; signature/body scope; owner membership; cross-owner constraints; uniqueness option; generated helpers; supported names; reflection composition; structural baseline checks; and explicit mutual groups. Use corrected arithmetic and a genuine expensive user example as motivating cases.

Deliverable: a behavior table and expected successes/failures. Gate: every claim about “only this definition” has a precise answer for delayed work and foreign metas.

### Step 2: establish baseline evidence on a pinned stock build

Re-run §10 on an executable built from the inspected revision. Confirm the primitive discrepancy and auto-inlining behavior before deciding whether they require a separate bug fix or an explicitly narrower feature. Record wall time, allocation, constraint count, and reduction counts for the current reflection workaround and ordinary elaboration.

Gate: a reproducible baseline; no claim of speedup from this research alone.

### Step 3: implement ownership and mutation accounting

Introduce the logical owner in the checking environment/meta provenance; establish it before checking the signature. Preserve it in generated and postponed work and in replacement metas. Inventory instantiation, `updateMetaVar`, pruning, promotion, eta expansion, defaulting, listeners, and rollback. Add a common authorization mechanism appropriate to each mutation path; do not rely only on `assignV` or temporary freezing.

Use debug assertions or effect logging during development to verify that a restricted operation cannot commit foreign meta refinements. Queue foreign wakeups for ordinary checking and retain cross-owner obligations. Decide how a nested owner composes with an active outer restriction before enabling nested annotations.

Gate: owner-isolation tests pass even when the reduction filter is temporarily cleared for trusted work.

### Step 4: introduce and propagate source metadata

Extend concrete pragma syntax, parser/lexer, nicifier attachment, scope checking, abstract metadata, pretty printing/highlighting, and cache comparison. Carry the same annotation to signature and clauses. Preserve ordinary exported definitions. Include interface-version/serialization work only if the chosen representation actually crosses that boundary.

Gate: adding, removing, or moving a policy produces the same result in a clean run and an incremental editor session.

### Step 5: connect the documented elaboration phases

Compose the lexical name restriction with ordinary visibility and reflection policy. Annotate purpose-specific bypasses: macro execution, type reconstruction, type-shape inspection, and structural validation. Audit both reducers, copy expansion, inlining, rewrite rules, and instance indexing for the supported target class. Add an explicit policy-stuck diagnostic or equivalent traceable result where needed.

Gate: every supported path obeys the documented restriction; unsupported paths fail explicitly or run in the documented baseline phase.

### Step 6: establish preservation and integration evidence

Run accepted examples with baseline internal rechecking as a development oracle. Inspect structural outcomes separately. Exercise relevant combinations of `--safe`, `--without-K`, cubical modes, rewriting, cumulativity, erasure, and interactive holes; either support combinations with evidence or state a deliberate initial limitation. Do not infer logical safety solely from the nonunique-solutions option.

Gate: no policy-induced impossible-case acceptance, no foreign writes, no stale cache behavior, and consistent results across relevant reduction paths.

### Step 7: measure, document, and review

Compare ordinary elaboration, reflection, the native policy, and any pure-comparison alternative on the same examples. Measure full checking, including mandatory baseline validation. Look for cases where congruence traverses large arguments that unfolding would discard. Publish syntax, exact phase exceptions, owner semantics, and examples where explicit arguments are necessary.

Acceptance should require a demonstrated benefit on real motivating workloads, not just removal of a quotation call.

### Test matrix

These are proposed tests, distinct from the observations in §10.

| Area | Essential case | Required result |
|---|---|---|
| Basic behavior | Expensive transparent index kept folded during conversion | Checks without unnecessary conversion-time expansion |
| Use sites | Use and normalize the completed annotated definition elsewhere | Ordinary transparency retained |
| Arithmetic | Original neutral formula and corrected formula | First rejected, corrected one accepted for the right reason |
| Local inference | Fresh local `?x` in `f ?x = f 0`, constant-valued `f` | Chosen solution allowed only under the documented inference policy |
| Foreign metas | Constraint attempts to assign an earlier hole | Restricted operation cannot commit the write |
| Indirect mutation | Occurs check prunes/promotes an earlier meta; eta expansion targets it | Same ownership rule, including low-level paths |
| Replacement provenance | Old meta gets a fresh pruned representative | Representative remains old-owned |
| Delayed work | Local meta/constraint resumes after lexical checking returns | Original policy and owner retained |
| Foreign wakeup | Local assignment wakes a foreign constraint | Deferred or separately baseline-checked; no owner escape |
| Cross-owner equation | `old = local`, followed by local assignment | Original obligation preserved; documented direct-containment semantics |
| Signatures/helpers | Signature holes, with-functions, where clauses, extended lambdas | Membership in owner matches the specification |
| Mutual definitions | Explicit user mutual block with annotation | Rejected initially, or handled only by an explicitly specified group design |
| Structural reasoning | Hidden reductions would make apparently different indices equal | No false absurd clause, coverage, or injectivity conclusion |
| Reduction engines | Supported name under fast/slow, compiled/clause paths | Same supported semantics; blocked matching does not fall through |
| Special targets | Primitive, projection, module copy | Explicitly unsupported initially, or covered by dedicated semantics/tests |
| Reflection | Macro helper evaluation, `unify`, `normalise`, `defineFun` | Macro runs; object-level policy and owner boundary obeyed |
| Indexing | Instance inserted and queried under different policies | Conservative candidate retrieval; no false missing instance |
| Caching | Edit pragma only; reload/import; resume interaction | Same result as clean checking; no policy/owner leakage |
| Options | Relevant safe/cubical/rewriting/erasure/level configurations | Existing invariants preserved or combinations explicitly unavailable |
| Performance | Real large-index/category examples, plus cheap-discarding functions | Full cost measured; no unsupported universal speedup claim |

## 10. Small observational experiments

### Environment and limitations

Experiments used `/Users/marcin/.cabal/bin/agda`, reporting Agda 2.9.0, with executable SHA-256:

```text
e69f3672be767d32d280ad7ce5e4dfcdd24d6ce5b0366a566b6c6eb1de068fff
```

The executable is an existing local build with extra local options. It was **not established to be a stock build of the inspected commit**. Results therefore support the analysis alongside source inspection; they are not claimed as verified upstream regressions at that exact commit. No compiler was rebuilt or installed.

Files were created under `/tmp/agda-8860-probes`, outside repository source. Each invocation used `--no-libraries --no-write-interfaces`. The complete useful reproducers are preserved below so the record does not depend on temporary files.

| Probe | Extra flags | Observed exit/result |
|---|---|---|
| `ArithmeticNeutral.agda` | none | 42; equality rejected |
| `ArithmeticCorrected.agda` | none | 0; accepted |
| `RestrictedMeta.agda` | `--no-auto-inline` | 0; fresh meta chosen as `0` |
| `RestrictedMeta.agda` | `--no-auto-inline --no-fast-reduce` | 0; same result |
| `RestrictedPrimitive.agda` | none | 0; quoted addition retained |
| `RestrictedPrimitive.agda` | `--no-fast-reduce` | 42; normalized result is literal `3`, so the retained-syntax equality fails |

The meta experiments did not enable `--lossy-unification` or `--no-require-unique-meta-solutions`.

### 10.1 Arithmetic with a genuinely neutral index

```agda
module ArithmeticNeutral where

open import Agda.Builtin.Nat
open import Agda.Builtin.Equality

postulate n : Nat

bad : n + n ≡ 2 * n
bad = refl
```

```agda
module ArithmeticCorrected where

open import Agda.Builtin.Nat
open import Agda.Builtin.Equality

postulate n : Nat

good : n + (n + 0) ≡ 2 * n
good = refl
```

Commands:

```sh
agda --no-libraries --no-write-interfaces ArithmeticNeutral.agda
agda --no-libraries --no-write-interfaces ArithmeticCorrected.agda
```

This tests the definitional arithmetic prerequisite, not a proposed native annotation.

### 10.2 Nonunique inference with a fresh local meta

```agda
module RestrictedMeta where

open import Agda.Builtin.Nat
open import Agda.Builtin.Equality
open import Agda.Builtin.Bool
open import Agda.Builtin.Sigma
open import Agda.Builtin.Unit
open import Agda.Builtin.List
open import Agda.Builtin.Reflection

pattern vArg x = arg (arg-info visible (modality relevant quantity-ω)) x

f : Nat → Nat
f zero = 0
f (suc n) = 0

macro
  pick : Term → TC ⊤
  pick hole = withReduceDefs (false , (quote f ∷ []))
    (unify (def (quote f) (vArg hole ∷ []))
           (def (quote f) (vArg (lit (nat 0)) ∷ [])))

chosen : Nat
chosen = pick

chosen-is-zero : chosen ≡ 0
chosen-is-zero = refl

alternative-also-satisfies : f 1 ≡ f 0
alternative-also-satisfies = refl
```

```sh
agda --no-libraries --no-write-interfaces --no-auto-inline RestrictedMeta.agda
agda --no-libraries --no-write-interfaces --no-auto-inline --no-fast-reduce RestrictedMeta.agda
```

The hole originates in checking `chosen`. The two final equalities establish the selected result and an alternative solution of the original `f` equation. This is the direct counterexample to interpreting local ownership as a uniqueness guarantee.

An earlier version used the single clause `f _ = 0`; automatic inlining during reflection's input rechecking removed the head before the restricted comparison, leaving the hole unsolved. The two-clause definition and disabled automatic inlining isolate the intended comparison. That failed attempt is itself evidence that annotation scope and pre-comparison transformations matter.

### 10.3 Fast/slow primitive reduction discrepancy

```agda
module RestrictedPrimitive where

open import Agda.Builtin.Nat
open import Agda.Builtin.Equality
open import Agda.Builtin.Bool
open import Agda.Builtin.Sigma
open import Agda.Builtin.Unit
open import Agda.Builtin.List
open import Agda.Builtin.Reflection renaming (bindTC to _>>=_)

pattern vArg x = arg (arg-info visible (modality relevant quantity-ω)) x

macro
  inspect : Term → TC ⊤
  inspect hole = do
    t ← withReduceDefs (false , (quote _+_ ∷ []))
      (normalise (def (quote _+_)
        (vArg (lit (nat 1)) ∷ vArg (lit (nat 2)) ∷ [])))
    q ← quoteTC t
    unify q hole

kept : inspect ≡ def (quote _+_)
  (vArg (lit (nat 1)) ∷ vArg (lit (nat 2)) ∷ [])
kept = refl
```

```sh
agda --no-libraries --no-write-interfaces RestrictedPrimitive.agda
agda --no-libraries --no-write-interfaces --no-fast-reduce RestrictedPrimitive.agda
```

The observed difference matches the source-level gate ordering described in §5.1. It should be reproduced on a stock pinned build before filing a new upstream report. No issue or comment was posted.

## 11. Exploration log and remaining uncertainties

### Research routes followed

1. Retrieved #8860 and its comment count through GitHub; read the requested semantics and uniqueness concern.
2. Searched repository issues/PRs for reduction control, `withReduceDefs`, `onlyReduceDefs`, `dontReduceDefs`, uniqueness, `INJECTIVE_FOR_INFERENCE`, local abstraction, opacity/unfolding, and elaboration caching.
3. Followed direct history through #433, #1625, #6546, #6640, #6628, #5469, and #5898; followed recent failure modes through #8566, #8777, #8704, #8828, #8827/#8837, #7304, and #8230.
4. Read official Agda reflection, pragma, lossy-unification, and opacity documentation alongside implementation. Inspected existing regression examples for #5469, #8777, and #8828.
5. Followed paper links from discussions, then read the relevant theory, algorithm, and context-formation sections listed in §3. Checked current primary Lean/Rocq references to avoid projecting historical terminology onto current systems.
6. Traced `ReduceDefs` from its environment representation through reducers, conversion, reflection, declarations, constraints, closures, interaction, and indexing.
7. After the user's local-meta suggestion, traced allocation tracking, freezing, ordinary/direct assignment, pruning, in-place modality promotion, level defaulting, and the generalization warning about old metas with new representatives.
8. Ran the small experiments above. No implementation prototype, full test suite, standard-library benchmark, or TypeTopology benchmark was run.

### Nearby material considered but not used as central evidence

Search results concerning canonical type aliases (#7582), non-abstract variants (#8500), and reflection/rewrite behavior (#6088) indicated adjacent motivations, but were not pursued to the same depth. Other general subject-reduction and meta-pruning issues surfaced in searches; their existence is not treated as evidence of a new bug in this proposal. The preliminary opaque PR #6354 was located through later discussion, not independently reviewed as an implementation alternative.

### Questions that research alone does not settle

- Which real examples require control beyond conversion, especially with-abstraction normalization?
- **Resolved by D1:** direct containment of meta writes is enough; strict independence from older unresolved metas is not required.
- Should nested named where definitions share the root owner permanently, or receive an explicit sub-owner with inherited authority?
- Should explicit mutual groups be supported as one named unit, or require per-member signatures that prevent shared inference?
- Can a conservative pure-comparison mode deliver enough benefit to avoid opting into nonunique inference for common cases?
- Which primitive, projection, alias, and rewrite behaviors should eventually become part of the public contract?
- What is the cost of required baseline validation on the actual workloads that motivated the issue?

The evidence supports a scoped implementation project with clear invariants. It does not support a claim that existing `withReduceDefs` is already a uniform, proved-safe declaration annotation, nor that ownership alone resolves every semantic question.

### Interactive design decisions

| ID | Question | User decision | Consequence |
|---|---|---|---|
| D1 | Direct containment or prevention of all later influence on older metas? | A: direct containment | Guard restricted writes/refinements; preserve cross-owner constraints; permit later ordinary propagation |
| D2 | Does ownership include metas created while checking the signature? | A: signature and body | Establish the owner and attach the policy before signature checking; restricted body checking may solve signature metas |

Other recommendations remain provisional. The discussion will cover helper ownership, delayed work and mutual groups, uniqueness, hard restriction versus fallback, policy shape, affected phases, supported targets, syntax, nesting, reflection, feature combinations, diagnostics, and validation priorities.

## 12. Pinned implementation references

The links below are the main entry points used in the source audit; adjacent definitions in the same files are discussed above.

- [Policy representation and predicate][base-policy]
- [Ordinary reduction and special cases][reduce]; [fast reduction gate][fast]
- [Reflection declarations and legacy wrappers][reflection-api]; [reflection interpreter][unquote]
- [Explicit inference shortcut][conversion-shortcut]; [residual-head comparison][conversion-head]; [pure conversion][pure-conversion]
- [Closure representation][closures]; [closure restoration][enter-closure]
- [Meta assignment restrictions][assignment]; [meta service, allocation tracking, freezing][meta-service]
- [Occurs checking, modality promotion, and pruning][occurs]; [generalization provenance warning][generalization]
- [Declaration checking and cache][declarations]; [function checking and RHS rechecking][function-check]
- [Proof-relevant LHS unification][lhs]; [instance discrimination tree][discrim]
- [Inference-injectivity option documentation][pragma-doc]

[base-policy]: https://github.com/agda/agda/blob/ef326bb97c238796ee7ef0552d381666435d4714/src/full/Agda/TypeChecking/Monad/Base.hs#L3755
[reduce]: https://github.com/agda/agda/blob/ef326bb97c238796ee7ef0552d381666435d4714/src/full/Agda/TypeChecking/Reduce.hs#L717
[fast]: https://github.com/agda/agda/blob/ef326bb97c238796ee7ef0552d381666435d4714/src/full/Agda/TypeChecking/Reduce/Fast.hs#L127
[reflection-api]: https://github.com/agda/agda/blob/ef326bb97c238796ee7ef0552d381666435d4714/src/data/lib/prim/Agda/Builtin/Reflection.agda#L325
[unquote]: https://github.com/agda/agda/blob/ef326bb97c238796ee7ef0552d381666435d4714/src/full/Agda/TypeChecking/Unquote.hs#L735
[conversion-shortcut]: https://github.com/agda/agda/blob/ef326bb97c238796ee7ef0552d381666435d4714/src/full/Agda/TypeChecking/Conversion.hs#L198
[conversion-head]: https://github.com/agda/agda/blob/ef326bb97c238796ee7ef0552d381666435d4714/src/full/Agda/TypeChecking/Conversion.hs#L672
[pure-conversion]: https://github.com/agda/agda/blob/ef326bb97c238796ee7ef0552d381666435d4714/src/full/Agda/TypeChecking/Conversion/Pure.hs#L20
[closures]: https://github.com/agda/agda/blob/ef326bb97c238796ee7ef0552d381666435d4714/src/full/Agda/TypeChecking/Monad/Base.hs#L1620
[enter-closure]: https://github.com/agda/agda/blob/ef326bb97c238796ee7ef0552d381666435d4714/src/full/Agda/TypeChecking/Monad/Closure.hs#L11
[assignment]: https://github.com/agda/agda/blob/ef326bb97c238796ee7ef0552d381666435d4714/src/full/Agda/TypeChecking/MetaVars.hs#L934
[meta-service]: https://github.com/agda/agda/blob/ef326bb97c238796ee7ef0552d381666435d4714/src/full/Agda/TypeChecking/Monad/MetaVars.hs#L85
[occurs]: https://github.com/agda/agda/blob/ef326bb97c238796ee7ef0552d381666435d4714/src/full/Agda/TypeChecking/MetaVars/Occurs.hs#L262
[generalization]: https://github.com/agda/agda/blob/ef326bb97c238796ee7ef0552d381666435d4714/src/full/Agda/TypeChecking/Generalize.hs#L309
[declarations]: https://github.com/agda/agda/blob/ef326bb97c238796ee7ef0552d381666435d4714/src/full/Agda/TypeChecking/Rules/Decl.hs#L90
[function-check]: https://github.com/agda/agda/blob/ef326bb97c238796ee7ef0552d381666435d4714/src/full/Agda/TypeChecking/Rules/Def.hs#L740
[lhs]: https://github.com/agda/agda/blob/ef326bb97c238796ee7ef0552d381666435d4714/src/full/Agda/TypeChecking/Rules/LHS/Unify.hs#L1
[discrim]: https://github.com/agda/agda/blob/ef326bb97c238796ee7ef0552d381666435d4714/src/full/Agda/TypeChecking/DiscrimTree.hs#L112
[pragma-doc]: https://github.com/agda/agda/blob/ef326bb97c238796ee7ef0552d381666435d4714/doc/user-manual/language/pragmas.lagda.rst#L144
