module Issue8860 where

open import Agda.Builtin.Nat
open import Agda.Builtin.Equality

f : Nat → Nat
f zero = 3
f (suc n) = 3

proof : f 0 ≡ 3
proof = refl

{-# DONT_UNFOLD f #-}
blocked : f 0 ≡ 3
blocked = {!!}

{-# DONT_UNFOLD f #-}
local-meta : _
local-meta = {!!}
