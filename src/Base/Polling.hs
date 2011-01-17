
module Base.Polling where


import Data.Map (Map, fromList, member, (!))
import Data.Word
import qualified Data.Set as Set
import Data.Set (Set, union, difference, insert, intersection, empty, delete)
import Data.IORef

import Control.Concurrent
import Control.Arrow

import System.IO.Unsafe
import System.Info

import Graphics.Qt

import Utils

import Base.Types
import Base.GlobalShortcuts


-- this is for joystick (and gamepad) stuff, will be used soon!
type JJ_Event = ()

{-# NOINLINE keyStateRef #-}
keyStateRef :: IORef ([AppEvent], Set AppButton)
keyStateRef = unsafePerformIO $ newIORef ([], empty)

-- | non-blocking polling of AppEvents
-- Also handles global shortcuts.
pollAppEvents :: Application_ s -> KeyPoller -> M ControlData
pollAppEvents app poller = do
    (unpolledEvents, keyState) <- io $ readIORef keyStateRef
    qEvents <- io $ pollEvents poller
    appEvents <- handleGlobalShortcuts app $
        concatMap (toAppEvent keyState) (map Left qEvents)
    let keyState' = foldr (>>>) id (map updateKeyState appEvents) keyState
    io $ writeIORef keyStateRef ([], keyState')
    return $ ControlData (unpolledEvents ++ appEvents) keyState'

-- | puts AppEvents back to be polled again
unpollAppEvents :: [AppEvent] -> IO ()
unpollAppEvents events = do
    (unpolledEvents, keyState) <- readIORef keyStateRef
    writeIORef keyStateRef (unpolledEvents ++ events, keyState)

resetHeldKeys :: IO ()
resetHeldKeys = do
    modifyIORef keyStateRef (second (const empty))


-- | Blocking wait for the next event.
-- waits between polls
waitForAppEvent :: Application_ s -> KeyPoller -> M AppEvent
waitForAppEvent app poller = do
    ControlData events _ <- pollAppEvents app poller
    case events of
        (a : r) -> io $ do
            unpollAppEvents r
            return a
        [] -> do
            io $ threadDelay (round (0.01 * 10 ^ 6))
            waitForAppEvent app poller


updateKeyState :: AppEvent -> Set AppButton -> Set AppButton
updateKeyState (Press   k) ll = insert k ll
updateKeyState (Release k) ll = delete k ll
updateKeyState Quit ll = ll


toAppEvent :: Set AppButton -> Either QtEvent JJ_Event -> [AppEvent]
-- keyboard
toAppEvent _ (Left (KeyPress key _)) | key `member` key2button =
    [Press (key2button ! key)]
toAppEvent _ (Left (KeyRelease key _)) | key `member` key2button =
    [Release (key2button ! key)]
toAppEvent _ (Left (KeyPress key text)) = [Press (KeyboardButton key text)]
toAppEvent _ (Left (KeyRelease key text)) = [Release (KeyboardButton key text)]

toAppEvent _ (Left CloseWindow) = [Quit]

-- joystick
-- toAppEvent _ (Right (JoyButtonDown 0 jbutton)) | jbutton `member` jbutton2button =
--     [Press   (jbutton2button ! jbutton)]
-- toAppEvent _ (Right (JoyButtonUp   0 jbutton)) | jbutton `member` jbutton2button =
--     [Release (jbutton2button ! jbutton)]
-- toAppEvent oldButtons (Right (JoyHatMotion  0 0 x)) =
--     calculateJoyHatEvents oldButtons x

-- else:


key2button :: Map Key AppButton 
key2button = fromList [
      (platformCtrl, AButton)
    , (Shift, BButton)
    , (Escape, StartButton)

    , (LeftArrow, LeftButton)
    , (RightArrow, RightButton)
    , (UpArrow, UpButton)
    , (DownArrow, DownButton)
  ]

-- stick with Ctrl on osx
-- (Qt::AA_MacDontSwapCtrlAndMeta doesn't seem to work)
platformCtrl = case System.Info.os of
    "darwin" -> Meta
    _ -> Ctrl


-- does not contain 
jbutton2button :: Map Word8 AppButton
jbutton2button = fromList [
    -- xbox controller
      (0, AButton)
    , (1, BButton)
    -- impact controller
    , (2, AButton)
    , (3, BButton)
  ]

-- returns the events from the gamepad hat,
-- given the buttons already reported as pressed
-- and the number returned by SDL for that hat.
-- That number is (up -> 1, right -> 2, down -> 4, left -> 8)
-- added up, if more than one is pressed
calculateJoyHatEvents :: Set AppButton -> Word8 -> [AppEvent]
calculateJoyHatEvents oldButtons n =
    Set.toList (Set.map Press presses `union` Set.map Release releases)
  where
    presses = cp `difference` oldArrowButtons
    releases = oldArrowButtons `difference` cp
    oldArrowButtons = allArrowButtons `intersection` oldButtons
    cp = currentlyPressed n

currentlyPressed :: Word8 -> Set AppButton
currentlyPressed = cp 8
  where
    cp :: Word8 -> Word8 -> Set AppButton
    cp 0 _ = Set.empty
    cp s n
      | n >= s = toButton s `insert` cp (s `div` 2) (n - s)
      | n < s = cp (s `div` 2) n
    toButton n = case n of
        1 -> UpButton
        2 -> RightButton
        4 -> DownButton
        8 -> LeftButton