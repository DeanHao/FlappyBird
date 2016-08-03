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
	case Foreground
	case Player
}

class GameScene: SKScene {
	let kGravity: CGFloat = -150.0 // 重力
	let kImpluse: CGFloat = 200 // 上升力
	let worldNode = SKNode()
	let player = SKSpriteNode(imageNamed: "Bird0")
	
	var playableStart: CGFloat = 0
	var playableHeight: CGFloat = 0
	var lastUpdateTime: NSTimeInterval = 0 // 上次 render 的时间
	var dt: NSTimeInterval = 0 // 两次 render 之间的时间差
	var playerVelocity = CGPoint.zero // 速度  变量类型为一个点
	
	let coinAction = SKAction.playSoundFileNamed("coin.wav", waitForCompletion: false)
	let dingAction = SKAction.playSoundFileNamed("ding.wav", waitForCompletion: false)
	let fallingAction = SKAction.playSoundFileNamed("falling.wav", waitForCompletion: false)
	let flappingAction = SKAction.playSoundFileNamed("flapping.wav", waitForCompletion: false)
	let hitGroundAction = SKAction.playSoundFileNamed("hitGround.wav", waitForCompletion: false)
	let popAction = SKAction.playSoundFileNamed("pop.wav", waitForCompletion: false)
	let whackAction = SKAction.playSoundFileNamed("whack.wav", waitForCompletion: false)
	
	override func didMoveToView(view: SKView) {
		addChild(worldNode)
		setupBackground()
		setupForeground()
		setupPlayer()
	}
	
	override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
		flapPlayer()
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
		updatePlayer()
	}
	
	func setupBackground() {
		let background = SKSpriteNode(imageNamed: "Background")
		background.anchorPoint = CGPointMake(0.5, 1)
		background.position = CGPointMake(size.width / 2.0, size.height)
		background.zPosition = Layer.Background.rawValue
		worldNode.addChild(background)
		
		playableStart = size.height - background.size.height
		playableHeight = background.size.height
	}
	
	func setupForeground() {
		let foreground = SKSpriteNode(imageNamed: "Ground")
		foreground.anchorPoint = CGPoint(x: 0, y: 1)
		foreground.position = CGPoint(x: 0, y: playableStart)
		foreground.zPosition = Layer.Foreground.rawValue
		worldNode.addChild(foreground)
	}
	
	func setupPlayer() {
		player.position = CGPointMake(size.width * 0.2, playableHeight * 0.4 + playableStart)
		player.zPosition = Layer.Player.rawValue
		
		worldNode.addChild(player)
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
	
	func flapPlayer() {
		runAction(flappingAction)
		playerVelocity = CGPointMake(0, kImpluse)
	}
}
