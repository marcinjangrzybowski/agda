module Issue8860Nested where

open import Agda.Builtin.Nat
open import Agda.Builtin.Equality

f : Nat → Nat
f zero = 3
f (suc n) = 3

proof : f 0 ≡ 3
proof = refl

{-# DONT_UNFOLD f #-}
outer : Nat
outer = zero
  where
  {-# ONLY_UNFOLD f #-}
  allowed : f 0 ≡ 3
  allowed = {!!}

  {-# UNFOLD_EVERYTHING #-}
  reset : f 0 ≡ 3
  reset = {!!}

  inherited : f 0 ≡ 3
  inherited = {!!}
