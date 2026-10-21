module Issue8860Projection where
open import Agda.Builtin.Nat
open import Agda.Builtin.Sigma

{-# DONT_UNFOLD fst #-}
bad : Nat
bad = 0
