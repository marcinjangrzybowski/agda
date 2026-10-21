{-# OPTIONS --safe #-}
module Issue8860Coverage where
open import Agda.Builtin.Nat

f : Nat → Nat
f zero = 0
f (suc n) = 0

data D : Nat → Set where
  c : D (f 0)

-- Keeping f folded must not justify an absurd clause: the indices are equal.
{-# DONT_UNFOLD f #-}
bad : D (f 1) → Nat
bad ()
