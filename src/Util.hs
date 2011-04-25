{-# LANGUAGE ScopedTypeVariables #-}
{-
Need to be very careful with temporary files, if we close them then there is a race condition.
To avoid this we use a unique seed which we pass to openTempFile.
Plus some things corrupt other things, so for fast operations we hold the one lock.
-}

module Util where

import Control.Monad
import System.Directory
import System.Exit
import Control.Exception as E
import System.IO
import System.IO.Unsafe
import System.Cmd
import Data.List
import Control.Concurrent
import System.FilePath


{-# NOINLINE oneVar #-}
oneVar :: MVar ()
oneVar = unsafePerformIO $ newMVar ()

one :: IO a -> IO a
one = withMVar oneVar . const


{-# NOINLINE uniqueIntVar #-}
uniqueIntVar :: MVar Int
uniqueIntVar = unsafePerformIO $ newMVar 1

uniqueInt :: IO Int
uniqueInt = modifyMVar uniqueIntVar $ \x -> return (x+1,x+1)


tempDir :: IO FilePath
tempDir = getTemporaryDirectory


withTempFile :: (FilePath -> IO a) -> IO a
withTempFile f = do
    u <- uniqueInt
    let name = "neil_" ++ show u ++ "_file.tmp"
    E.bracket
        (one $ do (file,h) <- openTempFile "." name; hClose h; return file)
        (\file -> one $ ignoreExceptions $ removeFile file)
        f


withTempDirectory :: (FilePath -> IO a) -> IO a
withTempDirectory f = do
    u <- uniqueInt
    let name = "neil_" ++ show u ++ "_dir.tmp"
    E.bracket
        (one $ do (file,h) <- openTempFile "." name; hClose h; createDirectory (file <.> "dir"); return (file <.> "dir"))
        (\file -> one $ do removeFile $ dropExtension file; removeDirectoryRecursive file)
        f


withDirectory dir cmd = E.bracket
    (do x <- getCurrentDirectory; setCurrentDirectory dir; return x)
    (\old -> setCurrentDirectory old)
    (const cmd)


cmdCodeOutErr :: String -> IO (ExitCode, String, String)
cmdCodeOutErr x = withTempFile $ \stderr -> withTempFile $ \stdout -> do
    res <- system $ x ++ " > " ++ stdout ++ " 2> " ++ stderr
    err <- readFile' stderr
    out <- readFile' stdout
    return (res,out,err)


cmdCode :: String -> IO ExitCode
cmdCode = system


cmd :: String -> IO ()
cmd x = do
    res <- system x
    when (res /= ExitSuccess) $
        error $ "Failed in system command: " ++ x


readFile' :: FilePath -> IO String
readFile' file = do
    h <- openFile file ReadMode
    src <- hGetContents h
    length src `seq` hClose h
    return src


liner :: IO (String -> IO ())
liner = do
    mvar <- newMVar 0
    return $ \msg -> modifyMVar_ mvar $ \old -> do
        let eol = "\n" `isSuffixOf` msg
        msg <- return $ takeWhile (/= '\n') msg
        let new = length msg
        putStr $ (if old == 0 then "" else replicate 1000 '\b') ++ msg ++ replicate (old - new) ' '
        if eol then putStrLn "" >> return 0 else return new


ignoreExceptions :: IO () -> IO ()
ignoreExceptions act = E.catch act (\(x::SomeException) -> return ())