{-# language NamedFieldPuns, FlexibleInstances, DeriveDataTypeable #-}


-- module for often used types (in one Base module, to avoid module import cycles.)

module Base.Types where


import Data.Set
import Data.Indexable
import Data.Initial
import Data.Abelian
import Data.Array.Storable
import Data.SelectTree
import Data.Menu hiding (selected)
import Data.Typeable

import Physics.Chipmunk

import Graphics.Qt

import Utils

import Base.Constants
import Base.Grounds


data Scene object
    = Scene {
        spaceTime :: Seconds,
        objects :: Grounds object,
        cameraState :: CameraState,
        contactRef :: !(ContactRef Contacts),
        contacts :: !Contacts,
        mode :: Mode
      }
  deriving Show
  
-- * getter

-- | returns the object currently controlled by the gamepad
getControlled :: Scene o -> o
getControlled s = s |> getControlledIndex |> getMainlayerObject s

getControlledIndex :: Scene o -> Index
getControlledIndex Scene{mode} =
    case mode of
        NikkiMode{nikki} -> nikki
        TerminalMode{terminal} -> terminal
        RobotMode{robot} -> robot
        LevelFinished{lastControlled} -> lastControlled

-- | returns an object from the mainLayer
getMainlayerObject :: Scene o -> Index -> o
getMainlayerObject s@Scene{objects} i = mainLayerIndexable objects !!! i


-- * modifications

modifyMainlayerObjectByIndex :: (o -> o) -> Index -> Scene o -> Scene o
modifyMainlayerObjectByIndex f i =
    modifyObjects (modifyMainLayer (modifyByIndex f i))

modifyObjects :: (Grounds a -> Grounds b) -> Scene a -> Scene b
modifyObjects f s@Scene{objects} =
    s{objects = f objects}

modifyObjectsM :: Monad m => (Grounds a -> m (Grounds b)) -> Scene a -> m (Scene b)
modifyObjectsM op s@Scene{objects} =
    op objects >>= \ new -> return s{objects = new}

modifyMode :: (Mode -> Mode) -> Scene o -> Scene o
modifyMode f s@Scene{mode} = s{mode = f mode}


data CameraState
    = CS Vector
  deriving Show

instance Initial CameraState where
    initial = CS zero



data Contacts
    = Contacts {
        nikkiContacts :: [(StorableArray Int Contact, Double)],
        nikkiFeetTouchGround :: !Bool,
        nikkiPawTouchesGround :: !Bool,
        nikkiTouchesLaser :: !Bool,
        triggers :: Set Shape,
        terminals :: Set Shape,
        batteries :: Set Shape,
        fallingTiles :: Set Shape
      }
  deriving Show

instance Show (StorableArray Int Contact) where
    show = const "<StorableArray>"


-- * mode for the game scene
data Mode
    = NikkiMode {
        nikki :: Index
      }
    | TerminalMode {
        nikki :: Index,
        terminal :: Index
      }
    | RobotMode{
        nikki :: Index,
        terminal :: Index,
        robot :: Index
      }
    | LevelFinished {
        lastControlled :: Index,
        levelResult :: LevelResult
      }
  deriving Show

-- | returns, if Nikki is controlled currently
isNikkiMode :: Mode -> Bool
isNikkiMode NikkiMode{} = True

-- | returns, if a robot is controlled currently
isRobotMode :: Mode -> Bool
isRobotMode RobotMode{} = True
isRobotMode _ = False

isTerminalMode :: Mode -> Bool
isTerminalMode TerminalMode{} = True
isTerminalMode _ = False


data LevelResult = Passed | Failed
  deriving Show


-- * EditorScene types

data EditorScene sort
    = EditorScene {
        levelPath :: Maybe FilePath,

        cursor :: EditorPosition,
        cursorStep :: EditorScene sort -> EditorPosition,

        availableSorts :: SelectTree sort,

        editorObjects :: Grounds (EditorObject sort),
        selectedLayer :: GroundsIndex,
        selected :: Maybe Index,
            -- index of the object that is in the scene and currently under the cursor
            -- (in the selected layer)
        objectEditModeIndex :: Maybe Index,

        debugMsgs :: [String]
    }
    | MenuScene {
        mainScene :: EditorScene sort,
        menu :: Menu (MenuLabel sort) (EditorScene sort),

        debugMsgs :: [String]
      }
    | ExitEditorScene {
        levelPath :: Maybe FilePath,
        editorObjects :: Grounds (EditorObject sort)
      }
  deriving (Show, Typeable)

instance Show (EditorScene sort -> EditorPosition) where
    show _ = "<EditorScene -> EditorPosition>"


getLevelPath :: EditorScene sort -> Maybe FilePath
getLevelPath EditorScene{levelPath} = levelPath
getLevelPath MenuScene{mainScene} = levelPath mainScene

getCursorStep :: EditorScene sort -> EditorPosition
getCursorStep s = cursorStep s s


data MenuLabel sort = MenuLabel (Maybe sort) String
  deriving (Show)


data EditorPosition = EditorPosition {
    editorX :: Double,
    editorY :: Double
  }
  deriving (Show, Read, Eq)

instance Abelian EditorPosition where
    zero = EditorPosition 0 0
    (EditorPosition a b) +~ (EditorPosition x y) =
        EditorPosition (a + x) (b + y)
    (EditorPosition a b) -~ (EditorPosition x y) =
        EditorPosition (a - x) (b - y)


-- * Editor objects

data EditorObject sort
    = EditorObject {
        editorSort :: sort,
        editorPosition :: EditorPosition,
        editorOEMState :: Maybe (OEMState sort)
      }
    | MergedTilesEditorObject {
        editorMergedObjects :: [EditorObject sort]
      }
  deriving Show


data ObjectEditModeMethods sort
    = ObjectEditModeMethods {
        oemInitialState :: EditorPosition -> String,
        oemEnterMode :: EditorScene sort -> String -> String,
        oemUpdate :: EditorScene sort -> Key -> String -> String,
        oemRender :: Ptr QPainter -> EditorScene sort -> String -> IO () -- more args
      }

instance Show (ObjectEditModeMethods sort) where
    show = const "<ObjectEditModeMethods>"

data OEMState sort
    = OEMState {
        methods :: ObjectEditModeMethods sort,
        oemState :: String
      }
  deriving Show

