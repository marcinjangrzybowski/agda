{-# OPTIONS --safe #-}
module Issue8860Nested where

open import Agda.Builtin.Nat
open import Agda.Builtin.Equality

2^_ : Nat → Nat
2^ zero = 1
2^ (suc x) = (2^ x) + (2^ x)

pickThird : Nat → Nat → Nat → Nat
pickThird y z x = x

-- The outer conversion inherits the denial, so it stays symbolic.
-- The inner proof replaces it with an allow list and computes the small power.
-- Keep the powers modest because the test runner also rechecks the elaborated
-- term with --double-check, which deliberately uses ordinary reduction.
{-# DONT_UNFOLD 2^_ #-}
_ : Set
_ = Nat
  where
  z : pickThird (2^ 10) (2^ 9) (2^ 8) ≡ (2^ 8)
  z = refl
    where
    {-# ONLY_UNFOLD 2^_ #-}
    y : 8 ≡ (2^ 3)
    y = refl
