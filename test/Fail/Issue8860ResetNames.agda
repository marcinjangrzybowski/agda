module Issue8860ResetNames where
open import Agda.Builtin.Nat

f : Nat → Nat
f n = n

{-# UNFOLD_EVERYTHING f #-}
bad : Nat
bad = f 0
