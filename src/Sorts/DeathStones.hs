{-# language ScopedTypeVariables, MultiParamTypeClasses, DeriveDataTypeable #-}

module Sorts.DeathStones (sorts) where


import Data.Abelian
import Data.Typeable

import System.FilePath

import Physics.Chipmunk as CM

import Graphics.Qt

import Utils

import Base


-- * configuration

type StoneDescription = (SortId, [String], Offset Double)

stones :: [StoneDescription]
stones =
    (SortId "deathstones/lasers/horizontal",
     ("robots" </> "laser" </> "laser-horizontal-standard_00") :
        ("robots" </> "laser" </> "laser-horizontal-standard_01") :
        [],
     Position 1 17) :
    (SortId "deathstones/lasers/vertical",
     ("robots" </> "laser" </> "laser-vertical-standard_00") :
        ("robots" </> "laser" </> "laser-vertical-standard_01") :
        [],
     Position 17 1) :
    []

animationFrameTimes :: [Seconds] = [0.1]


-- * loading

sorts :: RM [Sort_]
sorts = forM stones loadStone

loadStone :: StoneDescription -> RM Sort_
loadStone (sortId, imageNames, offset) = do
    images <- mapM (loadSymmetricPixmap offset) =<< mapM mkPngFile imageNames
    return $ Sort_ $ SSort sortId images
  where
    mkPngFile :: String -> RM FilePath
    mkPngFile imageName = getDataFileName (pngDir </> imageName <.> "png")

data SSort = SSort {
    sortId :: SortId,
    pixmaps :: [Pixmap]
  }
    deriving (Show, Typeable)

data Stone = Stone {
    chipmunk :: Chipmunk
  }
    deriving (Show, Typeable)


instance Sort SSort Stone where
    sortId (SSort s _) = s

    freeSort (SSort _ pixmaps) =
        mapM_ freePixmap pixmaps

    size (SSort _ pixmaps) = pixmapSize $ head pixmaps

    renderIconified sort ptr =
        renderPixmapSimple ptr $ head $ pixmaps sort

    initialize app _ Nothing sort editorPosition Nothing _ = io $ do
        let (shapes, baryCenterOffset) = mkShapes $ size sort
            position = epToPosition (size sort) editorPosition
        return $ Stone $ ImmutableChipmunk position 0 baryCenterOffset []
    initialize app _ (Just space) sort editorPosition Nothing _ = io $ do
        let (shapes, baryCenterOffset) = mkShapes $ size sort
            shapesWithAttributes = map (mkShapeDescription shapeAttributes) shapes
            position = position2vector (epToPosition (size sort) editorPosition)
                            +~ baryCenterOffset
            bodyAttributes = StaticBodyAttributes position
        chip <- CM.initChipmunk space bodyAttributes shapesWithAttributes baryCenterOffset
        return $ Stone chip

    immutableCopy (Stone x) = CM.immutableCopy x >>= return . Stone

    chipmunks (Stone x) = singleton x

    renderObject _ _ o sort ptr offset now = do
        (pos, _) <- getRenderPositionAndAngle (chipmunk o)
        let pixmap = pickAnimationFrame (pixmaps sort) animationFrameTimes now
        return $ singleton $ RenderPixmap pixmap pos Nothing



-- * physics initialisation

shapeAttributes = ShapeAttributes {
    elasticity = 0,
    friction = 0,
    collisionType = DeadlyPermeableCT
  }


mkShapes :: Size Double -> ([ShapeType], Vector)
mkShapes size = ([box], baryCenterOffset)
  where
    box = mkRect (negateAbelian half) size
    half = size2position $ fmap (/ 2) size
    baryCenterOffset = position2vector half