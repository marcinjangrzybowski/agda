{-# OPTIONS --cubical #-}
module Issue8860InteractiveCubical where

open import Agda.Builtin.Nat
open import Agda.Builtin.Cubical.Path

f : Nat → Nat
f zero = 3
f (suc n) = 3

-- The wanted endpoints have already been computed by structural checking.
-- Display cannot refold them. Newly inferred actual endpoints must respect
-- the selected goal's policy: f 0 below, but 3 in the allowed goal.
{-# DONT_UNFOLD f #-}
blocked : f 0 ≡ f 0
blocked i = {!!}

{-# ONLY_UNFOLD f #-}
allowed : f 0 ≡ f 0
allowed i = {!!}
