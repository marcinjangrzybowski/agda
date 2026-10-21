module Issue8860Deny where
open import Agda.Builtin.Nat
open import Agda.Builtin.Equality

f : Nat → Nat
f zero = 3
f (suc n) = 3

{-# DONT_UNFOLD f #-}
blocked : f 0 ≡ 3
blocked = refl
