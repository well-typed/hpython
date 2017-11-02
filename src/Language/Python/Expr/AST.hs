{-# language DataKinds #-}
{-# language DeriveFoldable #-}
{-# language DeriveFunctor #-}
{-# language DeriveTraversable #-}
{-# language FlexibleContexts #-}
{-# language FlexibleInstances #-}
{-# language GADTs #-}
{-# language KindSignatures #-}
{-# language RecordWildCards #-}
{-# language StandaloneDeriving #-}
{-# language TemplateHaskell #-}
{-# language TypeFamilies #-}
module Language.Python.Expr.AST where

import Papa hiding (Plus, Sum, Product)

import Data.Deriving
import Data.Functor.Compose
import Data.Functor.Sum
import Data.Separated.After
import Data.Separated.Before
import Data.Separated.Between

import Language.Python.AST.ArgsList
import Language.Python.AST.ArgumentList
import Language.Python.AST.Identifier
import Language.Python.AST.Keywords
import Language.Python.AST.Symbols
import Language.Python.AST.TestlistStarExpr
import Language.Python.Expr.AST.BytesLiteral
import Language.Python.Expr.AST.CompOperator
import Language.Python.Expr.AST.FactorOperator
import Language.Python.Expr.AST.Float
import Language.Python.Expr.AST.Imag
import Language.Python.Expr.AST.Integer
import Language.Python.Expr.AST.StringLiteral
import Language.Python.Expr.AST.TermOperator
import Language.Python.IR.ExprConfig

data LambdefNocond (atomType :: AtomType) (ctxt :: DefinitionContext) a
  = LambdefNocond
  { _lambdefNocond_args
    :: Compose
         Maybe
         (Compose
           (Between (NonEmpty WhitespaceChar) [WhitespaceChar])
           (ArgsList Identifier (Test atomType ctxt)))
         a
  , _lambdefNocond_expr
    :: Compose
         (Before [WhitespaceChar])
         (TestNocond atomType ('FunDef 'Normal))
         a
  , _lambdefNocond_ann :: a
  }
  deriving (Functor, Foldable, Traversable)

data TestNocond (atomType :: AtomType) (ctxt :: DefinitionContext) a
  = TestNocond
  { _expressionNocond_value :: Sum (OrTest atomType ctxt) (LambdefNocond atomType ctxt) a
  , _expressionNocond_ann :: a
  }
deriving instance Functor (TestNocond a b)
deriving instance Foldable (TestNocond a b)
deriving instance Traversable (TestNocond a b)

data CompIter :: AtomType -> DefinitionContext -> * -> * where
  CompIter ::
    { _compIter_value :: Sum (CompFor 'NotAssignable ctxt) (CompIf 'NotAssignable ctxt) a
    , _compIter_ann :: a
    } -> CompIter 'NotAssignable ctxt a
deriving instance Eq c => Eq (CompIter a b c)
deriving instance Functor (CompIter a b)
deriving instance Foldable (CompIter a b)
deriving instance Traversable (CompIter a b)

data CompIf :: AtomType -> DefinitionContext -> * -> * where
  CompIf ::
    { _compIf_if :: Between' (NonEmpty WhitespaceChar) KIf
    , _compIf_expr
      :: TestNocond 'NotAssignable ctxt a
    , _compIf_iter
      :: Compose
          Maybe
          (Compose (Before [WhitespaceChar]) (CompIter 'NotAssignable ctxt))
          a
    , _compIf_ann :: a
    } -> CompIf 'NotAssignable ctxt a
deriving instance Eq c => Eq (CompIf a b c)
deriving instance Functor (CompIf a b)
deriving instance Foldable (CompIf a b)
deriving instance Traversable (CompIf a b)

data StarExpr (atomType :: AtomType) (ctxt :: DefinitionContext) a
  = StarExpr
  { _starExpr_value
    :: Compose
         (Before [WhitespaceChar])
         (Expr 'Assignable ctxt)
         a
  , _starExpr_ann :: a
  }
deriving instance Functor (StarExpr a b)
deriving instance Foldable (StarExpr a b)
deriving instance Traversable (StarExpr a b)

data ExprList :: AtomType -> DefinitionContext -> * -> * where
  ExprListSingleStarredComma ::
    { _exprListSingleStarredComma_value :: StarExpr atomType ctxt a
    , _exprListSingleStarredComma_comma :: Before [WhitespaceChar] Comma
    , _exprListSingleStarredComma_ann :: a
    } -> ExprList atomType ctxt a

  ExprListSingleStarredNoComma ::
    { _exprListSingleStarredNoComma_value :: StarExpr 'NotAssignable ctxt a
    , _exprListSingleStarredNoComma_ann :: a
    } -> ExprList 'NotAssignable ctxt a

  ExprListSingle ::
    { _exprListSingle_value :: Expr atomType ctxt a
    , _exprListSingle_comma :: Maybe (Before [WhitespaceChar] Comma)
    , _exprListSingle_ann :: a
    } -> ExprList atomType ctxt a

  ExprListMany ::
    { _exprListMany_head :: Sum (Expr atomType ctxt) (StarExpr atomType ctxt) a
    , _exprListMany_tail
      :: Compose
           NonEmpty
           (Compose
             (Before (Between' [WhitespaceChar] Comma))
             (Sum (Expr atomType ctxt) (StarExpr atomType ctxt)))
           a
    , _exprListMany_comma :: Maybe (Before [WhitespaceChar] Comma)
    , _exprListMany_ann :: a
    } -> ExprList atomType ctxt a
deriving instance Functor (ExprList a b)
deriving instance Foldable (ExprList a b)
deriving instance Traversable (ExprList a b)

data CompFor :: AtomType -> DefinitionContext -> * -> * where
  CompFor ::
    { _compFor_targets
      :: Compose
          (Before (Between' (NonEmpty WhitespaceChar) KFor))
          (Compose
            (After (NonEmpty WhitespaceChar))
            (TestlistStarExpr Expr StarExpr 'Assignable ctxt))
          a
    , _compFor_expr :: Compose (Before (NonEmpty WhitespaceChar)) (OrTest 'NotAssignable ctxt) a
    , _compFor_iter
      :: Compose
          Maybe
          (Compose
            (Before [WhitespaceChar])
            (CompIter 'NotAssignable ctxt))
          a
    , _compFor_ann :: a
    } -> CompFor 'NotAssignable ctxt a
deriving instance Eq c => Eq (CompFor a b c)
deriving instance Functor (CompFor a b)
deriving instance Foldable (CompFor a b)
deriving instance Traversable (CompFor a b)

data SliceOp :: AtomType -> DefinitionContext -> * -> * where
  SliceOp ::
    { _sliceOp_val
      :: Compose
          Maybe
          (Compose (Before [WhitespaceChar]) (Test 'NotAssignable ctxt))
          a
    , _sliceOp_ann :: a
    } -> SliceOp 'NotAssignable ctxt a
deriving instance Eq c => Eq (SliceOp a b c)
deriving instance Functor (SliceOp a b)
deriving instance Foldable (SliceOp a b)
deriving instance Traversable (SliceOp a b)

data Subscript :: AtomType -> DefinitionContext -> * -> * where
  SubscriptTest ::
    { _subscriptTest_val :: Test 'NotAssignable ctxt a
    , _subscript_ann :: a
    } -> Subscript 'NotAssignable ctxt a
  SubscriptSlice ::
    { _subscriptSlice_left
      :: Compose
           (After [WhitespaceChar])
           (Compose
             Maybe
             (Test 'NotAssignable ctxt))
           a
    , _subscriptSlice_colon :: After [WhitespaceChar] Colon
    , _subscriptSlice_right
      :: Compose
          Maybe
          (Compose (After [WhitespaceChar]) (Test 'NotAssignable ctxt))
          a
    , _subscriptSlice_sliceOp
      :: Compose
          Maybe
          (Compose (After [WhitespaceChar]) (SliceOp 'NotAssignable ctxt))
          a 
    , _subscript_ann :: a
    } -> Subscript 'NotAssignable ctxt a
deriving instance Eq c => Eq (Subscript a b c)
deriving instance Functor (Subscript a b)
deriving instance Foldable (Subscript a b)
deriving instance Traversable (Subscript a b)

data SubscriptList :: AtomType -> DefinitionContext -> * -> * where
  SubscriptList ::
    { _subscriptList_head :: Subscript 'NotAssignable ctxt a
    , _subscriptList_tail
      :: Compose
          []
          (Compose
            (Before (Between' [WhitespaceChar] Comma))
            (Subscript 'NotAssignable ctxt))
          a
    , _subscriptList_comma :: Maybe (Before [WhitespaceChar] Comma)
    , _subscriptList_ann :: a
    } -> SubscriptList 'NotAssignable ctxt a
deriving instance Eq c => Eq (SubscriptList a b c)
deriving instance Functor (SubscriptList a b)
deriving instance Foldable (SubscriptList a b)
deriving instance Traversable (SubscriptList a b)

data Trailer :: AtomType -> DefinitionContext -> * -> * where
  TrailerCall ::
    { _trailerCall_value
      :: Compose
          (Between' [WhitespaceChar])
          (Compose
            Maybe
            (ArgumentList Identifier Test 'NotAssignable ctxt))
          a
    , _trailerCall_ann :: a
    } -> Trailer 'NotAssignable ctxt a
  TrailerSubscript ::
    { _trailerSubscript_value
      :: Compose
          (Between' [WhitespaceChar])
          (SubscriptList 'NotAssignable ctxt)
          a
    , _trailerSubscript_ann :: a
    } -> Trailer atomType ctxt a
  TrailerAccess ::
    { _trailerAccess_value :: Compose (Before [WhitespaceChar]) Identifier a
    , _trailerAccess_ann :: a
    } -> Trailer atomType ctxt a
deriving instance Eq c => Eq (Trailer a b c)
deriving instance Functor (Trailer a b)
deriving instance Foldable (Trailer a b)
deriving instance Traversable (Trailer a b)

data AtomExprTrailers :: AtomType -> DefinitionContext -> * -> * where
  AtomExprTrailersBase ::
    { _atomExprTrailersBase_value :: AtomNoInt 'NotAssignable ctxt a
    , _atomExprTrailersBase_trailers
      :: Compose
           (Before [WhitespaceChar])
           (Trailer atomType ctxt)
           a
    , _atomExprTrailersBase_ann :: a
    } -> AtomExprTrailers atomType ctxt a
  AtomExprTrailersMany ::
    { _atomExprTrailersMany_value :: AtomExprTrailers 'NotAssignable ctxt a
    , _atomExprTrailersMany_trailers
      :: Compose
           (Before [WhitespaceChar])
           (Trailer atomType ctxt)
           a
    , _atomExprTrailersMany_ann :: a
    } -> AtomExprTrailers atomType ctxt a
deriving instance Eq c => Eq (AtomExprTrailers a b c)
deriving instance Functor (AtomExprTrailers a b)
deriving instance Foldable (AtomExprTrailers a b)
deriving instance Traversable (AtomExprTrailers a b)

data AtomExpr :: AtomType -> DefinitionContext -> * -> * where
  AtomExprSingle ::
    { _atomExprSingle_value :: Atom atomType ctxt a
    , _atomExprSingle_ann :: a
    } -> AtomExpr atomType ctxt a
  AtomExprTrailers ::
    { _atomExprTrailers_value :: AtomExprTrailers atomType ctxt a
    , _atomExprTrailers_ann :: a
    } -> AtomExpr atomType ctxt a
  AtomExprAwaitSingle ::
    { _atomExprAwaitSingle_await :: After (NonEmpty WhitespaceChar) KAwait
    , _atomExprAwaitSingle_atom :: Atom 'NotAssignable ('FunDef 'Async) a
    , _atomExprAwaitSingle_ann :: a
    } -> AtomExpr 'NotAssignable ('FunDef 'Async) a
  AtomExprAwaitTrailers ::
    { _atomExprAwaitTrailers_await :: After (NonEmpty WhitespaceChar) KAwait
    , _atomExprAwaitTrailers_trailers
      :: AtomExprTrailers 'NotAssignable ('FunDef 'Async) a
    , _atomExprAwaitTrailers_ann :: a
    } -> AtomExpr 'NotAssignable ('FunDef 'Async) a
deriving instance Eq a => Eq (AtomExpr c b a)
deriving instance Functor (AtomExpr b a)
deriving instance Foldable (AtomExpr b a)
deriving instance Traversable (AtomExpr b a)

data Power :: AtomType -> DefinitionContext -> * -> * where
  PowerOne ::
    { _powerOne_value :: AtomExpr atomType ctxt a
    , _powerOne_ann :: a
    } -> Power atomType ctxt a

  PowerMany ::
    { _powerMany_left :: AtomExpr 'NotAssignable ctxt a
    , _powerMany_right
      :: Compose
           (Before (Between' [WhitespaceChar] DoubleAsterisk))
           (Factor 'NotAssignable ctxt)
           a
    , _powerMany_ann :: a
    } -> Power 'NotAssignable ctxt a
deriving instance Eq c => Eq (Power a b c)
deriving instance Functor (Power a b)
deriving instance Foldable (Power a b)
deriving instance Traversable (Power a b)

data Factor :: AtomType -> DefinitionContext -> * -> * where
  FactorNone ::
    { _factorNone_value :: Power atomType ctxt a
    , _factorNone_ann :: a
    } -> Factor atomType ctxt a

  FactorOne ::
    { _factorOne_op :: After [WhitespaceChar] FactorOperator
    , _factorOne_value :: Factor 'NotAssignable ctxt a
    , _factorOne_ann :: a
    } -> Factor 'NotAssignable ctxt a
deriving instance Eq c => Eq (Factor a b c)
deriving instance Functor (Factor a b)
deriving instance Foldable (Factor a b)
deriving instance Traversable (Factor a b)

data Term :: AtomType -> DefinitionContext -> * -> * where
  TermOne ::
    { _termOne_value :: Factor atomType ctxt a
    , _termOne_ann :: a
    } -> Term atomType ctxt a

  TermMany ::
    { _termMany_left :: Factor 'NotAssignable ctxt a
    , _termMany_right
      :: Compose
          NonEmpty
          (Compose
            (Before (Between' [WhitespaceChar] TermOperator))
            (Factor 'NotAssignable ctxt))
          a
    , _termMany_ann :: a
    } -> Term 'NotAssignable ctxt a
deriving instance Eq c => Eq (Term a b c)
deriving instance Functor (Term a b)
deriving instance Foldable (Term a b)
deriving instance Traversable (Term a b)

data ArithExpr :: AtomType -> DefinitionContext -> * -> * where
  ArithExprOne ::
    { _arithExprOne_value :: Term atomType ctxt a
    , _arithExprOne_ann :: a
    } -> ArithExpr atomType ctxt a

  ArithExprMany ::
    { _arithExprSome_left :: Term 'NotAssignable ctxt a
    , _arithExprSome_right
      :: Compose
          NonEmpty
          (Compose
            (Before (Between' [WhitespaceChar] (Either Plus Minus)))
            (Term 'NotAssignable ctxt))
          a
    , _arithExprSome_ann :: a
    } -> ArithExpr 'NotAssignable ctxt a
deriving instance Eq c => Eq (ArithExpr a b c)
deriving instance Functor (ArithExpr a b)
deriving instance Foldable (ArithExpr a b)
deriving instance Traversable (ArithExpr a b)

data ShiftExpr :: AtomType -> DefinitionContext -> * -> * where
  ShiftExprOne ::
    { _shiftExprOne_value :: ArithExpr atomType ctxt a
    , _shiftExprOne_ann :: a
    } -> ShiftExpr atomType ctxt a

  ShiftExprMany ::
    { _shiftExprMany_left :: ArithExpr 'NotAssignable ctxt a
    , _shiftExprMany_right
      :: Compose
          NonEmpty
          (Compose
            (Before (Between' [WhitespaceChar] (Either DoubleLT DoubleGT)))
            (ArithExpr 'NotAssignable ctxt))
          a
    , _shiftExprMany_ann :: a
    } -> ShiftExpr 'NotAssignable ctxt a
deriving instance Eq c => Eq (ShiftExpr a b c)
deriving instance Functor (ShiftExpr a b)
deriving instance Foldable (ShiftExpr a b)
deriving instance Traversable (ShiftExpr a b)

data AndExpr :: AtomType -> DefinitionContext -> * -> * where
  AndExprOne ::
    { _andExprOne_value :: ShiftExpr atomType ctxt a
    , _andExprOne_ann :: a
    } -> AndExpr atomType ctxt a

  AndExprMany ::
    { _andExprMany_left :: ShiftExpr 'NotAssignable ctxt a
    , _andExprMany_right
      :: Compose
          NonEmpty
          (Compose
            (Before (Between' [WhitespaceChar] Ampersand))
            (ShiftExpr 'NotAssignable ctxt))
          a
    , _andExprMany_ann :: a
    } -> AndExpr 'NotAssignable ctxt a
deriving instance Eq c => Eq (AndExpr a b c)
deriving instance Functor (AndExpr a b)
deriving instance Foldable (AndExpr a b)
deriving instance Traversable (AndExpr a b)

data XorExpr :: AtomType -> DefinitionContext -> * -> * where
  XorExprOne ::
    { _xorExprOne_value :: AndExpr atomType ctxt a
    , _xorExprOne_ann :: a
    } -> XorExpr atomType ctxt a
  XorExprMany ::
    { _xorExprMany_left :: AndExpr 'NotAssignable ctxt a
    , _xorExprMany_right
      :: Compose
          NonEmpty
          (Compose
            (Before (Between' [WhitespaceChar] Caret))
            (AndExpr 'NotAssignable ctxt))
          a
    , _xorExprMany_ann :: a
    } -> XorExpr 'NotAssignable ctxt a
deriving instance Eq c => Eq (XorExpr a b c)
deriving instance Functor (XorExpr a b)
deriving instance Foldable (XorExpr a b)
deriving instance Traversable (XorExpr a b)

data Expr :: AtomType -> DefinitionContext -> * -> * where
  ExprOne ::
    { _exprOne_value :: XorExpr atomType ctxt a
    , _exprOne_ann :: a
    } -> Expr atomType ctxt a
  ExprMany ::
    { _exprMany_left :: XorExpr 'NotAssignable ctxt a
    , _exprMany_right
      :: Compose
          NonEmpty
          (Compose
            (Before (Between' [WhitespaceChar] Pipe))
            (XorExpr 'NotAssignable ctxt))
          a
    , _exprMany_ann :: a
    } -> Expr 'NotAssignable ctxt a
deriving instance Eq c => Eq (Expr a b c)
deriving instance Functor (Expr a b)
deriving instance Foldable (Expr a b)
deriving instance Traversable (Expr a b)

data Comparison :: AtomType -> DefinitionContext -> * -> * where
  ComparisonOne ::
    { _comparisonOne_value :: Expr atomType ctxt a
    , _comparisonOne_ann :: a
    } -> Comparison atomType ctxt a
  ComparisonMany ::
    { _comparisonMany_left :: Expr 'NotAssignable ctxt a
    , _comparisonMany_right
      :: Compose
          NonEmpty
          (Compose
            (Before CompOperator)
            (Expr 'NotAssignable ctxt))
          a
    , _comparisonMany_ann :: a
    } -> Comparison 'NotAssignable ctxt a
deriving instance Eq c => Eq (Comparison a b c)
deriving instance Functor (Comparison a b)
deriving instance Foldable (Comparison a b)
deriving instance Traversable (Comparison a b)

data NotTest :: AtomType -> DefinitionContext -> * -> * where
  NotTestMany ::
    { _notTestMany_value
      :: Compose
          (Before (After (NonEmpty WhitespaceChar) KNot))
          (NotTest 'NotAssignable ctxt)
          a
    , _notTestMany_ann :: a
    } -> NotTest 'NotAssignable ctxt a
  NotTestOne ::
    { _notTestNone_value :: Comparison atomType ctxt a
    , _notTestNone_ann :: a
    } -> NotTest atomType ctxt a
deriving instance Eq c => Eq (NotTest a b c)
deriving instance Functor (NotTest a b)
deriving instance Foldable (NotTest a b)
deriving instance Traversable (NotTest a b)

data AndTest :: AtomType -> DefinitionContext -> * -> * where
  AndTestOne ::
    { _andTestOne_value :: NotTest atomType ctxt a
    , _andTestOne_ann :: a
    } -> AndTest atomType ctxt a

  AndTestMany ::
    { _andTestMany_left :: NotTest 'NotAssignable ctxt a
    , _andTestMany_right
      :: Compose
          NonEmpty
          (Compose
            (Before (Between' (NonEmpty WhitespaceChar) KAnd))
            (NotTest 'NotAssignable ctxt))
          a
    , _andTestMany_ann :: a
    } -> AndTest 'NotAssignable ctxt a
deriving instance Eq c => Eq (AndTest a b c)
deriving instance Functor (AndTest a b)
deriving instance Foldable (AndTest a b)
deriving instance Traversable (AndTest a b)

data OrTest :: AtomType -> DefinitionContext -> * -> * where
  OrTestOne ::
    { _orTestOne_value :: AndTest atomType ctxt a
    , _orTestOne_ann :: a
    } -> OrTest atomType ctxt a

  OrTestMany ::
    { _orTestMany_left :: AndTest 'NotAssignable ctxt a
    , _orTestMany_right
      :: Compose
           NonEmpty
           (Compose
             (Before (Between' (NonEmpty WhitespaceChar) KOr))
             (AndTest 'NotAssignable ctxt))
           a
    , _orTestMany_ann :: a
    } -> OrTest 'NotAssignable ctxt a
deriving instance Eq c => Eq (OrTest a b c)
deriving instance Functor (OrTest a b)
deriving instance Foldable (OrTest a b)
deriving instance Traversable (OrTest a b)

data IfThenElse :: AtomType -> DefinitionContext -> * -> * where
  IfThenElse ::
    { _ifThenElse_if :: Between' (NonEmpty WhitespaceChar) KIf
    , _ifThenElse_value1 :: OrTest 'NotAssignable ctxt a
    , _ifThenElse_else :: Between' (NonEmpty WhitespaceChar) KElse
    , _ifThenElse_value2 :: Test 'NotAssignable ctxt a
    } -> IfThenElse 'NotAssignable ctxt a
deriving instance Eq c => Eq (IfThenElse a b c)
deriving instance Functor (IfThenElse a b)
deriving instance Foldable (IfThenElse a b)
deriving instance Traversable (IfThenElse a b)

data Test :: AtomType -> DefinitionContext -> * -> * where
  TestCondNoIf ::
    { _testCondNoIf_value :: OrTest atomType ctxt a
    , _testCondNoIf_ann :: a
    } -> Test atomType ctxt a
  TestCondIf ::
    { _testCondIf_head :: OrTest 'NotAssignable ctxt a
    , _testCondIf_tail
      :: Compose
          (Before (NonEmpty WhitespaceChar))
          (IfThenElse 'NotAssignable ctxt)
          a
    , _testCondIf_ann :: a
    } -> Test 'NotAssignable ctxt a

  TestLambdef ::
    { _testLambdef_value :: Lambdef 'NotAssignable ctxt a
    , _testLambdef_ann :: a
    } -> Test 'NotAssignable ctxt a
deriving instance Eq c => Eq (Test a b c)
deriving instance Functor (Test a b)
deriving instance Foldable (Test a b)
deriving instance Traversable (Test a b)

data Lambdef :: AtomType -> DefinitionContext -> * -> * where
  Lambdef ::
    { _lambdef_Args
      :: Compose
          Maybe
          (Compose
            (Before (NonEmpty WhitespaceChar))
            (ArgsList Identifier (Test 'NotAssignable ctxt)))
          a
    , _lambdef_body
      :: Compose
           (Before (Between' [WhitespaceChar] Colon))
           (Test 'NotAssignable ('FunDef 'Normal))
           a
    , _lambdef_ann :: a
    } -> Lambdef 'NotAssignable ctxt a
deriving instance Eq c => Eq (Lambdef a b c)
deriving instance Functor (Lambdef a b)
deriving instance Foldable (Lambdef a b)
deriving instance Traversable (Lambdef a b)

data TestList (atomType :: AtomType) (ctxt :: DefinitionContext) a
  = TestList
  { _testList_head :: Test atomType ctxt a
  , _testList_tail
    :: Compose
         []
         (Compose
           (Before (Between' [WhitespaceChar] Comma))
           (Test atomType ctxt))
         a
  , _testList_comma :: Maybe (Before [WhitespaceChar] Comma)
  , _testList_ann :: a
  }
  deriving (Functor, Foldable, Traversable)

data YieldArg :: AtomType -> DefinitionContext -> * -> * where
  YieldArgFrom ::
    { _yieldArgFrom_value
      :: Compose
           (Before (NonEmpty WhitespaceChar))
           (Test 'NotAssignable ctxt)
           a
    , _yieldArgFrom_ann :: a
    } -> YieldArg 'NotAssignable ctxt a
  YieldArgList ::
    { _yieldArgList_value :: TestList atomType ctxt a
    , _yieldArgList_ann :: a
    } -> YieldArg atomType ctxt a
deriving instance Eq c => Eq (YieldArg a b c)
deriving instance Functor (YieldArg a b)
deriving instance Foldable (YieldArg a b)
deriving instance Traversable (YieldArg a b)

data YieldExpr (ctxt :: DefinitionContext) a where
  YieldExpr ::
    { _yieldExpr_value
      :: Compose
          Maybe
          (Compose
            (Before (NonEmpty WhitespaceChar))
            (YieldArg 'NotAssignable ('FunDef 'Normal)))
          a
    , _yieldExpr_ann :: a
    } -> YieldExpr ('FunDef 'Normal) a
deriving instance Eq a => Eq (YieldExpr ctxt a)
deriving instance Show a => Show (YieldExpr ctxt a)
deriving instance Functor (YieldExpr ctxt)
deriving instance Foldable (YieldExpr ctxt)
deriving instance Traversable (YieldExpr ctxt)

data ListTestlistComp :: AtomType -> DefinitionContext -> * -> * where
  ListTestlistCompStarred ::
    { _ListTestlistCompStarred_head :: StarExpr atomType ctxt a
    , _ListTestlistCompStarred_tail
      :: Compose
          []
          (Compose
            (Before (Between' [WhitespaceChar] Comma))
            (Sum (Test atomType ctxt) (StarExpr atomType ctxt)))
          a
    , _ListTestlistCompStarred_comma :: Maybe (Before [WhitespaceChar] Comma)
    , _ListTestlistCompStarred_ann :: a
    } -> ListTestlistComp atomType ctxt a

  ListTestlistCompList ::
    { _ListTestlistCompList_head :: Test atomType ctxt a
    , _ListTestlistCompList_tail
      :: Compose
          []
          (Compose
            (Before (Between' [WhitespaceChar] Comma))
            (Sum (Test atomType ctxt) (StarExpr atomType ctxt)))
          a
    , _ListTestlistCompList_comma :: Maybe (Before [WhitespaceChar] Comma)
    , _ListTestlistCompList_ann :: a
    } -> ListTestlistComp atomType ctxt a

  ListTestlistCompFor ::
    { _ListTestlistCompFor_head
      :: Test 'NotAssignable ctxt a
    , _ListTestlistCompFor_tail
      :: CompFor 'NotAssignable ctxt a
    , _ListTestlistCompFor_ann :: a
    } -> ListTestlistComp 'NotAssignable ctxt a
deriving instance Eq c => Eq (ListTestlistComp a b c)
deriving instance Functor (ListTestlistComp a b)
deriving instance Foldable (ListTestlistComp a b)
deriving instance Traversable (ListTestlistComp a b)

data TupleTestlistComp :: AtomType -> DefinitionContext -> * -> * where
  TupleTestlistCompStarredOne ::
    { _tupleTestlistCompStarredOne_head :: StarExpr atomType ctxt a
    , _tupleTestlistCompStarredOne_comma :: Before [WhitespaceChar] Comma
    , _tupleTestlistCompStarredOne_ann :: a
    } -> TupleTestlistComp atomType ctxt a

  TupleTestlistCompStarredMany ::
    { _tupleTestlistCompStarredMany_head :: StarExpr atomType ctxt a
    , _tupleTestlistCompStarredMany_tail
      :: Compose
          NonEmpty
          (Compose
            (Before (Between' [WhitespaceChar] Comma))
            (Sum (Test atomType ctxt) (StarExpr atomType ctxt)))
          a
    , _tupleTestlistCompStarredMany_comma :: Maybe (Before [WhitespaceChar] Comma)
    , _tupleTestlistCompStarredMany_ann :: a
    } -> TupleTestlistComp atomType ctxt a

  TupleTestlistCompList ::
    { _tupleTestlistCompList_head :: Test atomType ctxt a
    , _tupleTestlistCompList_tail
      :: Compose
          []
          (Compose
            (Before (Between' [WhitespaceChar] Comma))
            (Sum (Test atomType ctxt) (StarExpr atomType ctxt)))
          a
    , _tupleTestlistCompList_comma :: Maybe (Before [WhitespaceChar] Comma)
    , _tupleTestlistCompList_ann :: a
    } -> TupleTestlistComp atomType ctxt a

  TupleTestlistCompFor ::
    { _tupleTestlistCompFor_head
      :: Test 'NotAssignable ctxt a
    , _tupleTestlistCompFor_tail
      :: CompFor 'NotAssignable ctxt a
    , _tupleTestlistCompFor_ann :: a
    } -> TupleTestlistComp 'NotAssignable ctxt a
deriving instance Eq c => Eq (TupleTestlistComp a b c)
deriving instance Functor (TupleTestlistComp a b)
deriving instance Foldable (TupleTestlistComp a b)
deriving instance Traversable (TupleTestlistComp a b)

data DictItem (atomType :: AtomType) (ctxt :: DefinitionContext) a where
  DictItem ::
    { _dictItem_key :: Test 'NotAssignable ctxt a
    , _dictItem_colon :: Between' [WhitespaceChar] Colon
    , _dictItem_value :: Test 'NotAssignable ctxt a
    , _dictItem_ann :: a
    } -> DictItem 'NotAssignable ctxt a
deriving instance Eq c => Eq (DictItem a b c)
deriving instance Show c => Show (DictItem a b c)
deriving instance Functor (DictItem a b)
deriving instance Foldable (DictItem a b)
deriving instance Traversable (DictItem a b)

data DictUnpacking (atomType :: AtomType) (ctxt :: DefinitionContext) a where
  DictUnpacking ::
    { _dictUnpacking_value
      :: Compose
            (Before (Between' [WhitespaceChar] DoubleAsterisk))
            (Expr 'NotAssignable ctxt)
            a
    , _dictUnpacking_ann :: a
    } -> DictUnpacking 'NotAssignable ctxt a
deriving instance Eq c => Eq (DictUnpacking a b c)
deriving instance Show c => Show (DictUnpacking a b c)
deriving instance Functor (DictUnpacking a b)
deriving instance Foldable (DictUnpacking a b)
deriving instance Traversable (DictUnpacking a b)

data DictOrSetMaker (atomType :: AtomType) (ctxt :: DefinitionContext) a where
  DictOrSetMakerDictComp ::
    { _dictOrSetMakerDictComp_head :: DictItem 'NotAssignable ctxt a
    , _dictOrSetMakerDictComp_tail :: CompFor 'NotAssignable ctxt a
    , _dictOrSetMakerDictComp_ann :: a
    } -> DictOrSetMaker 'NotAssignable ctxt a
  DictOrSetMakerDictUnpack ::
    { _dictOrSetMakerDictUnpack_head
      :: Sum
           (DictItem 'NotAssignable ctxt)
           (DictUnpacking 'NotAssignable ctxt)
           a
    , _dictOrSetMakerDictUnpack_tail
      :: Compose
           []
           (Compose
             (Before (Between' [WhitespaceChar] Comma))
             (Sum
               (DictItem 'NotAssignable ctxt)
               (DictUnpacking 'NotAssignable ctxt)))
           a
    , _dictOrSetMakerDictUnpack_comma
      :: Maybe (Between' [WhitespaceChar] Comma)
    , _dictOrSetMakerDictUnpack_ann :: a
    } -> DictOrSetMaker 'NotAssignable ctxt a
  DictOrSetMakerSetComp ::
    { _dictOrSetMakerSetComp_head :: Test 'NotAssignable ctxt a
    , _dictOrSetMakerSetComp_tail :: CompFor 'NotAssignable ctxt a
    , _dictOrSetMakerSetComp_ann :: a
    } -> DictOrSetMaker 'NotAssignable ctxt a
  DictOrSetMakerSetUnpack ::
    { _dictOrSetMakerSetUnpack_head
      :: Sum
           (Test 'NotAssignable ctxt)
           (StarExpr 'NotAssignable ctxt)
           a
    , _dictOrSetMakerSetUnpack_tail
      :: Compose
           []
           (Compose
             (Before (Between' [WhitespaceChar] Comma))
             (Sum
               (Test 'NotAssignable ctxt)
               (StarExpr 'NotAssignable ctxt)))
           a
    , _dictOrSetMakerSetUnpack_comma
      :: Maybe (Between' [WhitespaceChar] Comma)
    , _dictOrSetMakerSetUnpack_ann :: a
    } -> DictOrSetMaker 'NotAssignable ctxt a
deriving instance Eq c => Eq (DictOrSetMaker a b c)
deriving instance Show c => Show (DictOrSetMaker a b c)
deriving instance Functor (DictOrSetMaker a b)
deriving instance Foldable (DictOrSetMaker a b)
deriving instance Traversable (DictOrSetMaker a b)

data AtomNoInt :: AtomType -> DefinitionContext -> * -> * where
  AtomParenNoYield ::
    { _atomParenNoYield_val
      :: Compose
          (Between' [WhitespaceChar])
          (Compose
            Maybe
            (TupleTestlistComp atomType ctxt))
          a
    , _atomParenNoYield_ann :: a
    } -> AtomNoInt atomType ctxt a

  -- A yield expression can only be used within a normal function definition
  AtomParenYield ::
    { _atomParenYield_val
      :: Compose
          (Between' [WhitespaceChar])
          (YieldExpr ctxt)
          a
    , _atomParenYield_ann :: a
    } -> AtomNoInt 'NotAssignable ctxt a

  AtomBracket ::
    { _atomBracket_val
      :: Compose
          (Between' [WhitespaceChar])
          (Compose
            Maybe
            (ListTestlistComp atomType ctxt))
          a
    , _atomBracket_ann :: a
    } -> AtomNoInt atomType ctxt a

  AtomCurly ::
    { _atomCurly_val
      :: Compose
          (Between' [WhitespaceChar])
          (Compose
            Maybe
            (DictOrSetMaker 'NotAssignable ctxt))
          a
    , _atomCurly_ann :: a
    } -> AtomNoInt 'NotAssignable ctxt a

  AtomIdentifier ::
    { _atomIdentifier_value :: Identifier a
    , _atomIdentifier_ann :: a
    } -> AtomNoInt atomType ctxt a

  AtomFloat ::
    { _atomFloat :: Float' a
    , _atomFloat_ann :: a
    } -> AtomNoInt 'NotAssignable ctxt a

  AtomString ::
    { _atomString_head :: Sum StringLiteral BytesLiteral a
    , _atomString_tail
      :: Compose
          []
          (Compose
            (Before [WhitespaceChar])
            (Sum StringLiteral BytesLiteral))
          a
    , _atomString_ann :: a
    } -> AtomNoInt 'NotAssignable ctxt a

  AtomImag ::
    { _atomImag_value
      :: Compose
           (Before [WhitespaceChar])
           Imag
          a
    , _atomString_ann :: a
    } -> AtomNoInt 'NotAssignable ctxt a

  AtomEllipsis ::
    { _atomEllipsis_ann :: a
    } -> AtomNoInt 'NotAssignable ctxt a

  AtomNone ::
    { _atomNone_ann :: a
    } -> AtomNoInt 'NotAssignable ctxt a

  AtomTrue ::
    { _atomTrue_ann :: a
    } -> AtomNoInt 'NotAssignable ctxt a

  AtomFalse ::
    { _atomFalse_ann :: a
    } -> AtomNoInt 'NotAssignable ctxt a
deriving instance Eq a => Eq (AtomNoInt atomType ctxt a)
deriving instance Functor (AtomNoInt atomType ctxt)
deriving instance Foldable (AtomNoInt atomType ctxt)
deriving instance Traversable (AtomNoInt atomType ctxt)

data Atom :: AtomType -> DefinitionContext -> * -> * where
  AtomNoInt ::
    { _atomNoInt_value :: AtomNoInt atomType ctxt a
    , _atomNoInt_ann :: a
    } -> Atom atomType ctxt a

  AtomInteger ::
    { _atomInteger :: Integer' a
    , _atomInteger_ann :: a
    } -> Atom 'NotAssignable ctxt a
deriving instance Eq a => Eq (Atom atomType ctxt a)
deriving instance Functor (Atom atomType ctxt)
deriving instance Foldable (Atom atomType ctxt)
deriving instance Traversable (Atom atomType ctxt)

data PythonModule a
  = PythonModule
  { _pythonModule_content :: a
  , _pythonModule_ann :: a
  } deriving (Functor, Foldable, Traversable)

deriveShow ''Comparison
deriveEq1 ''Comparison
deriveOrd1 ''Comparison
deriveShow1 ''Comparison

deriveShow ''NotTest
deriveEq1 ''NotTest
deriveOrd1 ''NotTest
deriveShow1 ''NotTest

deriveShow ''AndTest
deriveEq1 ''AndTest
deriveOrd1 ''AndTest
deriveShow1 ''AndTest

deriveShow ''OrTest
deriveEq1 ''OrTest
deriveOrd1 ''OrTest
deriveShow1 ''OrTest

deriveShow ''IfThenElse
deriveEq1 ''IfThenElse
deriveOrd1 ''IfThenElse
deriveShow1 ''IfThenElse

deriveShow ''Test
deriveEq1 ''Test
deriveOrd1 ''Test
deriveShow1 ''Test

deriveEq ''TestList
deriveShow ''TestList
deriveEq1 ''TestList
deriveOrd1 ''TestList
deriveShow1 ''TestList

deriveEq ''LambdefNocond
deriveShow ''LambdefNocond
deriveEq1 ''LambdefNocond
deriveOrd1 ''LambdefNocond
deriveShow1 ''LambdefNocond

deriveEq ''TestNocond
deriveShow ''TestNocond
deriveEq1 ''TestNocond
deriveOrd1 ''TestNocond
deriveShow1 ''TestNocond

deriveShow ''CompIter
deriveEq1 ''CompIter
deriveOrd1 ''CompIter
deriveShow1 ''CompIter

deriveShow ''CompIf
deriveEq1 ''CompIf
deriveOrd1 ''CompIf
deriveShow1 ''CompIf

deriveEq ''StarExpr
deriveShow ''StarExpr
deriveEq1 ''StarExpr
deriveOrd1 ''StarExpr
deriveShow1 ''StarExpr

deriveEq ''ExprList
deriveShow ''ExprList
deriveEq1 ''ExprList
deriveOrd1 ''ExprList
deriveShow1 ''ExprList

deriveShow ''SliceOp
deriveEq1 ''SliceOp
deriveOrd1 ''SliceOp
deriveShow1 ''SliceOp

deriveShow ''Subscript
deriveEq1 ''Subscript
deriveOrd1 ''Subscript
deriveShow1 ''Subscript

deriveShow ''SubscriptList
deriveEq1 ''SubscriptList
deriveOrd1 ''SubscriptList
deriveShow1 ''SubscriptList

deriveShow ''CompFor
deriveEq1 ''CompFor
deriveOrd1 ''CompFor
deriveShow1 ''CompFor

deriveShow ''Trailer
deriveEq1 ''Trailer
deriveOrd1 ''Trailer
deriveShow1 ''Trailer

deriveShow ''AtomExprTrailers
deriveEq1 ''AtomExprTrailers
deriveOrd1 ''AtomExprTrailers
deriveShow1 ''AtomExprTrailers

deriveShow ''AtomExpr
deriveEq1 ''AtomExpr
deriveOrd1 ''AtomExpr
deriveShow1 ''AtomExpr

deriveShow ''Power
deriveEq1 ''Power
deriveOrd1 ''Power
deriveShow1 ''Power

deriveShow ''Factor
deriveEq1 ''Factor
deriveOrd1 ''Factor
deriveShow1 ''Factor

deriveShow ''Term
deriveEq1 ''Term
deriveOrd1 ''Term
deriveShow1 ''Term

deriveShow ''ArithExpr
deriveEq1 ''ArithExpr
deriveOrd1 ''ArithExpr
deriveShow1 ''ArithExpr

deriveShow ''ShiftExpr
deriveEq1 ''ShiftExpr
deriveOrd1 ''ShiftExpr
deriveShow1 ''ShiftExpr

deriveShow ''AndExpr
deriveEq1 ''AndExpr
deriveOrd1 ''AndExpr
deriveShow1 ''AndExpr

deriveShow ''XorExpr
deriveEq1 ''XorExpr
deriveOrd1 ''XorExpr
deriveShow1 ''XorExpr
  
deriveShow ''Expr
deriveEq1 ''Expr
deriveOrd1 ''Expr
deriveShow1 ''Expr

deriveShow ''YieldArg
deriveEq1 ''YieldArg
deriveOrd1 ''YieldArg
deriveShow1 ''YieldArg

deriveEq1 ''YieldExpr
deriveOrd1 ''YieldExpr
deriveShow1 ''YieldExpr

deriveShow ''TupleTestlistComp
deriveEq1 ''TupleTestlistComp
deriveOrd1 ''TupleTestlistComp
deriveShow1 ''TupleTestlistComp

deriveShow ''ListTestlistComp
deriveEq1 ''ListTestlistComp
deriveOrd1 ''ListTestlistComp
deriveShow1 ''ListTestlistComp

deriveEq1 ''DictOrSetMaker
deriveOrd1 ''DictOrSetMaker
deriveShow1 ''DictOrSetMaker

deriveShow ''AtomNoInt
deriveEq1 ''AtomNoInt
deriveOrd1 ''AtomNoInt
deriveShow1 ''AtomNoInt

deriveShow ''Atom
deriveEq1 ''Atom
deriveOrd1 ''Atom
deriveShow1 ''Atom

deriveEq ''PythonModule
deriveShow ''PythonModule
deriveEq1 ''PythonModule
deriveOrd1 ''PythonModule
deriveShow1 ''PythonModule

deriveShow ''Lambdef
deriveEq1 ''Lambdef
deriveOrd1 ''Lambdef
deriveShow1 ''Lambdef

deriveEq1 ''DictUnpacking
deriveOrd1 ''DictUnpacking
deriveShow1 ''DictUnpacking

deriveEq1 ''DictItem
deriveOrd1 ''DictItem
deriveShow1 ''DictItem