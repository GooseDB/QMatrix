{-# LANGUAGE DataKinds #-}
{-# LANGUAGE MonoLocalBinds #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeApplications #-}

module Internal.Quasi.Operator.Quasi where

import Data.List.Split (chunksOf)
import Data.Proxy
import qualified GHC.Natural as Natural
import GHC.TypeNats
import Internal.Matrix
import qualified Internal.Quasi.Operator.Parser as Parser
import qualified Internal.Quasi.Parser as Parser
import Internal.Quasi.Quasi
import Language.Haskell.TH.Quote
import Language.Haskell.TH.Syntax
import QLinear.Identity

{- | Macro constructor for operator

>>> [operator| (x, y) => (y, x) |]
[0,1]
[1,0]
>>> [operator| (x, y) => (2 * x, y + x) |] ~*~ [vector| 3 4 |]
[6]
[7]

Do note,constructor __doesn't prove__ linearity.
It just builds matrix of given operator.

-}
operator :: QuasiQuoter
operator =
  QuasiQuoter
    { quoteExp = expr,
      quotePat = notDefined "Pattern",
      quoteType = notDefined "Type",
      quoteDec = notDefined "Declaration"
    }
  where
    notDefined = isNotDefinedAs "operator"

expr :: String -> Q Exp
expr source = do
  let (params, lams, n) = unwrap $ parse source
  let sizeType = LitT . NumTyLit
  let msize = TupE $ map (Just . LitE . IntegerL) [n, 1]
  let func = VarE 'matrixOfOperator
  let constructor = foldl AppTypeE (ConE 'Matrix) [sizeType n, sizeType 1, WildCardT]
  let mvalue = ListE $ map (ListE . pure . LamE [ListP params]) lams
  pure $ AppE func $ foldl AppE constructor [msize, mvalue]

parse :: String -> Either [String] ([Pat], [Exp], Integer)
parse source = do
  (params, lams) <- Parser.parse Parser.definition "QLinear" source
  msize <- checkSize (params, lams)
  pure (params, lams, msize)

checkSize :: ([Pat], [Exp]) -> Either [String] Integer
checkSize ([], _) = Left ["Parameters of operator cannot be empty"]
checkSize (_, []) = Left ["Body of operator cannot be empty"]
checkSize (names, exprs) =
  let namesLength = length names
      exprsLength = length exprs
   in if namesLength == exprsLength
        then Right $ fromIntegral namesLength
        else Left ["Number of arguments and number of lambdas must be equal"]

matrixOfOperator :: forall n a b. (KnownNat n, HasIdentity a) => Matrix n 1 ([a] -> b) -> Matrix n n b
matrixOfOperator (Matrix _ fs) = Matrix (n, n) $ chunksOf n [f line | f <- concat fs, line <- identity]
  where
    (Matrix _ identity) = e :: Matrix n n a
    n = Natural.naturalToInt $ natVal (Proxy @n)
