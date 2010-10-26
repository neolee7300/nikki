
module Base.Configuration where


import Graphics.Qt


-- | developing configuration
data Development = Development {
    graphicsProfiling :: Bool,
    physicsProfiling :: Bool,
    windowSize :: WindowSize,
    showScene :: Bool,
    showXYCross :: Bool,
    showChipmunkObjects :: Bool
  }

development = Development {
    graphicsProfiling = False,
    physicsProfiling = False,
    windowSize = Windowed (Size 1000 650), -- FullScreen,
    showScene = True,
    showXYCross = False,
    showChipmunkObjects = False
  }


