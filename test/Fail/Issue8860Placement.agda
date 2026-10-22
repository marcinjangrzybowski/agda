module Issue8860Placement where
open import Agda.Builtin.Nat

bad : Nat
{-# UNFOLD_EVERYTHING #-}
bad = 0
