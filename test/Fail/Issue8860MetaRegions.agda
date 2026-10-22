{-# OPTIONS --safe #-}
module Issue8860MetaRegions where

open import Agda.Builtin.Nat
open import Agda.Builtin.Equality

f : Nat → Nat
f n = n

-- Like #8837's abstract/opaque check, annotated checking cannot solve a
-- meta created outside its region. Deferred work must retain this boundary.
outside : Nat
outside = 0
  where
  N : Set
  N = _

  {-# DONT_UNFOLD f #-}
  force : N ≡ Nat
  force = refl

-- A nested annotation starts a new region, even with an identical policy.
{-# DONT_UNFOLD f #-}
nested : Nat
nested = 0
  where
  N : Set
  N = _

  {-# DONT_UNFOLD f #-}
  force : N ≡ Nat
  force = refl

-- Resetting unfolding does not grant permission to solve a parent's meta.
{-# DONT_UNFOLD f #-}
reset : Nat
reset = 0
  where
  N : Set
  N = _

  {-# UNFOLD_EVERYTHING #-}
  force : N ≡ Nat
  force = refl
