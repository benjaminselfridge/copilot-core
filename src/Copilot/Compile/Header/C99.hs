--------------------------------------------------------------------------------
-- Copyright © 2011 National Institute of Aerospace / Galois, Inc.
--------------------------------------------------------------------------------

-- | Generates a C99 header from a copilot-specification. The functionality
-- provided by the header must be implemented by back-ends targetting C99.

{-# LANGUAGE Safe #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE Rank2Types #-}

module Copilot.Compile.Header.C99
  ( genC99Header
  , c99HeaderName
  ) where

import Copilot.Core
import Data.List (intersperse, nubBy)
import Text.PrettyPrint.HughesPJ
import Prelude hiding (unlines)

--------------------------------------------------------------------------------

genC99Header :: Maybe String -> FilePath -> Spec -> IO ()
genC99Header mprefix path spec =
  let
    filePath = path ++ "/" ++ prefix ++ "copilot.h"
    prefix   = case mprefix of
                 Just cs -> cs ++ "_"
                 _       -> ""
  in
    writeFile filePath (c99Header prefix spec)

c99HeaderName :: Maybe String -> String
c99HeaderName (Just cs) = cs ++ "_" ++ "copilot.h"
c99HeaderName _         = "copilot.h"

c99Header :: String -> Spec -> String
c99Header prefix spec = render $ vcat $
  [ text "/* Generated by Copilot Core." <+> text "*/"
  , text ""
  , ppHeaders
  , text ""
  , text "/* Observers (defined by Copilot): */"
  , text ""
  , ppObservers prefix (specObservers spec)
  , text ""
  , text "/* Triggers (must be defined by user): */"
  , text ""
  , ppTriggerPrototypes prefix (specTriggers spec)
  , text ""
  , text "/* External variables (must be defined by user): */"
  , text ""
  , ppExternalVariables (externVars spec)
  , text ""
  , text "/* External arrays (must be defined by user): */"
  , text ""
  , ppExternalArrays (externArrays spec)
  , text ""
  , text "/* External functions (must be defined by user): */"
  , text ""
  , ppExternalFunctions (externFuns spec)
  , text ""
  , text "/* Step function: */"
  , text ""
  , ppStep prefix
  ]

--------------------------------------------------------------------------------

ppHeaders :: Doc
ppHeaders = unlines
  [ "#include <stdint.h>"
  , "#include <stdbool.h>"
  ]

--------------------------------------------------------------------------------

ppObservers :: String -> [Observer] -> Doc
ppObservers prefix = vcat . map ppObserver

  where

  ppObserver :: Observer -> Doc
  ppObserver
    Observer
      { observerName     = name
      , observerExprType = t } =
          text "extern" <+> text (typeSpec (UType t)) <+>
          text (prefix ++ name) <> text ";"

--------------------------------------------------------------------------------

ppTriggerPrototypes :: String -> [Trigger] -> Doc
ppTriggerPrototypes prefix = vcat . map ppTriggerPrototype

  where

  ppTriggerPrototype :: Trigger -> Doc
  ppTriggerPrototype
    Trigger
      { triggerName = name
      , triggerArgs = args } =
          text "void" <+> text (prefix ++ name) <>
          text "(" <> ppArgs args <> text ");"

    where
    ppArgs :: [UExpr] -> Doc
    ppArgs = hcat . intersperse (text ", ") . map ppArg

    ppArg :: UExpr -> Doc
    ppArg UExpr { uExprType = t } = text (typeSpec (UType t))

--------------------------------------------------------------------------------

ppExternalVariables :: [ExtVar] -> Doc
ppExternalVariables = vcat . map ppExternalVariable

ppExternalVariable :: ExtVar -> Doc
ppExternalVariable
  ExtVar
    { externVarName = name
    , externVarType = t } =
        text "extern" <+> text (typeSpec t) <+> text name <> text ";"

--------------------------------------------------------------------------------

ppExternalArrays :: [ExtArray] -> Doc
ppExternalArrays = vcat . map ppExternalArray . nubBy eq
  where
  eq ExtArray { externArrayName = name1 } ExtArray { externArrayName = name2 } =
    name1 == name2

ppExternalArray :: ExtArray -> Doc
ppExternalArray
  ExtArray
    { externArrayName     = name
    , externArrayElemType = t 
    , externArraySize     = size } 
  =
        text "extern" <+> text (typeSpec (UType t)) 
        <+> text name <> lbrack <> int size <> rbrack
        <> text ";"

--------------------------------------------------------------------------------

ppExternalFunctions :: [ExtFun] -> Doc
ppExternalFunctions = vcat . map ppExternalFunction . nubBy eq
  where
  eq ExtFun { externFunName = name1 } ExtFun { externFunName = name2 } =
    name1 == name2

ppExternalFunction :: ExtFun -> Doc
ppExternalFunction
  ExtFun
    { externFunName = name
    , externFunType = t
    , externFunArgs = args } =
        text (typeSpec (UType t)) <+> text name <>
        text "(" <> ppArgs args <> text ");"

  where
  ppArgs :: [UExpr] -> Doc
  ppArgs = hcat . intersperse (text ",") . map ppArg

  ppArg :: UExpr -> Doc
  ppArg UExpr { uExprType = t1 } = text (typeSpec (UType t1))

--------------------------------------------------------------------------------

typeSpec :: UType -> String
typeSpec UType { uTypeType = t }
  = case t of
      Bool   -> "bool"
      Int8   -> "int8_t"
      Int16  -> "int16_t"
      Int32  -> "int32_t"
      Int64  -> "int64_t"
      Word8  -> "uint8_t"
      Word16 -> "uint16_t"
      Word32 -> "uint32_t"
      Word64 -> "uint64_t"
      Float  -> "float"
      Double -> "double"

--------------------------------------------------------------------------------

ppStep :: String -> Doc
ppStep prefix = text "void" <+> text (prefix ++ "step") <> text "(void);"

--------------------------------------------------------------------------------

unlines :: [String] -> Doc
unlines = vcat . map text

--------------------------------------------------------------------------------
