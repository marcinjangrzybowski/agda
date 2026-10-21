{-# OPTIONS_GHC -Wunused-imports #-}

module Agda.TypeChecking.Monad.Closure where

import Control.Monad

import Agda.TypeChecking.Monad.Base
import Agda.TypeChecking.Monad.Env
import Agda.TypeChecking.Monad.State

{-# INLINE enterClosure #-}
enterClosure :: (MonadTCEnv m, ReadTCState m, LensClosure c a)
             => c -> (a -> m b) -> m b
enterClosure c k | Closure _sig env scope cps x <- c ^. lensClosure = do
  isDbg <- viewTC eIsDebugPrinting
  owner <- viewTC eRestrictedMetaOwner
  phase <- viewTC eElaborationReduction
  policy <- viewTC eElaborationReduceDefs
  let combine Nothing p = p
      combine p Nothing = p
      combine (Just p) (Just q) = Just (intersectReduceDefs p q)
  evalWithScope scope
      -- TODO: use the signature here? would that fix parts of issue #118?
    $ locallyTCState stModuleCheckpoints (const cps)
    $ withEnv (env & eIsDebugPrinting .~ isDbg
                   & eRestrictedMetaOwner %~ maybe id (const . Just) owner
                   & eElaborationReduceDefs %~ combine policy
                   & eElaborationReduction %~ \ p ->
                       if phase == ElaborationDisabled then ElaborationDisabled else p)
    $ k x

{-# INLINE withClosure  #-}
withClosure :: (MonadTCEnv m, ReadTCState m) => Closure a -> (a -> m b) -> m (Closure b)
withClosure cl k = enterClosure cl $ k >=> buildClosure

{-# INLINE mapClosure  #-}
mapClosure :: (MonadTCEnv m, ReadTCState m) => (a -> m b) -> Closure a -> m (Closure b)
mapClosure = flip withClosure
