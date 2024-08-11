{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE EmptyCase #-}
{-# LANGUAGE EmptyDataDecls #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}

{-# OPTIONS_GHC -Wno-overlapping-patterns #-}

module MAlonzo.Code.Qlanguage.QforeignZ45ZfunctionZ45Zinterface where

import MAlonzo.RTE (coe, erased, AgdaAny, addInt, subInt, mulInt,
                    quotInt, remInt, geqInt, ltInt, eqInt, add64, sub64, mul64, quot64,
                    rem64, lt64, eq64, word64FromNat, word64ToNat)
import qualified MAlonzo.RTE
import qualified Data.Text
import qualified MAlonzo.Code.Agda.Builtin.Bool
import qualified MAlonzo.Code.Agda.Builtin.IO
import qualified MAlonzo.Code.Agda.Builtin.List
import qualified MAlonzo.Code.Agda.Builtin.String
import qualified MAlonzo.Code.Agda.Builtin.Unit
import qualified MAlonzo.Code.Agda.Primitive

import Data.Maybe
import qualified System.IO
import Data.Tree
import qualified Data.Text.IO as Text
import qualified System.IO as IO
import GUILib
data Foo = Foo | Bar Foo

countBars :: Foo -> Integer
countBars Foo = 0
countBars (Bar f) = 1 + countBars f
type AgdaEither a b = Either
data WidgetDict w = Widget w => WidgetDict
-- language.foreign-function-interface.<Name>
d_'60'Name'62'_4
  = error
      "MAlonzo Runtime Error: postulate evaluated: language.foreign-function-interface.<Name>"
-- language.foreign-function-interface.FileHandle
type T_FileHandle_6 = System.IO.Handle
d_FileHandle_6
  = error
      "MAlonzo Runtime Error: postulate evaluated: language.foreign-function-interface.FileHandle"
-- language.foreign-function-interface.Maybe
d_Maybe_10 a0 = ()
type T_Maybe_10 a0 = Maybe a0
pattern C_nothing_14 = Nothing
pattern C_just_16 a0 = Just a0
check_nothing_14 :: forall xA. T_Maybe_10 xA
check_nothing_14 = Nothing
check_just_16 :: forall xA. xA -> T_Maybe_10 xA
check_just_16 = Just
cover_Maybe_10 :: Maybe a1 -> ()
cover_Maybe_10 x
  = case x of
      Nothing -> ()
      Just _ -> ()
-- language.foreign-function-interface.Tree
d_Tree_20 a0 = ()
type T_Tree_20 a0 = Tree a0
pattern C_node_32 a0 a1 = Node a0 a1
check_node_32 ::
  forall xA.
    xA ->
    MAlonzo.Code.Agda.Builtin.List.T_List_10 () (T_Tree_20 xA) ->
    T_Tree_20 xA
check_node_32 = Node
cover_Tree_20 :: Tree a1 -> ()
cover_Tree_20 x
  = case x of
      Node _ _ -> ()
-- language.foreign-function-interface.Tree.root-label
d_root'45'label_28 :: T_Tree_20 AgdaAny -> AgdaAny
d_root'45'label_28 v0
  = case coe v0 of
      C_node_32 v1 v2 -> coe v1
      _ -> MAlonzo.RTE.mazUnreachableError
-- language.foreign-function-interface.Tree.sub-forest
d_sub'45'forest_30 :: T_Tree_20 AgdaAny -> [T_Tree_20 AgdaAny]
d_sub'45'forest_30 v0
  = case coe v0 of
      C_node_32 v1 v2 -> coe v2
      _ -> MAlonzo.RTE.mazUnreachableError
-- language.foreign-function-interface.stdout
d_stdout_34 :: T_FileHandle_6
d_stdout_34 = IO.stdout
-- language.foreign-function-interface.hPutStrLn
d_hPutStrLn_36 ::
  T_FileHandle_6 ->
  MAlonzo.Code.Agda.Builtin.String.T_String_6 ->
  MAlonzo.Code.Agda.Builtin.IO.T_IO_8
    () MAlonzo.Code.Agda.Builtin.Unit.T_'8868'_6
d_hPutStrLn_36 = Text.hPutStrLn
-- language.foreign-function-interface.IdAgda.idAgda
idAgdaFromHs :: forall xA. () -> xA -> xA
idAgdaFromHs = coe d_idAgda_42
d_idAgda_42 :: () -> AgdaAny -> AgdaAny
d_idAgda_42 ~v0 v1 = du_idAgda_42 v1
du_idAgda_42 :: AgdaAny -> AgdaAny
du_idAgda_42 v0 = coe v0
-- language.foreign-function-interface.ioReturn
d_ioReturn_48 ::
  forall xA. () -> xA -> MAlonzo.Code.Agda.Builtin.IO.T_IO_8 () xA
d_ioReturn_48 = \ _ x -> return x
-- language.foreign-function-interface.Either
d_Either_58 a0 a1 a2 a3 = ()
type T_Either_58 a0 a1 a2 a3 = AgdaEither a0 a1 a2 a3
pattern C_left_68 a0 = Left a0
pattern C_right_70 a0 = Right a0
check_left_68 ::
  forall xa.
    forall xb. forall xA. forall xB. xA -> T_Either_58 xa xb xA xB
check_left_68 = Left
check_right_70 ::
  forall xa.
    forall xb. forall xA. forall xB. xB -> T_Either_58 xa xb xA xB
check_right_70 = Right
cover_Either_58 :: AgdaEither a1 a2 a3 a4 -> ()
cover_Either_58 x
  = case x of
      Left _ -> ()
      Right _ -> ()
-- language.foreign-function-interface.Widget
type T_Widget_72 a0 = WidgetDict a0
d_Widget_72
  = error
      "MAlonzo Runtime Error: postulate evaluated: language.foreign-function-interface.Widget"
-- language.foreign-function-interface.setVisible
d_setVisible_78 ::
  forall xw.
    () ->
    T_Widget_72 xw ->
    xw ->
    Bool ->
    MAlonzo.Code.Agda.Builtin.IO.T_IO_8
      () MAlonzo.Code.Agda.Builtin.Unit.T_'8868'_6
d_setVisible_78 = \ _ WidgetDict -> setVisible
-- language.foreign-function-interface.Window
type T_Window_80 = Window
d_Window_80
  = error
      "MAlonzo Runtime Error: postulate evaluated: language.foreign-function-interface.Window"
-- language.foreign-function-interface.newWindow
d_newWindow_82 ::
  MAlonzo.Code.Agda.Builtin.IO.T_IO_8 () T_Window_80
d_newWindow_82 = newWindow
-- language.foreign-function-interface.WidgetWindow
d_WidgetWindow_84 :: T_Widget_72 T_Window_80
d_WidgetWindow_84 = WidgetDict
-- language.foreign-function-interface.return
d_return_88 ::
  forall xA. () -> xA -> MAlonzo.Code.Agda.Builtin.IO.T_IO_8 () xA
d_return_88 = \ _ -> return
-- language.foreign-function-interface._>>=_
d__'62''62''61'__94 ::
  forall xA.
    forall xB.
      () ->
      () ->
      MAlonzo.Code.Agda.Builtin.IO.T_IO_8 () xA ->
      (xA -> MAlonzo.Code.Agda.Builtin.IO.T_IO_8 () xB) ->
      MAlonzo.Code.Agda.Builtin.IO.T_IO_8 () xB
d__'62''62''61'__94 = \ _ _ -> (>>=)
-- language.foreign-function-interface.openWindow
d_openWindow_96 ::
  MAlonzo.Code.Agda.Builtin.IO.T_IO_8 AgdaAny T_Window_80
d_openWindow_96
  = coe
      d__'62''62''61'__94 erased erased d_newWindow_82
      (\ v0 ->
         coe
           d__'62''62''61'__94 erased erased
           (coe
              d_setVisible_78 erased d_WidgetWindow_84 v0
              (coe MAlonzo.Code.Agda.Builtin.Bool.C_true_10))
           (\ v1 -> coe d_return_88 erased v0))
-- language.foreign-function-interface.List
d_List_106 a0 a1 = ()
data T_List_106
  = C_'91''93'_112 | C__'8759'__118 AgdaAny T_List_106
