{-# LANGUAGE TemplateHaskell #-}

module Internal.TypeChecking.Monad.Base ( tests ) where

import Agda.Syntax.Abstract.Name (QName, qualify, noModuleName)
import Agda.Interaction.Base (Rewrite(..))
import Agda.Interaction.BasicOps (normalFormForDisplay, normalFormClosureForDisplay)
import Agda.Syntax.Common (MetaId, defaultArgInfo)
import Agda.Syntax.Internal (Term(..), Clause(..), ClauseRecursive(..), WakeUp(..), mkType, unblockOnMeta)
import Agda.TypeChecking.CompiledClause qualified as CC
import Agda.TypeChecking.Monad
import Agda.TypeChecking.MetaVars ()
import Agda.TypeChecking.Constraints ()
import Agda.TypeChecking.Substitute (sort)
import Agda.TypeChecking.Reduce (normalise)

import Agda.Utils.Lens
import Agda.Utils.Permutation (idP)
import Agda.Utils.Null (empty)
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
-- The closure's lexical unfolding policy is restored, not intersected with
-- the caller's policy: that would undo a nested override on resumption.
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
            && policy == Just (OnlyReduceDefs $ Set.singleton a)

-- A postponed equation retains its original authority even when woken from
-- ordinary checking. The foreign meta must be solved independently first.
prop_restrictedMetaDeferredConstraint :: Property
prop_restrictedMetaDeferredConstraint = tcmProperty $ do
  owner <- testOwner
  old <- testMeta =<< createMetaInfo
  untouched <- restricted owner $ do
    addConstraint (unblockOnMeta old) $
      ValueCmp CmpEq (AsTermsOf $ sort $ mkType 1) (MetaV old []) (Sort $ mkType 0)
    solveAwakeConstraints
    isOpenMeta . mvInstantiation <$> lookupLocalMeta old
  pending <- getAllConstraints
  let retained = case pending of
        [c] -> view eRestrictedMetaOwner (clEnv $ theConstraint c) == Just owner
        _ -> False
  wakeConstraints $ const WakeUp
  solveAwakeConstraints
  stillOpen <- isOpenMeta . mvInstantiation <$> lookupLocalMeta old
  assignTerm' old [] (Sort $ mkType 0)
  solveAwakeConstraints
  remaining <- getAllConstraints
  pure $ untouched && retained && stillOpen && null remaining

-- An explicitly annotated child has a separate region, even with the same
-- policy. Resetting unfolding does not permit it to solve its parent's metas.
prop_restrictedNestedMetaRegion :: Property
prop_restrictedNestedMetaRegion = tcmProperty $ do
  parent <- testOwner
  child <- testOwner
  restricted parent $ do
    outer <- testMeta =<< createMetaInfo
    (blocked, localSolved) <- restricted child $
      locallyTC eElaborationReduceDefs (const $ Just reduceAllDefs) $ do
        blocked <- assignmentBlocked outer
        local <- testMeta =<< createMetaInfo
        assignTerm' local [] (Sort $ mkType 0)
        solved <- isInstantiatedMeta local
        pure (blocked, solved)
    assignTerm' outer [] (Sort $ mkType 0)
    outerSolved <- isInstantiatedMeta outer
    pure $ blocked && localSolved && outerSolved

-- Assigning a local meta can wake an older eta listener. Do not lose that
-- listener when clearing the assigned meta's listener set.
prop_restrictedMetaEtaListener :: Property
prop_restrictedMetaEtaListener = tcmProperty $ do
  owner <- testOwner
  target <- testOwner
  old <- restricted target $ locallyTC eElaborationReduceDefs
          (const $ Just $ DontReduceDefs $ Set.singleton target) $
    testMeta =<< createMetaInfo
  pending <- restricted owner $ do
    local <- testMeta =<< createMetaInfo
    listenToMeta (EtaExpand old) local
    assignTerm' local [] (Sort $ mkType 0)
    solveAwakeConstraints
    getAwakeConstraints
  let queued = case pending of
        [c] | ExpandMeta m <- clValue $ theConstraint c ->
          let env = clEnv $ theConstraint c in
          m == old && view eRestrictedMetaOwner env == Just target &&
          view eElaborationReduceDefs env == Just (DontReduceDefs $ Set.singleton target)
        _ -> False
  solveAwakeConstraints
  remaining <- getAwakeConstraints
  pure $ queued && null remaining

-- Display is a fresh read-only operation. A meta created during structural
-- checking still has a lexical policy; displaying it must not change the
-- caller's structural phase or grant permission to assign a foreign meta.
prop_interactiveReduction :: Property
prop_interactiveReduction = tcmProperty $ do
  (f, body) <- testReducibleFunction
  owner <- testOwner
  old <- testMeta =<< createMetaInfo
  restricted owner $ locallyTC eElaborationReduceDefs
    (const $ Just $ DontReduceDefs $ Set.singleton f) $
    withoutElaborationReduction $ do
      let term = Def f []
      before <- mayRefineMeta old
      displayed <- normalFormForDisplay Normalised term
      ordinary <- normalise term
      after <- mayRefineMeta old
      phase <- viewTC eElaborationReduction
      authority <- viewTC eRestrictedMetaOwner
      pure $ displayed == term && ordinary == body &&
        not before && not after && phase == ElaborationDisabled && authority == Just owner

-- Each constraint keeps its creation policy even when displayed from a goal
-- with a different policy. Neither the stored payload nor its closure metadata
-- may be rewritten by display normalization.
prop_interactiveConstraintClosure :: Property
prop_interactiveConstraintClosure = tcmProperty $ do
  (f, body) <- testReducibleFunction
  owner <- testOwner
  caller <- testOwner
  let term = Def f []
      constraint = ValueCmp CmpEq (AsTermsOf $ sort $ mkType 1) term body
      capture policy = restricted owner $ locallyTC eElaborationReduceDefs
        (const $ Just policy) $ withoutElaborationReduction $ buildClosure constraint
  denied <- capture $ DontReduceDefs $ Set.singleton f
  allowed <- capture $ OnlyReduceDefs $ Set.singleton f
  restricted caller $ locallyTC eElaborationReduceDefs
    (const $ Just $ DontReduceDefs $ Set.singleton f) $ do
      denied' <- normalFormClosureForDisplay Normalised denied
      allowed' <- normalFormClosureForDisplay Normalised allowed
      phase <- viewTC eElaborationReduction
      authority <- viewTC eRestrictedMetaOwner
      let saved cl = view eRestrictedMetaOwner (clEnv cl) == Just owner &&
                     view eElaborationReduction (clEnv cl) == ElaborationDisabled
          sides cl expected = case clValue cl of
            ValueCmp CmpEq _ lhs rhs -> lhs == expected && rhs == body
            _ -> False
      pure $ sides denied' term && sides allowed' body &&
        sides allowed term && saved denied' && saved allowed' &&
        phase == ElaborationInactive && authority == Just caller

testReducibleFunction :: TCM (QName, Term)
testReducibleFunction = do
  f <- testOwner
  fun <- emptyFunctionData
  let body = Sort $ mkType 0
      def = FunctionDefn $ fun
        { _funClauses = [(empty :: Clause) { clauseBody = Just body }]
        , _funCompiled = Just $ CC.Done 0 NotRecursive [] body
        , _funTerminates = Just True
        }
  addConstant' f defaultArgInfo (sort $ mkType 1) def
  pure (f, body)

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
