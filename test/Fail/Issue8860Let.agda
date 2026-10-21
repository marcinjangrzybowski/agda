module Issue8860Let where
open import Agda.Builtin.Nat

bad : Nat
bad = let {-# ONLY_UNFOLD #-}
          x : Nat
          x = 0
      in x
