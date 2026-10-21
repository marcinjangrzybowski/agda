module Issue8860Mutual where
open import Agda.Builtin.Nat

mutual
  {-# ONLY_UNFOLD #-}
  bad : Nat
  bad = 0
