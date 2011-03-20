{-# LANGUAGE ForeignFunctionInterface, ScopedTypeVariables, TypeOperators #-}

module BlockCopy where

-- standard libraries
import Prelude as P
import Foreign.Ptr
import Control.Monad
import Control.Exception

-- friends
import Data.Array.Accelerate
import Data.Array.Accelerate.IO

assertEqual :: (Eq a, Show a) => String -> a -> a -> IO ()
assertEqual preface expected actual =
  unless (actual == expected) (throw $ AssertionFailed msg)
  where
    msg = (if null preface then "" else preface ++ "\n")  ++
          "expected: " ++ show expected ++ "\n but got: " ++ show actual

run :: IO ()
run =
  mapM_ (\(msg,act) -> putStrLn ("test: " ++ msg) >> act)
    [ ("fromPtr Int",          testBlockCopyPrim)
    , ("fromPtr (Int,Double)", testBlockCopyTuples)
    , ("toPtr Int",            testBlockCopyFromArray)
    , ("toPtr Int16",          testBlockCopyFromArrayInt16)
    , ("toPtr Int64",          testBlockCopyFromArrayInt64)
    , ("fromArray Int",        testBlockCopyFromArrayWithFunctions) ]


testBlockCopyPrim :: IO ()
testBlockCopyPrim = do
  ptr <- oneToTen
  (arr :: Array (Z :. Int) Int) <- fromPtr (Z :. 10) ((), ptr)
  assertEqual "Not equal" [1..10] (toList arr)

testBlockCopyTuples :: IO ()
testBlockCopyTuples = do
  intPtr    <- oneToTen
  doublePtr <- tenToOne
  (arr :: Array (Z :. Int) (Int, Double)) <- fromPtr (Z :. 10) (((), intPtr), doublePtr)
  assertEqual "Not equal" [ (x, P.fromIntegral (11 - x)) | x <- [1..10]] (toList arr)

testBlockCopyFromArray :: IO ()
testBlockCopyFromArray = do
  let (arr :: Array (Z:.Int:.Int) Int) = fromList (Z:.10:.10) [2*x | x <- [0..99]]
  ohi <- nInts 100
  toPtr arr ((), ohi)
  b   <- isFilledWithEvens ohi 100
  assertEqual "Not equal" 1 b

testBlockCopyFromArrayWithFunctions :: IO ()
testBlockCopyFromArrayWithFunctions = do
  let n = 5^(3::Int)
  let (arr :: Array (Z:.Int:.Int:.Int) Int) = fromList (Z:.5:.5:.5) [2*x | x <- [0..n-1]]
  ohi <- nInts n
  fromArray arr ((), memcpy ohi)
  b   <- isFilledWithEvens ohi n
  assertEqual "Not equal" 1 b

testBlockCopyFromArrayInt16 :: IO ()
testBlockCopyFromArrayInt16 = do
  let n = 50
  let (arr :: Array (Z:.Int) Int) = fromList (Z:.n) [2*x | x <- [0..n-1]]
  ohi <- nInt16s n
  toPtr arr ((), ohi)
  b   <- isFilledWithEvens ohi n
  assertEqual "Not equal" 1 b

testBlockCopyFromArrayInt64 :: IO ()
testBlockCopyFromArrayInt64 = do
  let n = 73
  let (arr :: Array (Z:.Int) Int) = fromList (Z:.n) [2*x | x <- [0..n-1]]
  ohi <- nInt64s n
  toPtr arr ((), ohi)
  b   <- isFilledWithEvens ohi n
  assertEqual "Not equal" 1 b

foreign import ccall "one_to_ten" oneToTen :: IO (Ptr Int)
foreign import ccall "ten_to_one" tenToOne :: IO (Ptr Double)
foreign import ccall "n_ints" nInts :: Int -> IO (Ptr Int)
foreign import ccall "n_int_16s" nInt16s :: Int -> IO (Ptr Int)
foreign import ccall "n_int_64s" nInt64s :: Int -> IO (Ptr Int)
foreign import ccall "is_filled_with_evens" isFilledWithEvens :: Ptr Int -> Int -> IO Int
foreign import ccall memcpy :: Ptr a -> Ptr b -> Int -> IO ()
