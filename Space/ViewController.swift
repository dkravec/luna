//
//  ViewController.swift
//  Lexi
//
//  Created by 46-1718 on 2019-12-01.
//  Copyright © 2019 NOVA Productions. All rights reserved.
//

import UIKit
import ARKit

class ViewController: UIViewController {
    
    //Main Page
    @IBOutlet weak var sceneView: ARSCNView!
   let configuration = ARWorldTrackingConfiguration()

    override func viewDidLoad() {
        super.viewDidLoad()
        //self.sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]
    self.sceneView.session.run(configuration)
        // Do any additional setup after loading the view.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    //dispose of any resources that can be recreated
    }
    
    
    
    //test (if i delete it, it gives a bunch of errors for me; i have no idea why)
    @IBAction func add(_ sender: Any) {
        let node = SCNNode()
            node.geometry = SCNBox(width: 0.07, height: 0.07, length: 0.07, chamferRadius: 0.07/2)
            node.geometry?.firstMaterial?.diffuse.contents = UIColor.red
        self.sceneView.scene.rootNode.addChildNode(node)
            node.position = SCNVector3(0,0,-0.3)
    }
    //test (if i delete it, it givea a bunch of errors for me; i have no idea why)

    
    
    
    @IBAction func addSS(_ sender: Any) {
        
       //Sun is Yellow
       let Sun = SCNNode()
            Sun.geometry = SCNBox(width: 0.2, height: 0.2, length: 0.2, chamferRadius: 0.2/2)
            Sun.geometry?.firstMaterial?.diffuse.contents = UIColor.yellow
        self.sceneView.scene.rootNode.addChildNode(Sun)
            Sun.position = SCNVector3(0,0,0)
        //Sun
        
        
        //Mercury is brown
        let Mercury = SCNNode()
            Mercury.geometry = SCNBox(width: 0.01, height: 0.01, length: 0.01, chamferRadius: 0.01/2)
            Mercury.geometry?.firstMaterial?.diffuse.contents = UIColor.brown
        self.sceneView.scene.rootNode.addChildNode(Mercury)
            Mercury.position = SCNVector3(0,0,-0.15)
        //Mercury
        
        
        //Venus is orange
            let Venus = SCNNode()
                Venus.geometry = SCNBox(width: 0.025, height: 0.025, length: 0.025, chamferRadius: 0.025/2)
                Venus.geometry?.firstMaterial?.diffuse.contents = UIColor.orange
        self.sceneView.scene.rootNode.addChildNode(Venus)
                Venus.position = SCNVector3(0,0,-0.19)
        //Venus
        
        
        //Earth is green
            let Earth = SCNNode()
                Earth.geometry = SCNBox(width: 0.02, height: 0.02, length: 0.02, chamferRadius: 0.02/2)
                Earth.geometry?.firstMaterial?.diffuse.contents = UIColor.green
        self.sceneView.scene.rootNode.addChildNode(Earth)
                Earth.position = SCNVector3(0,0,-0.24)
        //Earth
        
        
        //Moon is grey
            let Moon = SCNNode()
                Moon.geometry = SCNBox(width: 0.0025, height: 0.0025, length: 0.0025, chamferRadius: 0.0025/2)
                Moon.geometry?.firstMaterial?.diffuse.contents = UIColor.systemGray
            self.sceneView.scene.rootNode.addChildNode(Moon)
                Moon.position = SCNVector3(0.0107,0.0107,-0.2507)
        //Moon
        
        
        //Mars is Red
            let Mars = SCNNode()
                Mars.geometry = SCNBox(width: 0.015, height: 0.015, length: 0.015, chamferRadius: 0.015/2)
                Mars.geometry?.firstMaterial?.diffuse.contents = UIColor.red
        self.sceneView.scene.rootNode.addChildNode(Mars)
                Mars.position = SCNVector3(0,0,-0.30)
        //Mars
        
        
        
        //Jupiter is light red
            let Jupiter = SCNNode()
                Jupiter.geometry = SCNBox(width: 0.08, height: 0.08, length: 0.08, chamferRadius: 0.8/2)
                Jupiter.geometry?.firstMaterial?.diffuse.contents = UIColor.systemRed
        self.sceneView.scene.rootNode.addChildNode(Jupiter)
                Jupiter.position = SCNVector3(0,0,-0.40)
        //Jupiter
      
        
        
        //Saturn is beige
            let Saturn = SCNNode()
                Saturn.geometry = SCNBox(width: 0.07, height: 0.07, length: 0.07, chamferRadius: 0.07/2)
                Saturn.geometry?.firstMaterial?.diffuse.contents = UIColor.systemOrange
        self.sceneView.scene.rootNode.addChildNode(Saturn)
                     Saturn.position = SCNVector3(0,0,-0.50)
        //Saturn

        
        
        //Uranus is light blue
            let Uranus = SCNNode()
                Uranus.geometry = SCNBox(width: 0.05, height: 0.05, length: 0.05, chamferRadius: 0.05/2)
                Uranus.geometry?.firstMaterial?.diffuse.contents = UIColor.systemBlue
            self.sceneView.scene.rootNode.addChildNode(Uranus)
                         Uranus.position = SCNVector3(0,0,-0.57)
        //Uranus
        
        
        
        //Neptune is Blue
            let Neptune = SCNNode()
                Neptune.geometry = SCNBox(width: 0.03, height: 0.03, length: 0.03, chamferRadius: 0.03/2)
                Neptune.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
            self.sceneView.scene.rootNode.addChildNode(Neptune)
                Neptune.position = SCNVector3(0,0,-0.64)
        //Neptune
    }
}
    //Main Page
