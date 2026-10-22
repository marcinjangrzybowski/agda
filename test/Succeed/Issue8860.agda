{-# OPTIONS --safe #-}

module Issue8860 where

open import Agda.Builtin.Nat
open import Agda.Builtin.Equality
open import Agda.Builtin.Bool
open import Agda.Builtin.List
open import Agda.Builtin.Sigma
open import Agda.Builtin.Unit
open import Agda.Builtin.Reflection renaming (bindTC to _>>=_)

pattern vArg t = arg (arg-info visible (modality relevant quantity-ω)) t
pattern hArg t = arg (arg-info hidden (modality relevant quantity-ω)) t

f : Nat → Nat
f zero = 3
f (suc n) = 3

g : Nat → Nat
g n = n
{-# NOINLINE g #-}

macro
  normalForm : Term → Term → TC ⊤
  normalForm t hole = do
    t ← normalise t
    t ← quoteTC t
    unify hole t

  reflectedOnlyF : Term → Term → TC ⊤
  reflectedOnlyF t hole = withReduceDefs (true , (quote f ∷ [])) do
    t ← normalise t
    t ← quoteTC t
    unify hole t

  reflectedDenyF : Term → Term → TC ⊤
  reflectedDenyF t hole = withReduceDefs (false , (quote f ∷ [])) do
    t ← normalise t
    t ← quoteTC t
    unify hole t

-- Directives apply to ordinary conversion, not the definition's uses.
{-# DONT_UNFOLD f #-}
deny : Term
deny = normalForm (g (f 0))

deny-result : deny ≡ def (quote f) (vArg (lit (nat 0)) ∷ [])
deny-result = refl

{-# ONLY_UNFOLD g #-}
allow : Term
allow = normalForm (g (f 0))

allow-result : allow ≡ deny
allow-result = refl

-- Both functions can be kept folded; empty allow/deny lists are syntax errors.
{-# DONT_UNFOLD f g #-}
none : Term
none = normalForm (g (f 0))

none-result : none ≡ def (quote g) (vArg (def (quote f) (vArg (lit (nat 0)) ∷ [])) ∷ [])
none-result = refl

{-# UNFOLD_EVERYTHING #-}
all : Term
all = normalForm (g (f 0))

all-result : all ≡ lit (nat 3)
all-result = refl

-- The last directive on one declaration sets its policy.
{-# ONLY_UNFOLD f #-}
{-# DONT_UNFOLD f #-}
mixed : Term
mixed = normalForm (g (f 0))

mixed-result : mixed ≡ deny
mixed-result = refl

{-# ONLY_UNFOLD f #-}
{-# ONLY_UNFOLD g #-}
replace-allow : Term
replace-allow = normalForm (g (f 0))

replace-allow-result : replace-allow ≡ deny
replace-allow-result = refl

{-# DONT_UNFOLD f #-}
{-# DONT_UNFOLD g #-}
replace-deny : Term
replace-deny = normalForm (g (f 0))

replace-deny-result : replace-deny ≡ def (quote g) (vArg (lit (nat 3)) ∷ [])
replace-deny-result = refl

{-# DONT_UNFOLD f g #-}
{-# UNFOLD_EVERYTHING #-}
replace-reset : Term
replace-reset = normalForm (g (f 0))

replace-reset-result : replace-reset ≡ all
replace-reset-result = refl

{-# UNFOLD_EVERYTHING #-}
{-# ONLY_UNFOLD g #-}
after-reset : Term
after-reset = normalForm (g (f 0))

after-reset-result : after-reset ≡ deny
after-reset-result = refl

-- A nested annotation replaces the enclosing policy and can reopen a name.
{-# DONT_UNFOLD f #-}
nested : Term
nested = helper
  where
  {-# ONLY_UNFOLD f g #-}
  helper : Term
  helper = normalForm (g (f 0))

nested-result : nested ≡ all
nested-result = refl

-- Allow/allow: the inner allow list replaces the outer allow list.
{-# ONLY_UNFOLD g #-}
nested-allow : Term
nested-allow = helper
  where
  {-# ONLY_UNFOLD f #-}
  helper : Term
  helper = normalForm (g (f 0))

nested-allow-result : nested-allow ≡ def (quote g) (vArg (lit (nat 3)) ∷ [])
nested-allow-result = refl

-- Allow/deny: an inner deny list may allow names excluded by the outer list.
{-# ONLY_UNFOLD f #-}
nested-deny : Term
nested-deny = helper
  where
  {-# DONT_UNFOLD f #-}
  helper : Term
  helper = normalForm (g (f 0))

nested-deny-result : nested-deny ≡ deny
nested-deny-result = refl

-- Deny/deny also replaces: the earlier denial of f is forgotten.
{-# DONT_UNFOLD f #-}
nested-deny-deny : Term
nested-deny-deny = helper
  where
  {-# DONT_UNFOLD g #-}
  helper : Term
  helper = normalForm (g (f 0))

nested-deny-deny-result : nested-deny-deny ≡ nested-allow
nested-deny-deny-result = refl

-- UNFOLD_EVERYTHING resets a deny list.
{-# DONT_UNFOLD f #-}
nested-reset : Term
nested-reset = helper
  where
  {-# UNFOLD_EVERYTHING #-}
  helper : Term
  helper = normalForm (g (f 0))

nested-reset-result : nested-reset ≡ all
nested-reset-result = refl

-- UNFOLD_EVERYTHING resets an allow list as well.
{-# ONLY_UNFOLD f #-}
nested-allow-reset : Term
nested-allow-reset = helper
  where
  {-# UNFOLD_EVERYTHING #-}
  helper : Term
  helper = normalForm (g (f 0))

nested-allow-reset-result : nested-allow-reset ≡ all
nested-allow-reset-result = refl

-- Each level replaces its predecessor; no earlier denial may reappear.
{-# DONT_UNFOLD f #-}
nested-new-denial : Term
nested-new-denial = denying
  where
  {-# DONT_UNFOLD g #-}
  denying : Term
  denying = allowing
    where
    {-# ONLY_UNFOLD f g #-}
    allowing : Term
    allowing = fresh-denial
      where
      {-# DONT_UNFOLD g #-}
      fresh-denial : Term
      fresh-denial = normalForm (g (f 0))

nested-new-denial-result : nested-new-denial ≡ nested-allow
nested-new-denial-result = refl

-- After a nested override, a later unannotated sibling inherits the outer one.
{-# DONT_UNFOLD f #-}
nested-restored : Term
nested-restored = after
  where
  {-# ONLY_UNFOLD f g #-}
  inner : Term
  inner = normalForm (g (f 0))

  after : Term
  after = normalForm (g (f 0))

nested-restored-result : nested-restored ≡ deny
nested-restored-result = refl

-- Reflection composes with the lexical policy; macro computation still runs.
{-# ONLY_UNFOLD g #-}
macro-allow : Term
macro-allow = reflectedOnlyF (g (f 0))

macro-allow-result : macro-allow ≡ none
macro-allow-result = refl

{-# ONLY_UNFOLD f g #-}
macro-deny : Term
macro-deny = reflectedDenyF (g (f 0))

macro-deny-result : macro-deny ≡ deny
macro-deny-result = refl

-- Resetting the source policy retains the macro's independent filter.
{-# DONT_UNFOLD f #-}
macro-reset : Term
macro-reset = helper
  where
  {-# UNFOLD_EVERYTHING #-}
  helper : Term
  helper = reflectedDenyF (g (f 0))

macro-reset-result : macro-reset ≡ deny
macro-reset-result = refl

-- Signature metas belong to the same declaration as the clauses.
{-# DONT_UNFOLD f g #-}
inferred : _
inferred = suc zero

inferred-result : inferred ≡ 1
inferred-result = refl

{-# DONT_UNFOLD f #-}
helper-inference : _
helper-inference = helper
  where
  helper : _
  helper = suc zero

helper-inference-result : helper-inference ≡ 1
helper-inference-result = refl

-- An unannotated helper may solve a meta from the enclosing region.
{-# DONT_UNFOLD f #-}
shared-region : Nat
shared-region = 0
  where
  N : Set
  N = _

  force : N ≡ Nat
  force = refl

-- An explicit reset still permits solving the definition's own signature.
{-# UNFOLD_EVERYTHING #-}
reset-inferred : _
reset-inferred = suc zero

reset-inferred-result : reset-inferred ≡ 1
reset-inferred-result = refl

-- The function remains transparent at use sites.
{-# DONT_UNFOLD f #-}
ordinary : Nat
ordinary = f 0

ordinary-result : ordinary ≡ 3
ordinary-result = refl

data Vec (A : Set) : Nat → Set where
  [] : Vec A zero
  _∷_ : ∀ {n} → A → Vec A n → Vec A (suc n)

double : Nat → Nat
double n = n + n

big : Nat
big = 50

{-# DONT_UNFOLD big #-}
cast : ∀ {A} → Vec A (big + big) → Vec A (double big)
cast xs = xs

-- Unannotated local declarations and generated helpers inherit the policy.
{-# DONT_UNFOLD f #-}
inherited : Term
inherited = helper
  where
  helper : Term
  helper = normalForm (g (f 0))

inherited-result : inherited ≡ deny
inherited-result = refl

{-# DONT_UNFOLD f #-}
with-helper : Nat → Term
with-helper n with n
... | zero = normalForm (g (f 0))
... | suc n = normalForm (g (f 0))

with-result : with-helper 0 ≡ deny
with-result = refl

{-# DONT_UNFOLD f #-}
lambda-helper : Nat → Term
lambda-helper = λ { zero → normalForm (g (f 0))
                  ; (suc n) → normalForm (g (f 0)) }

lambda-result : lambda-helper 1 ≡ deny
lambda-result = refl

-- A foreign meta can be solved independently by its own declaration; the
-- postponed equation can then be checked without assigning that meta.
earlier : _

{-# DONT_UNFOLD f #-}
later : Nat
later = earlier

earlier = 0

later-result : later ≡ 0
later-result = refl

-- Projection-like functions remain ordinary functions for this policy.
identity : {A : Set} → A → A
identity x = x

{-# DONT_UNFOLD identity #-}
projection-like : Term
projection-like = normalForm (identity zero)

projection-like-result : projection-like ≡ def (quote identity) (hArg (def (quote Nat) []) ∷ vArg (lit (nat 0)) ∷ [])
projection-like-result = refl
