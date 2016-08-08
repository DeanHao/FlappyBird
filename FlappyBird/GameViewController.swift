//
//  GameViewController.swift
//  FlappyBird
//
//  Created by pmst on 15/10/4.
//  Copyright (c) 2015年 pmst. All rights reserved.
//

import UIKit
import SpriteKit

class GameViewController: UIViewController {
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
	}
	
	override func viewWillLayoutSubviews() {
		super.viewWillLayoutSubviews()
		
		if let skView = self.view as? SKView {
			if skView.scene == nil {
				let aspectRatio = skView.bounds.size.height / skView.bounds.size.width
				let scene = GameScene(size: CGSize(width: 320, height: 320 * aspectRatio), gameState: .MainMenu)
				
				skView.showsFPS = true
				skView.showsPhysics = true
				skView.showsNodeCount = true
				skView.ignoresSiblingOrder = true
				
				scene.scaleMode = .AspectFill
				
				skView.presentScene(scene)
			}
		}
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Release any cached data, images, etc that aren't in use.
	}
	
	override func prefersStatusBarHidden() -> Bool {
		return true
	}
}
