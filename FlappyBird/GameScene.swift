//
//  GameScene.swift
//  FlappyBird
//
//  Created by pmst on 15/10/4.
//  Copyright (c) 2016年 Dean. All rights reserved.
//

import SpriteKit

enum Layer: CGFloat {
	case Background
	case Obstacle
	case Foreground
	case Player
	case UI
	case Flash
}

enum GameState {
	case MainMenu
	case Tutorial
	case Play
	case Falling
	case ShowingScore
	case Gameover
}

struct PhysicsCategory {
	static let None: UInt32 = 0
	static let Player: UInt32 = 0b1
	static let Obstacle: UInt32 = 0b10
	static let Ground: UInt32 = 0b100
}

class GameScene: SKScene, SKPhysicsContactDelegate {
	let kGravity: CGFloat = -150.0 // 重力
	let kImpluse: CGFloat = 150 // 上升力
	let kGroundSpeed: CGFloat = 150 // 地面移动速度
	let kBottomObstacleMinFraction: CGFloat = 0.1
	let kBottomObstacleMaxFraction: CGFloat = 0.6
	let kGapMultiplier: CGFloat = 3.5
	let kFontName = "AmericanTypewriter-Bold"
	let kMargin: CGFloat = 20.0
	let kAnimDelay = 0.3
	let kMinDegrees: CGFloat = -90
	let kMaxDegrees: CGFloat = 25
	let kAngularVelocity: CGFloat = 1000.0 // 角速度
	
	let worldNode = SKNode()
	let player = SKSpriteNode(imageNamed: "Bird0")
	let sombrero = SKSpriteNode(imageNamed: "Sombrero")
	
	var playableStart: CGFloat = 0
	var playableHeight: CGFloat = 0
	var lastUpdateTime: NSTimeInterval = 0 // 上次 render 的时间
	var dt: NSTimeInterval = 0 // 两次 render 之间的时间差
	var playerVelocity = CGPoint.zero // 速度  变量类型为一个点
	var hitGround = false
	var hitObstacle = false
	var gameState: GameState = .Play
	var scoreLabel: SKLabelNode!
	var score = 0
	var playerAngularVelocity: CGFloat = 0.0
	var lastTouchTime: NSTimeInterval = 0
	var lastTouchY: CGFloat = 0.0
	
	let coinAction = SKAction.playSoundFileNamed("coin.wav", waitForCompletion: false)
	let dingAction = SKAction.playSoundFileNamed("ding.wav", waitForCompletion: false)
	let fallingAction = SKAction.playSoundFileNamed("falling.wav", waitForCompletion: false)
	let flappingAction = SKAction.playSoundFileNamed("flapping.wav", waitForCompletion: false)
	let hitGroundAction = SKAction.playSoundFileNamed("hitGround.wav", waitForCompletion: false)
	let popAction = SKAction.playSoundFileNamed("pop.wav", waitForCompletion: false)
	let whackAction = SKAction.playSoundFileNamed("whack.wav", waitForCompletion: false)
	
	init(size: CGSize, gameState: GameState) {
		self.gameState = gameState
		super.init(size: size)
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func didMoveToView(view: SKView) {
		physicsWorld.gravity = CGVector(dx: 0, dy: 0)
		physicsWorld.contactDelegate = self
		
		addChild(worldNode)
		
		if gameState == .MainMenu {
			switchToMainMenu()
		} else {
			switchToTutorial()
		}
	}
	
	override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
		let touch = touches.first
		let touchLocation = touch?.locationInNode(self)
		switch gameState {
		case .MainMenu:
			if touchLocation?.y < size.height * 0.15 {
				// learn()
			} else if touchLocation?.x < size.width * 0.6 {
				switchToNewGame(.Tutorial)
			}
			break
		case .Tutorial:
			switchToPlay()
			break
		case .Play:
			flapPlayer()
		case .Falling:
			break
		case .ShowingScore:
			break
		case .Gameover:
			if touchLocation?.x < size.width * 0.6 {
				switchToNewGame(.MainMenu)
			}
			break
		}
	}
	
	override func update(currentTime: CFTimeInterval) {
		/* Called before each frame is rendered */
		if lastUpdateTime > 0 {
			dt = currentTime - lastUpdateTime
		} else {
			dt = 0
		}
		lastUpdateTime = currentTime
		
		// print("两次更新的间隔时间为\(dt*1000)毫秒")
		
		switch gameState {
		case .MainMenu:
			break
		case .Tutorial:
			break
		case .Play:
			updateForeground()
			updatePlayer()
			checkHitObstacle()
			checkHitGround()
			updateScore()
			break
		case .Falling:
			updatePlayer()
			checkHitGround()
			break
		case .ShowingScore:
			break
		case .Gameover:
			break
		}
		
	}
	
	// MARK: - Setup
	
	func setupBackground() {
		let background = SKSpriteNode(imageNamed: "Background")
		background.anchorPoint = CGPointMake(0.5, 1)
		background.position = CGPointMake(size.width / 2.0, size.height)
		background.zPosition = Layer.Background.rawValue
		worldNode.addChild(background)
		
		playableStart = size.height - background.size.height
		playableHeight = background.size.height
		
		let lowerLeft = CGPoint(x: 0, y: playableStart)
		let lowerRight = CGPoint(x: size.width, y: playableStart)
		
		self.physicsBody = SKPhysicsBody(edgeFromPoint: lowerLeft, toPoint: lowerRight)
		self.physicsBody?.categoryBitMask = PhysicsCategory.Ground
		self.physicsBody?.collisionBitMask = 0
		self.physicsBody?.contactTestBitMask = PhysicsCategory.Player
	}
	
	func setupForeground() {
		for i in 0..<2 {
			let foreground = SKSpriteNode(imageNamed: "Ground")
			foreground.anchorPoint = CGPoint(x: 0, y: 1)
			// foreground.position = CGPoint(x: 0, y: playableStart)
			foreground.position = CGPoint(x: CGFloat(i) * size.width, y: playableStart)
			foreground.zPosition = Layer.Foreground.rawValue
			foreground.name = "foreground"
			worldNode.addChild(foreground)
		}
	}
	
	func setupLabel() {
		scoreLabel = SKLabelNode(fontNamed: kFontName)
		scoreLabel.fontColor = SKColor(red: 101.0 / 255.0, green: 71.0 / 255.0, blue: 73.0 / 255.0, alpha: 1.0)
		scoreLabel.position = CGPoint(x: size.width / 2, y: size.height - kMargin)
		scoreLabel.text = "0"
		scoreLabel.verticalAlignmentMode = .Top
		scoreLabel.zPosition = Layer.UI.rawValue
		worldNode.addChild(scoreLabel)
	}
	
	func setupScorecard() {
		if score > bestScore() {
			setBestScore(score)
		}
		
		let scorecard = SKSpriteNode(imageNamed: "ScoreCard")
		scorecard.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
		scorecard.name = "Tutorial"
		scorecard.zPosition = Layer.UI.rawValue
		worldNode.addChild(scorecard)
		
		let lastScore = SKLabelNode(fontNamed: kFontName)
		lastScore.fontColor = SKColor(red: 101.0 / 255.0, green: 71.0 / 255.0, blue: 73.0 / 255.0, alpha: 1.0)
		lastScore.position = CGPoint(x: -scorecard.size.width * 0.25, y: -scorecard.size.height * 0.2)
		lastScore.text = "\(score)"
		scorecard.addChild(lastScore)
		
		let bestScoreLabel = SKLabelNode(fontNamed: kFontName)
		bestScoreLabel.fontColor = SKColor(red: 101.0 / 255.0, green: 71.0 / 255.0, blue: 73.0 / 255.0, alpha: 1.0)
		bestScoreLabel.position = CGPoint(x: scorecard.size.width * 0.25, y: -scorecard.size.height * 0.2)
		bestScoreLabel.text = "\(self.bestScore())"
		scorecard.addChild(bestScoreLabel)
		
		let gameOver = SKSpriteNode(imageNamed: "GameOver")
		gameOver.position = CGPoint(x: size.width / 2, y: size.height / 2 + scorecard.size.height / 2 + kMargin + gameOver.size.height / 2)
		gameOver.zPosition = Layer.UI.rawValue
		worldNode.addChild(gameOver)
		
		let okButton = SKSpriteNode(imageNamed: "Button")
		okButton.position = CGPoint(x: size.width * 0.25, y: size.height / 2 - scorecard.size.height / 2 - kMargin - okButton.size.height / 2)
		okButton.zPosition = Layer.UI.rawValue
		worldNode.addChild(okButton)
		
		let ok = SKSpriteNode(imageNamed: "OK")
		ok.position = CGPoint.zero
		ok.zPosition = Layer.UI.rawValue
		okButton.addChild(ok)
		
		let shareButton = SKSpriteNode(imageNamed: "Button")
		shareButton.position = CGPoint(x: size.width * 0.75, y: size.height / 2 - scorecard.size.height / 2 - kMargin - shareButton.size.height / 2)
		shareButton.zPosition = Layer.UI.rawValue
		worldNode.addChild(shareButton)
		
		let share = SKSpriteNode(imageNamed: "Share")
		share.position = CGPoint.zero
		share.zPosition = Layer.UI.rawValue
		shareButton.addChild(share)
		
		gameOver.setScale(0)
		gameOver.alpha = 0
		let group = SKAction.group([
			SKAction.fadeInWithDuration(kAnimDelay),
			SKAction.scaleTo(1.0, duration: kAnimDelay)
		])
		group.timingMode = .EaseInEaseOut
		gameOver.runAction(SKAction.sequence([
			SKAction.waitForDuration(kAnimDelay),
			group
			]))
		scorecard.position = CGPoint(x: size.width * 0.5, y: -scorecard.size.height / 2)
		let moveTo = SKAction.moveTo(CGPoint(x: size.width / 2, y: size.height / 2), duration: kAnimDelay)
		moveTo.timingMode = .EaseInEaseOut
		scorecard.runAction(SKAction.sequence([
			SKAction.waitForDuration(kAnimDelay * 2),
			moveTo
			]))
		okButton.alpha = 0
		shareButton.alpha = 0
		let fadeIn = SKAction.sequence([
			SKAction.waitForDuration(kAnimDelay * 3),
			SKAction.fadeInWithDuration(kAnimDelay)
		])
		okButton.runAction(fadeIn)
		shareButton.runAction(fadeIn)
		
		let pops = SKAction.sequence([
			SKAction.waitForDuration(kAnimDelay),
			popAction,
			SKAction.waitForDuration(kAnimDelay),
			popAction,
			SKAction.waitForDuration(kAnimDelay),
			popAction,
			SKAction.runBlock(switchToGameOver)
		])
		runAction(pops)
	}
	
	func setupMainMenu() {
		let logo = SKSpriteNode(imageNamed: "Logo")
		logo.position = CGPoint(x: size.width / 2, y: size.height * 0.8)
		logo.zPosition = Layer.UI.rawValue
		worldNode.addChild(logo)
		
		let playButton = SKSpriteNode(imageNamed: "Button")
		playButton.position = CGPoint(x: size.width * 0.25, y: size.height * 0.25)
		playButton.zPosition = Layer.UI.rawValue
		worldNode.addChild(playButton)
		
		let play = SKSpriteNode(imageNamed: "Play")
		play.position = CGPoint.zero
		playButton.addChild(play)
		
		let rateButton = SKSpriteNode(imageNamed: "Button")
		rateButton.position = CGPoint(x: size.width * 0.75, y: size.height * 0.25)
		rateButton.zPosition = Layer.UI.rawValue
		worldNode.addChild(rateButton)
		
		let rate = SKSpriteNode(imageNamed: "Rate")
		rate.position = CGPoint.zero
		rateButton.addChild(rate)
		
		let learn = SKSpriteNode(imageNamed: "button_learn")
		learn.position = CGPoint(x: size.width * 0.5, y: learn.size.height / 2 + kMargin)
		learn.zPosition = Layer.UI.rawValue
		worldNode.addChild(learn)
		
		let scaleUp = SKAction.scaleTo(1.02, duration: 0.75)
		scaleUp.timingMode = .EaseInEaseOut
		let scaleDown = SKAction.scaleTo(0.98, duration: 0.75)
		scaleDown.timingMode = .EaseInEaseOut
		
		learn.runAction(SKAction.repeatActionForever(SKAction.sequence([
			scaleUp, scaleDown
			])))
	}
	
	func setupTutorial() {
		let tutorial = SKSpriteNode(imageNamed: "Tutorial")
		tutorial.position = CGPoint(x: size.width * 0.5, y: playableHeight * 0.4 + playableStart)
		tutorial.name = "Tutorial"
		tutorial.zPosition = Layer.UI.rawValue
		worldNode.addChild(tutorial)
		
		let ready = SKSpriteNode(imageNamed: "Ready")
		ready.position = CGPoint(x: size.width * 0.5, y: playableHeight * 0.7 + playableStart)
		ready.name = "Tutorial"
		ready.zPosition = Layer.UI.rawValue
		worldNode.addChild(ready)
	}
	
	func setupPlayer() {
		player.position = CGPointMake(size.width * 0.2, playableHeight * 0.4 + playableStart)
		player.zPosition = Layer.Player.rawValue
		
		let offsetX = player.size.width * player.anchorPoint.x
		let offsetY = player.size.height * player.anchorPoint.y
		let path = CGPathCreateMutable()
		
		CGPathMoveToPoint(path, nil, 17 - offsetX, 23 - offsetY)
		CGPathAddLineToPoint(path, nil, 39 - offsetX, 22 - offsetY)
		CGPathAddLineToPoint(path, nil, 38 - offsetX, 10 - offsetY)
		CGPathAddLineToPoint(path, nil, 21 - offsetX, 0 - offsetY)
		CGPathAddLineToPoint(path, nil, 4 - offsetX, 1 - offsetY)
		CGPathAddLineToPoint(path, nil, 3 - offsetX, 15 - offsetY)
		
		CGPathCloseSubpath(path)
		
		player.physicsBody = SKPhysicsBody(polygonFromPath: path)
		player.physicsBody?.categoryBitMask = PhysicsCategory.Player
		player.physicsBody?.collisionBitMask = 0
		player.physicsBody?.contactTestBitMask = PhysicsCategory.Ground | PhysicsCategory.Obstacle
		
		worldNode.addChild(player)
	}
	
	func setupPlayerAnimation() {
		var textures: Array<SKTexture> = []
		for i in 0..<4 {
			textures.append(SKTexture(imageNamed: "Bird\(i)"))
		}
		for i in 3.stride(to: 0, by: -1) {
			textures.append(SKTexture(imageNamed: "Bird\(i)"))
		}
		
		let playerAnimation = SKAction.animateWithTextures(textures, timePerFrame: 0.07)
		player.runAction(SKAction.repeatActionForever(playerAnimation))
	}
	
	func setupSombrero() {
		sombrero.position = CGPointMake(31 - sombrero.size.width / 2, 29 - sombrero.size.height / 2)
		player.addChild(sombrero)
	}
	
	// MARK: - Update
	
	func updatePlayer() {
		let gravity = CGPoint(x: 0, y: kGravity) // 设置 y方向上的加速度
		let gravityStep = gravity * CGFloat(dt)
		playerVelocity += gravityStep // player 的瞬时速度
		
		let velocityStep = playerVelocity * CGFloat(dt)
		player.position += velocityStep
		
		if player.position.y - player.size.height / 2 < playableStart {
			player.position = CGPoint(x: player.position.x, y: playableStart + player.size.height / 2) // player 静止在 playableStart
		}
		
		if player.position.y < lastTouchY {
			playerAngularVelocity = -kAngularVelocity.degreesToRadians()
		}
		
		let angularStep = playerAngularVelocity * CGFloat(dt)
		player.zRotation += angularStep
		player.zRotation = min(max(player.zRotation, kMinDegrees.degreesToRadians()), kMaxDegrees.degreesToRadians())
	}
	
	func updateForeground() {
		worldNode.enumerateChildNodesWithName("foreground", usingBlock: { (node, stop) -> Void in
			if let foreground = node as? SKSpriteNode {
				let moveAmt = CGPointMake(-self.kGroundSpeed * CGFloat(self.dt), 0)
				foreground.position += moveAmt
				if foreground.position.x < -foreground.size.width {
					foreground.position += CGPoint(x: foreground.size.width * CGFloat(2), y: 0)
				}
			}
		})
	}
	
	func updateScore() {
		worldNode.enumerateChildNodesWithName("BottomObstacle", usingBlock: { node, stop in
			if let obstacle = node as? SKSpriteNode {
				if let passed = obstacle.userData?["Passed"] as? NSNumber {
					if passed.boolValue {
						return
					}
				}
				if self.player.position.x > obstacle.position.x + obstacle.size.width / 2 {
					self.score = self.score + 1
					self.scoreLabel.text = "\(self.score)"
					self.runAction(self.coinAction)
					obstacle.userData?["Passed"] = NSNumber(bool: true)
				}
				
			}
		})
	}
	
	// MARK: - Check
	
	func checkHitObstacle() {
		if hitObstacle {
			hitObstacle = false
			switchToFalling()
		}
	}
	
	func checkHitGround() {
		if hitGround {
			hitGround = false
			playerVelocity = CGPoint.zero
			player.zRotation = CGFloat(-90).degreesToRadians()
			player.position = CGPoint(x: player.position.x, y: playableStart + player.size.width / 2)
			runAction(hitGroundAction)
			switchToShowScore()
		}
	}
	
	// MARK: - Game States
	
	func switchToMainMenu() {
		gameState = .MainMenu
		setupBackground()
		setupForeground()
		setupPlayer()
		setupSombrero()
		setupMainMenu()
		setupPlayerAnimation()
	}
	
	func switchToTutorial() {
		gameState = .Tutorial
		setupBackground()
		setupForeground()
		setupPlayer()
		setupSombrero()
		setupLabel()
		setupTutorial()
		setupPlayerAnimation()
	}
	
	func switchToPlay() {
		gameState = .Play
		
		worldNode.enumerateChildNodesWithName("Tutorial", usingBlock: { node, stop in
			node.runAction(SKAction.sequence([
				SKAction.fadeOutWithDuration(0.5),
				SKAction.removeFromParent()
				]))
		})
		
		startSpawning()
		flapPlayer()
	}
	
	func switchToFalling() {
		gameState = .Falling
		
		let shake = SKAction.screenShakeWithNode(worldNode, amount: CGPoint(x: 0, y: 7.0), oscillations: 10, duration: 1.0)
		worldNode.runAction(shake)
		
		let whiteNode = SKSpriteNode(color: SKColor.whiteColor(), size: size)
		whiteNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
		whiteNode.zPosition = Layer.Flash.rawValue
		worldNode.addChild(whiteNode)
		whiteNode.runAction(SKAction.removeFromParentAfterDelay(0.01))
		
		runAction(SKAction.sequence([
			whackAction,
			SKAction.waitForDuration(0.1),
			fallingAction
			]))
		player.removeAllActions()
		stopSpawning()
	}
	
	func switchToShowScore() {
		gameState = .ShowingScore
		player.removeAllActions()
		stopSpawning()
		setupScorecard()
	}
	
	func switchToNewGame (gameState: GameState) {
		runAction(popAction)
		let newScene = GameScene(size: size, gameState: gameState)
		let transition = SKTransition.fadeWithColor(SKColor.blackColor(), duration: 0.5)
		view?.presentScene(newScene, transition: transition)
	}
	
	func switchToGameOver() {
		gameState = .Gameover
	}
	
	func flapPlayer() {
		runAction(flappingAction)
		playerVelocity = CGPointMake(0, kImpluse)
		
		playerAngularVelocity = kAngularVelocity.degreesToRadians()
		lastTouchTime = lastUpdateTime
		lastTouchY = player.position.y
		
		let moveUp = SKAction.moveByX(0, y: 12, duration: 0.15)
		moveUp.timingMode = .EaseInEaseOut
		let moveDown = moveUp.reversedAction()
		sombrero.runAction(SKAction.sequence([moveUp, moveDown]))
	}
	
	func createObstacle() -> SKSpriteNode {
		let sprite = SKSpriteNode(imageNamed: "Cactus")
		sprite.zPosition = Layer.Obstacle.rawValue
		sprite.userData = NSMutableDictionary()
		
		let offsetX = sprite.size.width * sprite.anchorPoint.x
		let offsetY = sprite.size.height * sprite.anchorPoint.y
		let path = CGPathCreateMutable()
		
		CGPathMoveToPoint(path, nil, 3 - offsetX, 0 - offsetY)
		CGPathAddLineToPoint(path, nil, 5 - offsetX, 309 - offsetY)
		CGPathAddLineToPoint(path, nil, 16 - offsetX, 315 - offsetY)
		CGPathAddLineToPoint(path, nil, 39 - offsetX, 315 - offsetY)
		CGPathAddLineToPoint(path, nil, 51 - offsetX, 306 - offsetY)
		CGPathAddLineToPoint(path, nil, 49 - offsetX, 1 - offsetY)
		
		CGPathCloseSubpath(path)
		
		sprite.physicsBody = SKPhysicsBody(polygonFromPath: path)
		sprite.physicsBody?.categoryBitMask = PhysicsCategory.Obstacle
		sprite.physicsBody?.collisionBitMask = 0
		sprite.physicsBody?.contactTestBitMask = PhysicsCategory.Player
		
		return sprite
	}
	
	func spawnObstacle() {
		let bottomObstacle = createObstacle()
		let startX = size.width + bottomObstacle.size.width / 2
		let bottomObstacleMin = playableStart - bottomObstacle.size.height / 2 + playableHeight * kBottomObstacleMinFraction
		let bottomObstacleMax = playableStart - bottomObstacle.size.height / 2 + playableHeight * kBottomObstacleMaxFraction
		
		bottomObstacle.position = CGPointMake(startX, CGFloat.random(min: bottomObstacleMin, max: bottomObstacleMax))
		bottomObstacle.name = "BottomObstacle"
		worldNode.addChild(bottomObstacle)
		
		let topObstacle = createObstacle()
		topObstacle.zPosition = CGFloat(180).degreesToRadians()
		topObstacle.position = CGPoint(x: startX, y: bottomObstacle.position.y + bottomObstacle.size.height / 2 + topObstacle.size.height / 2 + player.size.height * kGapMultiplier)
		topObstacle.name = "TopObstacle"
		worldNode.addChild(topObstacle)
		
		let moveX = size.width + topObstacle.size.width
		let moveDuration = moveX / kGroundSpeed
		let sequence = SKAction.sequence([
			SKAction.moveByX(-moveX, y: 0, duration: NSTimeInterval(moveDuration)),
			SKAction.removeFromParent()
		])
		topObstacle.runAction(sequence)
		bottomObstacle.runAction(sequence)
	}
	
	func startSpawning() {
		let firstDelay = SKAction.waitForDuration(1.75)
		let spawn = SKAction.runBlock(spawnObstacle)
		let everyDelay = SKAction.waitForDuration(1.5)
		
		let spawnSequence = SKAction.sequence([spawn, everyDelay])
		
		let foreverSpawn = SKAction.repeatActionForever(spawnSequence)
		let overallSequence = SKAction.sequence([firstDelay, foreverSpawn])
		
		runAction(overallSequence, withKey: "spawn")
	}
	
	func stopSpawning() {
		removeActionForKey("spawn")
		worldNode.enumerateChildNodesWithName("TopObstacle", usingBlock: { node, stop in
			node.removeAllActions()
		})
		worldNode.enumerateChildNodesWithName("BottomObstacle", usingBlock: { node, stop in
			node.removeAllActions()
		})
	}
	
	func bestScore() -> Int {
		return NSUserDefaults.standardUserDefaults().integerForKey("BestScore")
	}
	
	func setBestScore(bestScore: Int) {
		NSUserDefaults.standardUserDefaults().setInteger(bestScore, forKey: "BestScore")
		NSUserDefaults.standardUserDefaults().synchronize()
	}
	
	// MARK: - SKPhysicsContactDelegate
	
	func didBeginContact(contact: SKPhysicsContact) {
		let other = contact.bodyA.categoryBitMask == PhysicsCategory.Player ? contact.bodyB : contact.bodyA
		
		if other.categoryBitMask == PhysicsCategory.Ground {
			hitGround = true
		}
		if other.categoryBitMask == PhysicsCategory.Obstacle {
			hitObstacle = true
		}
	}
}
