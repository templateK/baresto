module Component.Auth where

import Prelude

import Halogen
import qualified Halogen.HTML.Indexed as H
import qualified Halogen.HTML.Properties.Indexed as P
import qualified Halogen.HTML.Events.Indexed as E

import qualified Component.Spinner as Spinner

import Types

data State = State

initialState :: State
initialState = State

data Query a
  = Foo a

auth :: Component State Query Metrix
auth = component render eval
  where

    render :: Render State Query
    render _ = H.div_ []

    eval :: Eval Query State Query Metrix
    eval (Foo next) = do
      pure next
