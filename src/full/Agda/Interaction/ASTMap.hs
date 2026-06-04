module Agda.Interaction.ASTMap
  ( buildAstMapFromExprLike
  , WrapperMode(..)
  ) where

import Prelude
import Control.Monad (void)
import Control.Monad.State.Strict (State, execState, get, put)
import Data.Word  (Word32)
import qualified Data.IntMap.Strict as IM
import qualified Data.DList         as DL

import Agda.Syntax.Position
  ( HasRange(getRange), rangeToPosPair )
import Agda.Syntax.Abstract.Views
  ( ExprLike(..) )  -- needs foldExprLike + ctorName + isWrapper from your instance(s)

import Agda.Interaction.Response.Base
  ( AstPositions(..)
  , AstNodeId
  , AstNode(..)
  , AstMapPayload(..)
  )

--------------------------------------------------------------------------------
-- Public API

-- | How to treat \"wrapper\" nodes supplied by 'isWrapper'.
--   'OpaqueWrappers' means wrappers are not emitted as AST nodes (their single
--   child is effectively spliced in their place). 'IncludeWrappers' preserves
--   the original nodes exactly as produced by the 'ExprLike' fold.
data WrapperMode
  = IncludeWrappers
  | OpaqueWrappers
  deriving (Eq, Show)

-- | Build a whole-file *forest* AST map from any list of 'ExprLike' values.
--   - 'AstPositions' selects the coordinate system (recommended: 'AstCodepoint').
--   - UTF-8 is assumed globally (no encoding in the payload by design).
--   - 'WrapperMode' chooses whether 'isWrapper' nodes are included as nodes
--     ('IncludeWrappers') or treated as transparent ('OpaqueWrappers').
buildAstMapFromExprLike
  :: forall a. ExprLike a
  => WrapperMode    -- ^ wrapper handling
  -> AstPositions   -- ^ coordinate system
  -> [a]            -- ^ roots
  -> AstMapPayload
buildAstMapFromExprLike wmode posKind roots =
  let
    Build{ bNodes = nodesMap, bOrder = order, bTopLevel = tops } =
      buildByTraversal wmode roots

    orderedNodes :: [AstNode]
    orderedNodes = map (\i -> nodesMap IM.! i2i i) order
  in
    AstMapPayload
      { astPositions   = posKind
      , astTopLevel    = tops
      , astNodes       = orderedNodes
      }

--------------------------------------------------------------------------------
-- Internals

-- A single AST node harvested from an 'ExprLike' traversal.
data FlatNode = FlatNode
  { fnKind :: !String
  , fnBeg  :: !Word32
  , fnEnd  :: !Word32
  } deriving (Eq, Show)

-- Builder state for deriving a forest from the actual 'ExprLike' traversal.
data Build = Build
  { bNextId   :: !AstNodeId                       -- next fresh id (starts at 1)
  , bStack    :: [AstNodeId]                      -- open structural parents
  , bNodes    :: IM.IntMap AstNode                -- id → node (without children until closed)
  , bKids     :: IM.IntMap (DL.DList AstNodeId)   -- id → accumulated children
  , bOrder    :: [AstNodeId]                      -- creation order (deterministic output)
  , bTopLevel :: [AstNodeId]                      -- nodes with no parent (forest roots)
  } deriving (Show)

emptyBuild :: Build
emptyBuild = Build
  { bNextId   = 1
  , bStack    = []
  , bNodes    = IM.empty
  , bKids     = IM.empty
  , bOrder    = []
  , bTopLevel = []
}

-- Turn an 'ExprLike' forest into an AST map using structural recursion.
buildByTraversal :: ExprLike a => WrapperMode -> [a] -> Build
buildByTraversal wmode roots = execState (mapM_ (void . recurseExprLike visit) roots) emptyBuild
  where
    visit :: ExprLike b => b -> State Build b -> State Build b
    visit node post =
      case nodeInfo node of
        Just flat | shouldEmit node -> emitNode flat post
        _                          -> post

    shouldEmit :: ExprLike b => b -> Bool
    shouldEmit node =
      case wmode of
        IncludeWrappers -> True
        OpaqueWrappers  -> not (isWrapper node)

    emitNode :: FlatNode -> State Build b -> State Build b
    emitNode FlatNode{..} post = do
      bid <- freshId
      insertNode bid fnKind fnBeg fnEnd
      attachToParent bid
      pushContainer bid
      result <- post
      popContainer bid
      pure result

    nodeInfo :: ExprLike b => b -> Maybe FlatNode
    nodeInfo node =
      case rangeToPosPair (getRange node) of
        Just (s, e) | s < e ->
          Just FlatNode
            { fnKind = ctorName node
            , fnBeg  = fromIntegral s
            , fnEnd  = fromIntegral e
            }
        _ -> Nothing

    freshId :: State Build AstNodeId
    freshId = do
      st <- get
      let i = bNextId st
      put st{ bNextId = i + 1 }
      pure i

    insertNode :: AstNodeId -> String -> Word32 -> Word32 -> State Build ()
    insertNode i kd b e = do
      st <- get
      let node = AstNode
            { astNodeId       = i
            , astNodeKind     = kd
            , astNodeBeg      = b
            , astNodeEnd      = e
            , astNodeChildren = [] }
      put st
        { bNodes = IM.insert (i2i i) node (bNodes st)
        , bKids  = IM.insert (i2i i) mempty (bKids st)
        , bOrder = bOrder st ++ [i]
        }

    attachToParent :: AstNodeId -> State Build ()
    attachToParent i = do
      st <- get
      case bStack st of
        [] -> put st{ bTopLevel = bTopLevel st ++ [i] }
        p : _ ->
          put st{ bKids = IM.adjust (<> DL.singleton i) (i2i p) (bKids st) }

    pushContainer :: AstNodeId -> State Build ()
    pushContainer i = do
      st <- get
      put st{ bStack = i : bStack st }

    popContainer :: AstNodeId -> State Build ()
    popContainer i = do
      st <- get
      case bStack st of
        j : rest | i == j -> do
          let kids = maybe [] DL.toList (IM.lookup (i2i i) (bKids st))
              node = (bNodes st IM.! i2i i){ astNodeChildren = kids }
          put st{ bStack = rest
                , bNodes = IM.insert (i2i i) node (bNodes st) }
        _ -> pure ()

-- small helper
i2i :: AstNodeId -> Int
i2i = fromIntegral
