module Api.Schema.BusinessData where

import Prelude
import Data.Map as M
import Api.Schema.BusinessData.Key (Key, parseKeyF)
import Api.Schema.BusinessData.Value (Value(Value), UpdateValue(UpdateValuePrecision, UpdateValueData))
import Api.Schema.Common (Pair(Pair))
import Api.Schema.Validation (ValidationType, HoleCoords, ValidationResult)
import Data.Argonaut.Core (jsonEmptyObject)
import Data.Argonaut.Encode (class EncodeJson, encodeJson)
import Data.Argonaut.Encode.Combinators ((:=), (~>))
import Data.Foreign (ForeignError(JSONError), fail)
import Data.Foreign.Class (class IsForeign, readProp, read)
import Data.Foreign.Keys (keys)
import Data.Foreign.NullOrUndefined (unNullOrUndefined)
import Data.List (toUnfoldable)
import Data.Map (fromFoldable)
import Data.Maybe (Maybe)
import Data.Traversable (traverse)
import Data.Tuple (Tuple(Tuple))
import Types (UTCTime, UpdateId, TagId)

newtype Update = Update (Array (Tuple Key UpdateValue))

instance isForeignUpdate :: IsForeign Update where
  read json = do
    list <- read json
    let mkPair (Pair (Tuple k v)) = Tuple <$> parseKeyF k <*> read v
    Update <$> traverse mkPair list

instance encodeJsonUpdate :: EncodeJson Update where
  encodeJson (Update m) = encodeJson (showKeys <$> m)
    where showKeys (Tuple k v) = Pair $ Tuple (show k) v

newtype Snapshot = Snapshot (M.Map Key Value)

instance isForeignSnapshot :: IsForeign Snapshot where
  read json = do
    ks <- keys json
    let mkPair k = Tuple <$> parseKeyF k <*> readProp k json
    kvs <- traverse mkPair ks
    pure $ Snapshot $ fromFoldable kvs

snapshotToUpdate :: Snapshot -> Update
snapshotToUpdate (Snapshot m) = Update $ join $ toUpdates <$> (toUnfoldable $ M.toList m)
  where toUpdates (Tuple k (Value v)) =
             [Tuple k (UpdateValueData v.valueData)]
          <> [Tuple k (UpdateValuePrecision v.valuePrecision)]

--

newtype UpdatePost = UpdatePost
  { updatePostParentId       :: UpdateId
  , updatePostUpdate         :: Update
  , updatePostValidationType :: ValidationType
  }

instance encodeJsonUpdatePost :: EncodeJson UpdatePost where
  encodeJson (UpdatePost p) = "parentId"       := p.updatePostParentId
                           ~> "update"         := p.updatePostUpdate
                           ~> "validationType" := p.updatePostValidationType
                           ~> jsonEmptyObject

newtype UpdatePostResult = UpdatePostResult
  { uprUpdateDesc       :: UpdateDesc
  , uprValidationResult :: ValidationResult
  }

instance isForeignUpdatePostResult :: IsForeign UpdatePostResult where
  read json = do
    upr <- { uprUpdateDesc: _
           , uprValidationResult: _
           }
      <$> readProp "updateDesc" json
      <*> readProp "validationResult" json
    pure $ UpdatePostResult upr

newtype UpdateGet = UpdateGet
  { updateGetId       :: UpdateId
  , updateGetCreated  :: UTCTime
  , updateGetParentId :: Maybe UpdateId
  , updateGetUpdate   :: Update
  }

instance isForeignUpdateGet :: IsForeign UpdateGet where
  read json = do
    upd <- { updateGetId: _
           , updateGetCreated: _
           , updateGetParentId: _
           , updateGetUpdate: _
           }
      <$> readProp "updateId" json
      <*> readProp "created" json
      <*> (unNullOrUndefined <$> readProp "parentId" json)
      <*> readProp "update" json
    pure $ UpdateGet upd

newtype SnapshotDesc = SnapshotDesc
  { snapshotDescUpdateId :: UpdateId
  , snapshotDescCreated  :: UTCTime
  , snapshotDescParentId :: Maybe UpdateId
  , snapshotDescSnapshot :: Snapshot
  }

instance isForeignSnapshotDesc :: IsForeign SnapshotDesc where
  read json = do
    upd <- { snapshotDescUpdateId: _
           , snapshotDescCreated: _
           , snapshotDescParentId: _
           , snapshotDescSnapshot: _
           }
      <$> readProp "updateId" json
      <*> readProp "created" json
      <*> (unNullOrUndefined <$> readProp "parentId" json)
      <*> readProp "snapshot" json
    pure $ SnapshotDesc upd

newtype UpdateDesc = UpdateDesc
  { updateDescUpdateId :: UpdateId
  , updateDescCreated  :: UTCTime
  , updateDescAuthor   :: String
  , updateDescTags     :: Array TagDesc
  , updateDescChanges  :: Array UpdateChange
  }

instance isForeignUpdateDesc :: IsForeign UpdateDesc where
  read json = do
    desc <- { updateDescUpdateId: _
            , updateDescCreated: _
            , updateDescAuthor: _
            , updateDescTags: _
            , updateDescChanges: _
            }
      <$> readProp "updateId" json
      <*> readProp "created" json
      <*> readProp "author" json
      <*> readProp "tags" json
      <*> readProp "changes" json
    pure $ UpdateDesc desc

newtype UpdateChange = UpdateChange
  { updateChangeLoc :: ChangeLocationHuman
  , updateChangeOld :: Value
  , updateChangeNew :: Value
  }

instance isForeignUpdateEntry :: IsForeign UpdateChange where
  read json = do
    entry <- { updateChangeLoc: _
             , updateChangeOld: _
             , updateChangeNew: _
             }
      <$> readProp "location" json
      <*> readProp "old" json
      <*> readProp "new" json
    pure $ UpdateChange entry

data ChangeLocationHuman
  = HumanHeaderFact String               -- label
  | HumanFact       String HoleCoords    -- table coords
  | HumanSubsetZ    String String        -- table member
  | HumanCustomZ    String               -- table
  | HumanCustomRow  String String String -- table member sheet

instance isForeignUpdateEntryHuman :: IsForeign ChangeLocationHuman where
  read json = do
    typ <- readProp "type" json
    case typ of
      "header"    -> HumanHeaderFact <$> readProp "label" json
      "fact"      -> HumanFact <$> readProp "table" json
                               <*> readProp "coords" json
      "subsetZ"   -> HumanSubsetZ <$> readProp "table" json
                                  <*> readProp "member" json
      "customZ"   -> HumanCustomZ <$> readProp "table" json
      "customRow" -> HumanCustomRow <$> readProp "table" json
                                    <*> readProp "member" json
                                    <*> readProp "sheet" json
      _           -> fail $ JSONError "expected `header`, `fact`, `subsetZ`, `customZ` or `customRow`"

newtype TagDesc = TagDesc
  { tagDescTagId    :: TagId
  , tagDescUpdateId :: UpdateId
  , tagDescTagName  :: String
  , tagDescCreated  :: UTCTime
  }

instance isForeignTagDesc :: IsForeign TagDesc where
  read json = do
    desc <- { tagDescTagId: _
            , tagDescUpdateId: _
            , tagDescTagName: _
            , tagDescCreated: _
            }
      <$> readProp "tagId" json
      <*> readProp "updateId" json
      <*> readProp "name" json
      <*> readProp "created" json
    pure $ TagDesc desc
