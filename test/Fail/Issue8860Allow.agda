module Issue8860Allow where
open import Agda.Builtin.Nat
open import Agda.Builtin.Equality

f : Nat → Nat
f zero = 3
f (suc n) = 3

g : Nat → Nat
g n = n

{-# ONLY_UNFOLD g #-}
blocked : f 0 ≡ 3
blocked = refl
