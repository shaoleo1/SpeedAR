//
//  ViewController.swift
//  SpeedAR
//
//  Created by Leo Shao on 9/8/18.
//  Copyright © 2018 Leo Shao. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var statusTextView: UITextView!
    
    var box: Box!
    var status: String!
    var startPosition: SCNVector3!
    var distance: Float!
    var trackingState: ARCamera.TrackingState!
    enum Mode {
        case waitingForMeasuring
        case measuring
    }
    var mode: Mode = .waitingForMeasuring {
        didSet {
            switch mode {
            case .waitingForMeasuring:
                status = "NOT READY"
            case .measuring:
                box.update(
                    minExtents: SCNVector3Zero, maxExtents: SCNVector3Zero)
                box.isHidden = false
                startPosition = nil
                distance = 0.0
                setStatusText()
            }
        }
    }
    
    @IBAction func switchChanged(_ sender: UISwitch) {
        if sender.isOn {
            mode = .measuring
        } else {
            mode = .waitingForMeasuring
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        statusTextView.textContainerInset =
            UIEdgeInsetsMake(20.0, 10.0, 10.0, 0.0)
        
        box = Box()
        
        box.isHidden = true;
        
        sceneView.scene.rootNode.addChildNode(box)
        
        mode = .waitingForMeasuring
        
        distance = 0.0
        
        setStatusText()
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]
        
        configuration.planeDetection = .horizontal

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        trackingState = camera.trackingState
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    func setStatusText() {
        var text = "Status: \(status!)\n"
        text += "Tracking: \(getTrackingDescription())\n"
        text += "Distance: \(String(format:"%.2f cm", distance! * 100.0))"
        statusTextView.text = text
    }
    
    func getTrackingDescription() -> String {
        var description = ""
        if let t = trackingState {
            switch(t) {
            case .notAvailable:
                description = "TRACKING UNAVAILABLE"
            case .normal:
                description = "TRACKING NORMAL"
            case .limited(let reason):
                switch reason {
                case .excessiveMotion:
                    description =
                    "TRACKING LIMITED - Too much camera movement"
                case .insufficientFeatures:
                    description =
                    "TRACKING LIMITED - Not enough surface detail"
                case .initializing:
                    description = "INITIALIZING"
                case .relocalizing:
                    description = "RELOCALIZING"
                }
            }
        }
        return description
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // Call the method asynchronously to perform
        //  this heavy task without slowing down the UI
        DispatchQueue.main.async {
            self.measure()
            self.setStatusText()
        }
    }
    
    func measure() {
        let screenCenter : CGPoint = CGPoint(
            x: self.sceneView.bounds.midX, y: self.sceneView.bounds.midY)
        let planeTestResults = sceneView.hitTest(
            screenCenter, types: [.existingPlaneUsingExtent])
        if let result = planeTestResults.first {
            status = "READY"
            if mode == .measuring {
                status = "MEASURING"
                let worldPosition = SCNVector3Make(
                result.worldTransform.columns.3.x,
                result.worldTransform.columns.3.y,
                result.worldTransform.columns.3.z
                )
                if startPosition == nil {
                    startPosition = worldPosition
                    box.position = worldPosition
                }
                distance = calculateDistance(
                    from: startPosition!, to: worldPosition
                )
                print(distance)
                box.resizeTo(extent: distance)
                let angleInRadians = calculateAngleInRadians(
                    from: startPosition!, to: worldPosition
                )
                box.rotation = SCNVector4(x: 0, y: 1, z: 0,
                                          w: -(angleInRadians + Float.pi)
                )
            }
        } else {
            status = "NOT READY"
        }
    }
    
    func calculateDistance(from: SCNVector3, to: SCNVector3) -> Float {
        let x = from.x - to.x
        let y = from.y - to.y
        let z = from.z - to.z
        return sqrtf((x * x) + (y * y) + (z * z))
    }
    
    func calculateAngleInRadians(from: SCNVector3, to: SCNVector3) -> Float {
        let x = from.x - to.x
        let z = from.z - to.z
        return atan2(z, x)
    }
    
}
