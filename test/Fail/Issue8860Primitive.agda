module Issue8860Primitive where
open import Agda.Builtin.Nat

{-# DONT_UNFOLD _+_ #-}
bad : Nat
bad = 0
