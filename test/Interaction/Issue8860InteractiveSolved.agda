module Issue8860InteractiveSolved where

open import Agda.Builtin.Nat
open import Agda.Builtin.Equality

f : Nat → Nat
f zero = 3
f (suc n) = 3

-- The signature holes get solved while checking the proofs. Printing their
-- solutions must restore each signature's own policy.
{-# DONT_UNFOLD f #-}
blocked : f 0 ≡ {!!}
blocked = refl

{-# ONLY_UNFOLD f #-}
allowed : f 0 ≡ {!!}
allowed = refl

{-# UNFOLD_EVERYTHING #-}
reset : f 0 ≡ {!!}
reset = refl
