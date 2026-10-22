module Issue8860Mutual where
open import Agda.Builtin.Nat

mutual
  {-# UNFOLD_EVERYTHING #-}
  bad : Nat
  bad = 0
