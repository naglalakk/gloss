{-# OPTIONS -fglasgow-exts #-}
{-# OPTIONS_HADDOCK hide #-}

module Graphics.Gloss.Internals.Interface.Game
	(gameInWindow)
where
import Graphics.Gloss.Color
import Graphics.Gloss.Picture
import Graphics.Gloss.ViewPort
import Graphics.Gloss.Internals.Render.Picture
import Graphics.Gloss.Internals.Render.ViewPort
import Graphics.Gloss.Internals.Interface.Window
import Graphics.Gloss.Internals.Interface.Callback
import Graphics.Gloss.Internals.Interface.Common.Exit
import Graphics.Gloss.Internals.Interface.ViewPort.KeyMouse
import Graphics.Gloss.Internals.Interface.ViewPort.Motion
import Graphics.Gloss.Internals.Interface.ViewPort.Reshape
import Graphics.Gloss.Internals.Interface.Animate.Timing
import Graphics.Gloss.Internals.Interface.Simulate.Idle
import qualified Graphics.Gloss.Internals.Interface.Callback			as Callback
import qualified Graphics.Gloss.Internals.Interface.ViewPort.ControlState	as VPC
import qualified Graphics.Gloss.Internals.Interface.Simulate.State		as SM
import qualified Graphics.Gloss.Internals.Interface.Animate.State		as AN
import qualified Graphics.Gloss.Internals.Render.Options			as RO
import qualified Graphics.UI.GLUT						as GLUT
import Data.IORef
import System.Mem

-- | Possible input events.
data Event
	= EventKey    GLUT.Key GLUT.KeyState GLUT.Modifiers (Int, Int)
	| EventMotion (Int, Int)
	deriving (Eq, Show)

-- | Run a game in a window. 
--	You decide how the world is represented,
--	how to convert the world to a picture, 
--	how to advance the world for each unit of time
--	and how to handle input.
--
--   This function comes with no baked-in commands for controlling the viewport, 
--	but you can still press escape to quit the program.
--
gameInWindow 
	:: forall world
	.  String			-- ^ Name of the window.
	-> (Int, Int)			-- ^ Initial size of the window, in pixels.
	-> (Int, Int)			-- ^ Initial position of the window, in pixels.
	-> Color			-- ^ Background color.
	-> Int				-- ^ Number of simulation steps to take for each second of real time.
	-> world 			-- ^ The initial world.
	-> (world -> Picture)	 	-- ^ A function to convert the world a picture.
	-> (Event -> world -> world)	-- ^ A function to handle input events.
	-> (Float -> world -> world)    -- ^ A function to step the world one iteration.
	-> IO ()

gameInWindow
	windowName
	windowSize
	windowPos
	backgroundColor
	simResolution
	worldStart
	worldToPicture
	worldHandleEvent
	worldAdvance
 = do
	let singleStepTime	= 1

	-- make the simulation state
	stateSR		<- newIORef $ SM.stateInit simResolution

	-- make a reference to the initial world
	worldSR		<- newIORef worldStart

	-- make the initial GL view and render states
	viewSR		<- newIORef viewPortInit
	viewControlSR	<- newIORef VPC.stateInit
	renderSR	<- newIORef RO.optionsInit
	animateSR	<- newIORef AN.stateInit

	let displayFun
	     = do
		-- convert the world to a picture
		world		<- readIORef worldSR
		let picture	= worldToPicture world
	
		-- display the picture in the current view
		renderS		<- readIORef renderSR
		viewS		<- readIORef viewSR

		-- render the frame
		withViewPort 
			viewS
	 	 	(renderPicture renderS viewS picture)
 
		-- perform garbage collection
		performGC

	let callbacks
	     = 	[ Callback.Display	(animateBegin animateSR)
		, Callback.Display 	displayFun
		, Callback.Display	(animateEnd   animateSR)
		, Callback.Idle		(callback_simulate_idle 
						stateSR animateSR viewSR 
						worldSR worldStart (\_ -> worldAdvance)
						singleStepTime)
		, callback_exit () 
		, callback_keyMouse worldSR worldHandleEvent
		, callback_motion   worldSR worldHandleEvent
		, callback_viewPort_reshape ]

	createWindow windowName windowSize windowPos backgroundColor callbacks


-- | Callback for KeyMouse events.
callback_keyMouse 
	:: IORef world	 		-- ^ ref to world state
	-> (Event -> world -> world)	-- ^ fn to handle input events
	-> Callback

callback_keyMouse worldRef eventFn
 	= KeyMouse (handle_keyMouse worldRef eventFn)

handle_keyMouse worldRef eventFn key keyState keyMods pos
 = let	GLUT.Position x y	= pos
	pos'			= (fromIntegral x, fromIntegral y)
   in	worldRef `modifyIORef` \world -> eventFn (EventKey key keyState keyMods pos') world


-- | Callback for Motion events.
callback_motion
	:: IORef world	 		-- ^ ref to world state
	-> (Event -> world -> world)	-- ^ fn to handle input events
	-> Callback

callback_motion worldRef eventFn
 	= Motion (handle_motion worldRef eventFn)

handle_motion worldRef eventFn pos
 = let	GLUT.Position x y	= pos
	pos'			= (fromIntegral x, fromIntegral y)
   in	worldRef `modifyIORef` \world -> eventFn (EventMotion pos') world







