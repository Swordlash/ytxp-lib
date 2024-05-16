module Cardano.YTxP.Control.Yielding.MintingPolicy (
  -- * Minting Policy
  YieldingMPScript (mintingPolicy),
  compileYieldingMP,

  -- * Currency Symbol
  YieldingMPCS,
  mkYieldingMPCS,
) where

import Cardano.YTxP.Control.YieldList.MintingPolicy (YieldListSTCS)
import Cardano.YTxP.Control.Yielding.Helper (yieldingHelper)
import Data.Aeson (
  FromJSON (parseJSON),
  ToJSON (toEncoding, toJSON),
  object,
  pairs,
  withObject,
  (.:),
  (.=),
 )
import Data.Text (Text)
import Numeric.Natural (Natural)
import Plutarch (Config, compile)
import Plutarch.Api.V2 (PScriptContext, scriptHash)
import Plutarch.Script (Script)
import PlutusLedgerApi.V2 (CurrencySymbol (CurrencySymbol), getScriptHash)

--------------------------------------------------------------------------------
-- Yielding Minting Policy Script

-- | @since 0.1.0
data YieldingMPScript = YieldingMPScript
  { nonce :: Natural
  -- ^ @since 0.1.0
  , mintingPolicy :: Script
  -- ^ @since 0.1.0
  }

-- | @since 0.1.0
instance ToJSON YieldingMPScript where
  {-# INLINEABLE toJSON #-}
  toJSON ysvs =
    object
      [ "nonce" .= nonce ysvs
      , "stakingValidator"
          .= (HexStringScript @"StakingValidator" . mintingPolicy $ ysvs)
      ]
  {-# INLINEABLE toEncoding #-}
  toEncoding ysvs =
    pairs $
      "nonce" .= nonce ysvs
        <> "mintingPolicy"
          .= (HexStringScript @"StakingValidator" . mintingPolicy $ ysvs)

-- | @since 0.1.0
instance FromJSON YieldingMPScript where
  {-# INLINEABLE parseJSON #-}
  parseJSON = withObject "YieldingMPScript" $ \obj -> do
    ysvsNonce <- obj .: "nonce"
    (HexStringScript ysvsStakingValidator) :: HexStringScript "StakingValidator" <-
      obj .: "mintingPolicy"
    pure $ YieldingMPScript ysvsNonce ysvsStakingValidator

compileYieldingMP ::
  Config ->
  YieldListSTCS ->
  Natural ->
  Either
    Text
    YieldingMPScript
compileYieldingMP config ylstcs nonce = do
  let
    yieldingMP ::
      forall (s :: S).
      ( Term s (PData :--> PScriptContext :--> POpaque)
      )
    yieldingMP = plet (pconstant $ toInteger nonce) (const $ yieldingHelper ylstcs)
  script <- compile config yieldingMP
  pure $ YieldingMPScript nonce script

-------------------------------------------------------------------------------
-- Yielding Minting Policy Currency Symbol

-- | Opaque, semantic newtype for the YieldList state thread currency symbol
newtype YieldingMPCS = YieldingMPCS CurrencySymbol

mkYieldingMPCS :: YieldingMPScript -> YieldingMPCS
mkYieldingMPCS (YieldingMPScript _nonce script) =
  YieldingMPCS $ CurrencySymbol (getScriptHash $ scriptHash script)