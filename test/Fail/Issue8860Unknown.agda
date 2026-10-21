module Issue8860Unknown where
open import Agda.Builtin.Nat

{-# ONLY_UNFOLD missing #-}
bad : Nat
bad = 0
