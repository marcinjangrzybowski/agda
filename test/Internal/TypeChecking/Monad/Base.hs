{-# LANGUAGE TemplateHaskell #-}

module Internal.TypeChecking.Monad.Base ( tests ) where

import Agda.Syntax.Abstract.Name (QName, qualify, noModuleName)
import Agda.Syntax.Common (MetaId)
import Agda.Syntax.Internal (Term(..), mkType, unblockOnMeta)
import Agda.TypeChecking.Monad
import Agda.TypeChecking.MetaVars ()
import Agda.TypeChecking.Constraints ()
import Agda.TypeChecking.Substitute (sort)

import Agda.Utils.Lens
import Agda.Utils.Permutation (idP)
import qualified Data.Set as Set

import Internal.Helpers

------------------------------------------------------------------------
-- Instances

instance Arbitrary Simplification where
  arbitrary = elements [ YesSimplification, NoSimplification ]

------------------------------------------------------------------------------
-- Properties

-- | 'Simplification' is a monoid.
prop_monoid_Simplification :: Property3 Simplification
prop_monoid_Simplification = isMonoid

-- Use the real low-level assignment path: it deliberately skips the frozen
-- check, so temporary freezing would not provide the required isolation.
prop_restrictedMetaAssignment :: Property
prop_restrictedMetaAssignment = tcmProperty $ do
  owner <- testOwner
  old <- testMeta =<< createMetaInfo
  oldInfo <- mvInfo <$> lookupLocalMeta old
  (blocked, copiedBlocked, localSolved, oldOpen) <- restricted owner $ do
    local <- testMeta =<< createMetaInfo
    copied <- testMeta oldInfo
    blocked <- assignmentBlocked old
    copiedBlocked <- assignmentBlocked copied
    assignTerm' local [] (Sort $ mkType 0)
    localSolved <- isInstantiatedMeta local
    oldOpen <- isOpenMeta . mvInstantiation <$> lookupLocalMeta old
    pure (blocked, copiedBlocked, localSolved, oldOpen)
  assignTerm' old [] (Sort $ mkType 0)
  laterSolved <- isInstantiatedMeta old
  pure $ and [blocked, copiedBlocked, localSolved, oldOpen, laterSolved]

-- Entering the old meta's creation closure must not grant permission to write
-- it. A structural check must also keep its baseline reduction phase there.
prop_restrictedMetaClosure :: Property
prop_restrictedMetaClosure = tcmProperty $ do
  a <- testOwner
  b <- testOwner
  cl <- restricted a $ locallyTC eElaborationReduceDefs
          (const $ Just $ OnlyReduceDefs $ Set.singleton a) $ buildClosure ()
  restricted b $ locallyTC eElaborationReduceDefs
      (const $ Just $ DontReduceDefs $ Set.singleton a) $
    withoutElaborationReduction $ enterClosure cl $ \ () ->
      withElaborationReduction $ do
        authority <- viewTC eRestrictedMetaOwner
        provenance <- viewTC eDefinitionOwner
        phase <- viewTC eElaborationReduction
        policy <- viewTC eElaborationReduceDefs
        pure $ authority == Just b && provenance == Just a
            && phase == ElaborationDisabled
            && policy == Just (OnlyReduceDefs Set.empty)

-- Cross-owner obligations are retained and cannot be solved by an eager
-- wakeup inside the restricted declaration. Ordinary solving may solve them.
prop_restrictedMetaDeferredConstraint :: Property
prop_restrictedMetaDeferredConstraint = tcmProperty $ do
  owner <- testOwner
  old <- testMeta =<< createMetaInfo
  untouched <- restricted owner $ do
    addConstraint (unblockOnMeta old) $
      ValueCmp CmpEq (AsTermsOf $ sort $ mkType 1) (MetaV old []) (Sort $ mkType 0)
    solveAwakeConstraints
    isOpenMeta . mvInstantiation <$> lookupLocalMeta old
  pending <- getAwakeConstraints
  solveAwakeConstraints
  solved <- isInstantiatedMeta old
  remaining <- getAwakeConstraints
  pure $ untouched && length pending == 1 && solved && null remaining

-- Assigning a local meta can wake an older eta listener. Do not lose that
-- listener when clearing the assigned meta's listener set.
prop_restrictedMetaEtaListener :: Property
prop_restrictedMetaEtaListener = tcmProperty $ do
  owner <- testOwner
  old <- testMeta =<< createMetaInfo
  pending <- restricted owner $ do
    local <- testMeta =<< createMetaInfo
    listenToMeta (EtaExpand old) local
    assignTerm' local [] (Sort $ mkType 0)
    solveAwakeConstraints
    getAwakeConstraints
  let queued = case map (clValue . theConstraint) pending of
        [ExpandMeta m] -> m == old
        _ -> False
  solveAwakeConstraints
  remaining <- getAwakeConstraints
  pure $ queued && null remaining

testOwner :: TCM QName
testOwner = qualify noModuleName <$> freshName_ ("owner" :: String)

restricted :: QName -> TCM a -> TCM a
restricted q = localTC $ set eDefinitionOwner (Just q) . set eRestrictedMetaOwner (Just q)

testMeta :: MetaInfo -> TCM MetaId
testMeta info = newMeta Instantiable info normalMetaPriority (idP 0) $
  HasType () CmpEq (sort $ mkType 1)

assignmentBlocked :: MetaId -> TCM Bool
assignmentBlocked m = catchPatternErr (pure . (== unblockOnMeta m)) $
  False <$ assignTerm' m [] (Sort $ mkType 0)

tcmProperty :: TCM Bool -> Property
tcmProperty action = once $ ioProperty $ runTCMTop action >>= \case
  Left err -> pure $ counterexample (show err) False
  Right ok -> pure $ property ok

------------------------------------------------------------------------
-- * All tests
------------------------------------------------------------------------

-- Template Haskell hack to make the following $allProperties work
-- under ghc-7.8.
return [] -- KEEP!

-- | All tests as collected by 'allProperties'.
--
-- Using 'allProperties' is convenient and superior to the manual
-- enumeration of tests, since the name of the property is added
-- automatically.

tests :: TestTree
tests = testProperties "Internal.TypeChecking.Monad.Base" $allProperties
