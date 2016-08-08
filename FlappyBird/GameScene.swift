//
//  GameScene.swift
//  FlappyBird
//
//  Created by pmst on 15/10/4.
//  Copyright (c) 2015年 pmst. All rights reserved.
//

import SpriteKit

enum Layer: CGFloat {
	case Background
	case Obstacle
	case Foreground
	case Player
	case UI
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
	
	let coinAction = SKAction.playSoundFileNamed("coin.wav", waitForCompletion: false)
	let dingAction = SKAction.playSoundFileNamed("ding.wav", waitForCompletion: false)
	let fallingAction = SKAction.playSoundFileNamed("falling.wav", waitForCompletion: false)
	let flappingAction = SKAction.playSoundFileNamed("flapping.wav", waitForCompletion: false)
	let hitGroundAction = SKAction.playSoundFileNamed("hitGround.wav", waitForCompletion: false)
	let popAction = SKAction.playSoundFileNamed("pop.wav", waitForCompletion: false)
	let whackAction = SKAction.playSoundFileNamed("whack.wav", waitForCompletion: false)
	
	override func didMoveToView(view: SKView) {
		physicsWorld.gravity = CGVector(dx: 0, dy: 0)
		physicsWorld.contactDelegate = self
		
		addChild(worldNode)
		setupBackground()
		setupForeground()
		setupPlayer()
		setupSombrero()
		startSpawning()
		setupLabel()
		flapPlayer()
	}
	
	override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
		switch gameState {
		case .MainMenu:
			break
		case .Tutorial:
			break
		case .Play:
			flapPlayer()
		case .Falling:
			break
		case .ShowingScore:
			switchToNewGame()
			break
		case .Gameover:
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
		scorecard.position = CGPoint(x: size.width / 2, y: size.height / 2)
		scorecard.name = "Tutorial"
		scorecard.zPosition = Layer.UI.rawValue
		worldNode.addChild(scorecard)
		
		let lastScore = SKLabelNode(fontNamed: kFontName)
		lastScore.fontColor = SKColor(red: 101.0 / 255.0, green: 71.0 / 255.0, blue: 73.0 / 255.0, alpha: 1.0)
		lastScore.position = CGPoint(x: -scorecard.size.width * 0.25, y: -scorecard.size.height * 0.2)
		lastScore.text = "\(lastScore)"
		worldNode.addChild(lastScore)
		
		let bestScoreLabel = SKLabelNode(fontNamed: kFontName)
		bestScoreLabel.fontColor = SKColor(red: 101.0 / 255.0, green: 71.0 / 255.0, blue: 73.0 / 255.0, alpha: 1.0)
		bestScoreLabel.position = CGPoint(x: scorecard.size.width * 0.25, y: -scorecard.size.height * 0.2)
		bestScoreLabel.text = "\(self.bestScore())"
		worldNode.addChild(bestScoreLabel)
		
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
	
	func setupSombrero() {
		sombrero.position = CGPointMake(31 - sombrero.size.width / 2, 29 - sombrero.size.height / 2)
		player.addChild(sombrero)
	}
	
	func updatePlayer() {
		let gravity = CGPoint(x: 0, y: kGravity) // 设置 y方向上的加速度
		let gravityStep = gravity * CGFloat(dt)
		playerVelocity += gravityStep // player 的瞬时速度
		
		let velocityStep = playerVelocity * CGFloat(dt)
		player.position += velocityStep
		
		if player.position.y - player.size.height / 2 < playableStart {
			player.position = CGPoint(x: player.position.x, y: playableStart + player.size.height / 2) // player 静止在 playableStart
		}
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
					self.score += 1
					self.scoreLabel.text = "\(self.score)"
					self.runAction(self.coinAction)
					obstacle.userData?["Passed"] = NSNumber(bool: true)
				}
				
			}
		})
	}
	
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
	func switchToFalling() {
		gameState = .Falling
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
	
	func switchToNewGame () {
		runAction(popAction)
		let newScene = GameScene(size: size)
		let transition = SKTransition.fadeWithColor(SKColor.blackColor(), duration: 0.5)
		view?.presentScene(newScene, transition: transition)
	}
	
	func switchToGameOver() {
		gameState = .Gameover
	}
	
	func flapPlayer() {
		runAction(flappingAction)
		playerVelocity = CGPointMake(0, kImpluse)
		
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
	
	// MARK : - SKPhysicsContactDelegate
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
