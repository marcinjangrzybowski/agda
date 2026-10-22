module Issue8860Interactive where

open import Agda.Builtin.Nat
open import Agda.Builtin.Equality

f : Nat → Nat
f zero = 3
f (suc n) = 3

g : Nat → Nat
g zero = 5
g (suc n) = 5

proof : f 0 ≡ 3
proof = refl

{-# DONT_UNFOLD f #-}
blocked : (p : f 0 ≡ 3) → f 0 ≡ 3
blocked p = {!!}
  where
  {-# ONLY_UNFOLD f #-}
  allowed : f 0 ≡ 3
  allowed = {!!}

  {-# UNFOLD_EVERYTHING #-}
  reset : f 0 ≡ 3
  reset = {!!}

  inherited : f 0 ≡ 3
  inherited = {!!}

ordinary : f 0 ≡ 3
ordinary = {!!}

{-# DONT_UNFOLD f #-}
with-let : Nat
with-let = let n = f 0 in {!!}

HiddenNat : Set
HiddenNat = Nat

-- These operations need ordinary reduction to see the datatype's shape.
{-# DONT_UNFOLD HiddenNat #-}
split : HiddenNat → Nat
split n = {!!}

{-# DONT_UNFOLD HiddenNat #-}
introduce : HiddenNat
introduce = {!!}

identity : {A : Set} → A → A
identity x = x

-- Projection-like postprocessing must not unfold a denied function either.
{-# DONT_UNFOLD identity f #-}
elaborate : Nat
elaborate = {!!}
