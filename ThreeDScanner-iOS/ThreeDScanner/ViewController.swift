//
//  ViewController.swift
//  ThreeDScanner
//
//  Created by Steven Roach on 11/23/17.
//  Copyright © 2017 Steven Roach. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import GoogleAPIClientForREST
import GoogleSignIn

class ViewController: UIViewController, ARSCNViewDelegate, GIDSignInDelegate, GIDSignInUIDelegate {

    // MARK: - Properties
    
    @IBOutlet var sceneView: ARSCNView!
    var points: [vector_float3] = []
    var colors: [UIColor?] = []
    var pointsParentNode = SCNNode()
    var isTorchOn = false
    var addPointRatio = 1 // Show 1 / addPointRatio of the points
    var folderID = ""
    var hasFolderBeenUploaded = false
    var isMultipartUploadOn = false {
        didSet {
            if isMultipartUploadOn {
                uploadFolder()
            }
        }
    }
    let pendingImageUploadLabel: UILabel = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 21))
    var pendingImageUploads = 0 {
        didSet {
            pendingImageUploadLabel.text = "\(pendingImageUploads) pending uploads"
        }
    }

    // If modifying these scopes, delete your previously saved credentials by
    // resetting the iOS simulator or uninstall the app.
    private let scopes = ["https://www.googleapis.com/auth/drive"]
    private let service = GTLRDriveService()
    let signInButton = GIDSignInButton()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Configure Google Sign-in.
        GIDSignIn.sharedInstance().delegate = self
        GIDSignIn.sharedInstance().uiDelegate = self
        GIDSignIn.sharedInstance().scopes = scopes
        GIDSignIn.sharedInstance().signInSilently()
        
        // Add the sign-in button.
        view.addSubview(signInButton)
        
        addUploadButton()
        addToggleTorchButton()
        addInfoButton()
        addOptionsButton()
        addMultipartUploadSwitch()
        addPendingImageUploadLabel()
        
        sceneView.scene.rootNode.addChildNode(pointsParentNode)
    }
    
    internal func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        if let error = error {
            showAlert(title: "Authentication Error", message: error.localizedDescription)
            self.service.authorizer = nil
        } else {
            self.signInButton.isHidden = true
            self.service.authorizer = user.authentication.fetcherAuthorizer()
        }
    }
    
    // MARK: - UI
    
    private func addUploadButton() {
        let uploadButton = UIButton()
        view.addSubview(uploadButton)
        uploadButton.translatesAutoresizingMaskIntoConstraints = false
        uploadButton.setTitle("Upload All", for: .normal)
        uploadButton.setTitleColor(UIColor.red, for: .normal)
        uploadButton.backgroundColor = UIColor.white.withAlphaComponent(0.6)
        uploadButton.layer.cornerRadius = 4
        uploadButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        uploadButton.addTarget(self, action: #selector(uploadPointsTextFile(sender:)) , for: .touchUpInside)
        
        // Contraints
        uploadButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8.0).isActive = true
        uploadButton.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 0.0).isActive = true
        uploadButton.heightAnchor.constraint(equalToConstant: 50)
    }
    
    private func addToggleTorchButton() {
        let toggleTorchButton = UIButton()
        view.addSubview(toggleTorchButton)
        toggleTorchButton.translatesAutoresizingMaskIntoConstraints = false
        toggleTorchButton.setTitle("Torch", for: .normal)
        toggleTorchButton.setTitleColor(UIColor.red, for: .normal)
        toggleTorchButton.backgroundColor = UIColor.white.withAlphaComponent(0.6)
        toggleTorchButton.layer.cornerRadius = 4
        toggleTorchButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        toggleTorchButton.addTarget(self, action: #selector(toggleTorch(sender:)) , for: .touchUpInside)
        
        // Contraints
        toggleTorchButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8.0).isActive = true
        toggleTorchButton.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -8.0).isActive = true
        toggleTorchButton.heightAnchor.constraint(equalToConstant: 50)
    }
    
    private func addInfoButton() {
        let infoButton = UIButton()
        view.addSubview(infoButton)
        infoButton.translatesAutoresizingMaskIntoConstraints = false
        infoButton.setTitle("Info", for: .normal)
        infoButton.setTitleColor(UIColor.red, for: .normal)
        infoButton.backgroundColor = UIColor.white.withAlphaComponent(0.6)
        infoButton.layer.cornerRadius = 4
        infoButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        infoButton.addTarget(self, action: #selector(showInfoPopup(sender:)) , for: .touchUpInside)
        
        // Contraints
        infoButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 20.0).isActive = true
        infoButton.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -8.0).isActive = true
        infoButton.heightAnchor.constraint(equalToConstant: 50)
    }
    
    private func addOptionsButton() {
        let optionsButton = UIButton()
        view.addSubview(optionsButton)
        optionsButton.translatesAutoresizingMaskIntoConstraints = false
        optionsButton.setTitle("Options", for: .normal)
        optionsButton.setTitleColor(UIColor.red, for: .normal)
        optionsButton.backgroundColor = UIColor.white.withAlphaComponent(0.6)
        optionsButton.layer.cornerRadius = 4
        optionsButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        optionsButton.addTarget(self, action: #selector(showOptionsPopup(sender:)) , for: .touchUpInside)
        
        // Contraints
        optionsButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8.0).isActive = true
        optionsButton.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 8.0).isActive = true
        optionsButton.heightAnchor.constraint(equalToConstant: 50)
    }
    
    private func addMultipartUploadSwitch() {
        let multipartUploadSwitch = UISwitch()
        view.addSubview(multipartUploadSwitch)
        multipartUploadSwitch.translatesAutoresizingMaskIntoConstraints = false
        multipartUploadSwitch.isOn = isMultipartUploadOn
        multipartUploadSwitch.setOn(isMultipartUploadOn, animated: false)
        multipartUploadSwitch.addTarget(self, action: #selector(switchValueDidChange(sender:)), for: .valueChanged)
        
        // Contraints
        multipartUploadSwitch.topAnchor.constraint(equalTo: view.topAnchor, constant: 20.0).isActive = true
        multipartUploadSwitch.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 8.0).isActive = true
        multipartUploadSwitch.heightAnchor.constraint(equalToConstant: 50)
    }
    
    private func addPendingImageUploadLabel() {
        view.addSubview(pendingImageUploadLabel)
        pendingImageUploadLabel.translatesAutoresizingMaskIntoConstraints = false
        pendingImageUploadLabel.textAlignment = .center
        pendingImageUploadLabel.text = "\(pendingImageUploads) pending uploads"
        
        // Contraints
        pendingImageUploadLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 24.0).isActive = true
        pendingImageUploadLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 0.0).isActive = true
        pendingImageUploadLabel.heightAnchor.constraint(equalToConstant: 50)
    }
    
    // MARK: - UI Actions
    
    @IBAction func uploadPointsTextFile(sender: UIButton) {
        uploadFolder()
        
        let input = createXyzRgbString(points: points, pointColors: colors)
        uploadTextFile(input: input, name: "All_Points_and_Colors")
    }
    
    @IBAction func toggleTorch(sender: UIButton) {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video)
            else {return}
        
        if device.hasTorch {
            do {
                try device.lockForConfiguration()
                
                if !isTorchOn {
                    device.torchMode = .on
                    try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
                } else {
                    device.torchMode = .off
                }
                isTorchOn = !isTorchOn
                
                device.unlockForConfiguration()
            } catch {
                print("Torch could not be used")
            }
        } else {
            print("Torch is not available")
        }
    }
    
    @IBAction func showInfoPopup(sender: UIButton) {
        let title = "Info"
        let message = "Detected points are shown in yellow. Tap the screen to add currently detected ponts to the captured point cloud sample. Captured points are shown in white. Press Upload to upload a text file of the captured points to the associated Google Drive account."
        showAlert(title: title, message: message)
    }
    
    @IBAction func showOptionsPopup(sender: UIButton) {
        let alert = UIAlertController(title: "Adjust Add Point Ratio", message: "1 out of every _ points will be shown.", preferredStyle: UIAlertControllerStyle.alert)
        alert.addTextField(configurationHandler: {(textField: UITextField!) in
            textField.text = self.addPointRatio.description
            textField.keyboardType = UIKeyboardType.numberPad
        })
        
        alert.addAction(UIAlertAction(title: "Enter", style: UIAlertActionStyle.default, handler: { [weak alert] (_) in
            let textField = alert?.textFields![0] // Force unwrapping because we know it exists.
            if let text = textField!.text {
                if let newRatio = Int(text) {
                    self.addPointRatio = newRatio
                }
            }
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func switchValueDidChange(sender:UISwitch!) {
        if (sender.isOn){
            isMultipartUploadOn = true
        }
        else {
            isMultipartUploadOn = false
        }
    }
    
    // MARK: - Helper Functions
    
    private func uploadTextFile(input: String, name: String) {
        let fileData = input.data(using: .utf8)!
    
        let metadata = GTLRDrive_File()
        metadata.parents = [folderID]
        metadata.name = name + ".txt"
        
        let uploadParameters: GTLRUploadParameters = GTLRUploadParameters(data: fileData, mimeType: "text/plain")
        uploadParameters.shouldUploadWithSingleRequest = true
        
        let query = GTLRDriveQuery_FilesCreate.query(withObject: metadata, uploadParameters: uploadParameters)
        self.service.executeQuery(query, completionHandler: {(ticket:GTLRServiceTicket, object:Any?, error:Error?) in
            if error == nil {
                print("Text File Upload Success")
            }
            else {
                print("An error occurred: \(String(describing: error))")
                 self.showAlert(title: "Image Upload Error", message: "Make sure the folder has been uploaded successfully.")
            }
        })
    }
    
    private func uploadImageFile(image: UIImage, name: String) {
        
        let content = image
        let mimeType = "image/jpeg"
        
        let metadata = GTLRDrive_File()
        metadata.parents = [folderID]
        metadata.name = name + ".jpeg"
        
        guard let data = UIImagePNGRepresentation(content) else {
            return
        }
        
        let uploadParameters = GTLRUploadParameters(data: data, mimeType: mimeType)
        uploadParameters.shouldUploadWithSingleRequest = true

        let query = GTLRDriveQuery_FilesCreate.query(withObject: metadata, uploadParameters: uploadParameters)
        self.service.executeQuery(query, completionHandler: {(ticket:GTLRServiceTicket, object:Any?, error:Error?) in
            if error == nil {
                print("Image File Success")
            }
            else {
                print("An error occurred: \(String(describing: error))")
                self.showAlert(title: "Image Upload Error", message: "Make sure the folder has been uploaded successfully.")
            }
            self.pendingImageUploads -= 1
        })
    }
    
    private func uploadFolder() {
        if hasFolderBeenUploaded {
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = DateFormatter.Style.short
        dateFormatter.timeStyle = DateFormatter.Style.short
        let timeDateString = dateFormatter.string(from: Date())
        let name = timeDateString
        
        let metadata = GTLRDrive_File()
        metadata.name = name
        metadata.mimeType = "application/vnd.google-apps.folder"
        
        let query = GTLRDriveQuery_FilesCreate.query(withObject: metadata, uploadParameters: nil)
        self.service.executeQuery(query, completionHandler: {(ticket:GTLRServiceTicket, object: Any?, error:Error?) in
            if error == nil {
                let file = object as? GTLRDrive_File
                self.folderID = (file?.identifier)!
                self.hasFolderBeenUploaded = true
                print("Folder Upload Success")
                self.showAlert(title: "Folder Upload Success", message: "You may now tap to add images to the folder.")
            }
            else {
                print("An error occurred: \(String(describing: error))")
            }
        })
    }
    
    private func createXyzString(points: [float3]) -> String {
        var xyzString = "\n"
        for point in points {
            xyzString.append(point.x.description)
            xyzString.append(";")
            xyzString.append(point.y.description)
            xyzString.append(";")
            xyzString.append(point.z.description)
            xyzString.append("\n")
        }
        return xyzString
    }
    
    private func createXyzRgbString(points: [float3], pointColors: [UIColor?]) -> String {
        
        var xyzRgbString = "\n"
        for i in 0..<points.count {
            let point = points[i]
            let color = pointColors[i]
            
            xyzRgbString.append(point.x.description)
            xyzRgbString.append(";")
            xyzRgbString.append(point.y.description)
            xyzRgbString.append(";")
            xyzRgbString.append(point.z.description)
            xyzRgbString.append(";")
            
            if let pointColor = color {
                let ciColor = CIColor(color: pointColor)
                xyzRgbString.append((ciColor.red * 255).description)
                xyzRgbString.append(";")
                xyzRgbString.append((ciColor.green * 255).description)
                xyzRgbString.append(";")
                xyzRgbString.append((ciColor.blue * 255).description)
            } else {
                xyzRgbString += ";;"
            }
            xyzRgbString += "\n"
        }
        return xyzRgbString
    }
    
    private func capturePointColors(currentPoints: [float3]) -> [UIColor?] {
        
        var pointColors: [UIColor?] = []
        
        if let frame = sceneView.session.currentFrame {
            do {
                let capturedImageSampler = try CapturedImageSampler(frame: frame)
                
                for point in currentPoints {
                    let point2DPos = sceneView.projectPoint(SCNVector3(point))
                    if let pointColor = capturedImageSampler.getColor(atX: CGFloat(point2DPos.x) / sceneView.frame.maxX, y: CGFloat(point2DPos.y) / sceneView.frame.maxY) {
                        pointColors.append(pointColor)
                    } else {
                        pointColors.append(nil)
                    }
                }
                return pointColors
            } catch {
                print("Error")
                return pointColors
            }
        }
        return pointColors
    }
    
    private func projectPoint2DPositions(currentPoints: [float3]) -> [float3] {
        var point2DPositions: [float3] = []
        for point in currentPoints {
            var point2DPos = sceneView.projectPoint(SCNVector3(point))
            point2DPos.x /= Float(sceneView.frame.width)
            point2DPos.y /= Float(sceneView.frame.height)
            point2DPositions.append(float3(point2DPos))
        }
        return point2DPositions
    }
    
    // Helper for showing an alert
    private func showAlert(title : String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: UIAlertControllerStyle.alert
        )
        let ok = UIAlertAction(
            title: "OK",
            style: UIAlertActionStyle.default,
            handler: nil
        )
        alert.addAction(ok)
        present(alert, animated: true, completion: nil)
    }
    
    private func addPointToView(position: vector_float3) {
        let sphere = SCNSphere(radius: 0.00066)
        let sphereNode = SCNNode(geometry: sphere)
        sphereNode.position = SCNVector3(position)
        pointsParentNode.addChildNode(sphereNode)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = ARWorldTrackingConfiguration.PlaneDetection.horizontal

        // Run the view's session
        sceneView.session.run(configuration)
        
        // Show feature points
        sceneView.debugOptions.insert(ARSCNDebugOptions.showFeaturePoints)
        sceneView.debugOptions.insert(ARSCNDebugOptions.showWorldOrigin)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
        print("Memory Warning")
    }

    // MARK: - ARSCNViewDelegate
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let rawFeaturePoints = sceneView.session.currentFrame?.rawFeaturePoints else {
            return
        }
        let currentPoints = rawFeaturePoints.points
   
        if isMultipartUploadOn {
            uploadFolder() // Only uploads if folder hasn't been uploaded

            // Create corresponding file name for different types of uploads
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "H:m:ss:SSSS"
            let timeString = dateFormatter.string(from: Date())
            
            // Upload Image
//            let image = sceneView.snapshot()
            
            if let frame = sceneView.session.currentFrame {
                let imageWithCVPixelBuffer = frame.capturedImage
                let ciImage = CIImage(cvPixelBuffer: imageWithCVPixelBuffer)
                let tempContext = CIContext()
                let videoImage = tempContext.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: CGFloat(CVPixelBufferGetWidth(imageWithCVPixelBuffer)), height: CGFloat(CVPixelBufferGetHeight(imageWithCVPixelBuffer))))
                let image = UIImage(cgImage: videoImage!)
                // Slight lag, image uploading sideways? Could try supposedly faster method. Can CIImages be exported to jpeg?
                
                pendingImageUploads += 1
                uploadImageFile(image: image, name: "Photo_\(timeString)")
            }
            
            // Upload Points and Colors text file
            let pointColors = capturePointColors(currentPoints: currentPoints)
            colors += pointColors // add current colors to global list
            uploadTextFile(input: createXyzRgbString(points: currentPoints, pointColors: pointColors), name: "Points_and_Colors_\(timeString)")
            
            // Upload 2D point positions
            let point2DPositions = projectPoint2DPositions(currentPoints: currentPoints)
            uploadTextFile(input: createXyzString(points: point2DPositions), name: "2D_Point_Positions_\(timeString)")
            
            // Upload camera info text file
            let camera = sceneView.session.currentFrame?.camera
            let transform: String = "Transform: " + (camera?.transform.debugDescription)!
            let eulerAngles: String = "Euler Angles: " + (camera?.eulerAngles.debugDescription)!
            let intrinsics: String = "Intrinsics: " + (camera?.intrinsics.debugDescription)!
            uploadTextFile(input: transform + "\n" + eulerAngles + "\n" + intrinsics, name: "6DOF_\(timeString)")
        }
        
        // Display points
        var i = 0
        for rawPoint in currentPoints {
            if i % addPointRatio == 0 {
                addPointToView(position: rawPoint)
            }
            i += 1
        }
        points += rawFeaturePoints.points
    }
}
