module Issue8860Placement where
open import Agda.Builtin.Nat

bad : Nat
{-# DONT_UNFOLD #-}
bad = 0
