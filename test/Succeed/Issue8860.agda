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

-- Both directives apply to ordinary conversion, not the definition's uses.
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

-- An empty allow list disables all ordinary function unfolding in the
-- controlled operations. An empty deny list imposes no restriction.
{-# ONLY_UNFOLD #-}
none : Term
none = normalForm (g (f 0))

none-result : none ≡ def (quote g) (vArg (def (quote f) (vArg (lit (nat 0)) ∷ [])) ∷ [])
none-result = refl

{-# DONT_UNFOLD #-}
all : Term
all = normalForm (g (f 0))

all-result : all ≡ lit (nat 3)
all-result = refl

-- Repeated directives intersect their permissions.
{-# ONLY_UNFOLD f g #-}
{-# DONT_UNFOLD f #-}
mixed : Term
mixed = normalForm (g (f 0))

mixed-result : mixed ≡ deny
mixed-result = refl

{-# ONLY_UNFOLD f #-}
{-# ONLY_UNFOLD g #-}
intersection : Term
intersection = normalForm (g (f 0))

intersection-result : intersection ≡ none
intersection-result = refl

-- A nested allow list cannot reopen a name denied by the enclosing policy.
{-# DONT_UNFOLD f #-}
nested : Term
nested = helper
  where
  {-# ONLY_UNFOLD f g #-}
  helper : Term
  helper = normalForm (g (f 0))

nested-result : nested ≡ deny
nested-result = refl

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

-- Signature metas belong to the same declaration as the clauses.
{-# ONLY_UNFOLD #-}
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

-- A cross-owner obligation in an inferred mutual group may be solved later
-- by ordinary checking. The internal tests check that it is deferred first.
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
