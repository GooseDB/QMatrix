{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Internal.Matrix where

import qualified Data.List as List
import GHC.TypeNats (KnownNat,natVal, Nat)
import Data.Proxy

data Matrix (m :: Nat) (n :: Nat) a where
  Matrix :: forall m n a. (Int, Int) -> ![[a]] -> Matrix m n a

instance Show a => Show (Matrix m n a) where
  show (Matrix _ matrix) = List.intercalate "\n" $ map show matrix

instance Functor (Matrix m n) where
  fmap f (Matrix msize a) = Matrix msize $ map (map f) a

instance (KnownNat m, KnownNat n) => Applicative (Matrix m n) where
  pure = Matrix (fromIntegral $ natVal (Proxy :: Proxy m), fromIntegral $ natVal (Proxy :: Proxy n)) . pure . pure
  Matrix msize fs <*> (Matrix _ as) =
    Matrix msize $ zipWith (<*>) fs as

instance (Eq a) => Eq (Matrix m n a) where
  Matrix _ a == Matrix _ b = a == b

type Vector n a = Matrix n 1 a

size :: Integral b => Matrix m n a -> (b, b)
size (Matrix (m, n) _) = (fromIntegral m, fromIntegral n)

value :: Matrix m n a -> [[a]]
value (Matrix _ v) = v
