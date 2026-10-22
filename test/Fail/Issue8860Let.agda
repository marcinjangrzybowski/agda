module Issue8860Let where
open import Agda.Builtin.Nat

bad : Nat
bad = let {-# UNFOLD_EVERYTHING #-}
          x : Nat
          x = 0
      in x
