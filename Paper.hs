
module Main(main) where

import System.Directory
import System.Environment
import System.FilePath

import Paper.FileData
import Paper.Graph
import Paper.Make
import Paper.WordCount


{-
COMMANDS:
make -- compile the document
wc -- word count
graph -- make a graph
spell -- complete spell check
colin -- auto-colin grammar check
haskell -- auto-haskell checking

CONVENTIONS:
all object files go in obj/ directory
all stored files go in paper/ directory
    the output from chart
    word count logs (used for charting)
    grammar checking logs

all commands that take arguments take either:
    nothing - use the current directory
    a directory name - index.tex is the main file, all other *.tex files are extras
    a list of files - first is the main file, all others are extras (all must be the same directory)
-}

main :: IO ()
main = do
    args <- getArgs
    case args of
        (cmd:files) -> do
            files <- getFileData files
            process cmd files
        _ -> error "No arguments given"


process :: String -> FileData -> IO ()
process "wc" files = do
    let shw = fixed ("total" : map dropExtension (allFiles files))
    res <- flip mapM (allFiles files) $ \file -> do
        putStr $ shw (dropExtension file) ++ "  "
        count <- wordCount (directory files </> file)
        putStrLn $ int count
        return (file,count)
    putStrLn $ shw "Total" ++ "  " ++ int (sum $ map snd res)
    root <- paperDir files
    graphLog (root </> "graph.txt") res

process "graph" files = do
    root <- paperDir files
    let res = root </> "graph.png"
    graphCreate (root </> "graph.txt") res (allFiles files)
    putStrLn $ "Written graph, " ++ res

process "make" files = do
    dat <- dataDir
    obj <- objDir files
    make dat obj files

process x files = putStrLn $ "Error: Unknown action, " ++ show x


----- utility stuff

dataDir :: IO FilePath
dataDir = return "E:\\Neil\\paper\\data"


paperDir, objDir :: FileData -> IO FilePath
paperDir = ensureDir "paper"
objDir   = ensureDir "obj"


ensureDir :: FilePath -> FileData -> IO FilePath
ensureDir name files = do
    let s = directory files </> name
    createDirectoryIfMissing True s
    return s


----- mini formatting library

padR, padL :: Int -> String -> String
padL n s = replicate (n - length s) ' ' ++ s
padR n s = s ++ replicate (n - length s) ' '


maxIntWidth = maximum $ map (length . show) [minBound::Int, maxBound]

int :: Int -> String
int = padL maxIntWidth . show


fixed :: [String] -> String -> String
fixed ss = let n = maximum $ map length ss
           in \s -> padR n s
