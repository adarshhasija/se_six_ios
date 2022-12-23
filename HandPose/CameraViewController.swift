/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The app's main view controller object.
*/

import UIKit
import AVFoundation
import Vision
import FirebaseAnalytics

class CameraViewController: UIViewController {

    var isDeviceTooOld = false
    var isBrightnessTooLow = false
    var classifier : Any?
    var modelObservationsNeeded = 15
    var poseObservations = [VNHumanHandPoseObservation]()
    var poseObservations2 = [VNHumanHandPoseObservation]() //For a second hand (if applicable)
    var frameCounter = 0
    var contentToGet : Content? = nil
    var currentIndex = 0
    private var cameraView: CameraView { view as! CameraView }
    
    private let videoDataOutputQueue = DispatchQueue(label: "CameraFeedDataOutput", qos: .userInteractive)
    private var cameraFeedSession: AVCaptureSession?
    private var handPoseRequest = VNDetectHumanHandPoseRequest()
    
    @IBOutlet weak var topStackViewStoryboard: UIStackView!
    @IBOutlet weak var topInstructionLabel: UILabel!
    @IBOutlet weak var topLabel: UILabel!
    @IBOutlet weak var topButton: UIButton!
    @IBOutlet weak var ASLImageView: UIImageView!
    @IBOutlet weak var warningImageView: UIImageView!
    @IBOutlet weak var stackViewHandsNumber: UIStackView!
    @IBOutlet weak var labelHandsNumber: UILabel!
    
    
    @IBOutlet weak var middleStackViewHandDistance: UIStackView!
    @IBOutlet weak var middleStackViewNoHands: UIStackView!
    @IBOutlet weak var middleStackView: UIStackView!
    @IBOutlet weak var middleLabel: UILabel!
    @IBOutlet weak var middleButton: UIButton!
    
    
    @IBOutlet weak var bottomStackViewStoryboard: UIStackView!
    @IBOutlet weak var bottomLabel: UILabel!
    @IBOutlet weak var bottomImageView: UIImageView!
    
    
    private let tvTopBig = UITextView()
    private let tvTopBigTextSize : CGFloat = 50
    private let tvMiddleBig = UITextView()
    private let drawOverlay = CAShapeLayer()
    private let drawPath = UIBezierPath()
    private var evidenceBuffer = [HandGestureProcessor.PointsPair]()
    private var lastDrawPoint: CGPoint?
    private var isFirstSegment = true
    private var lastObservationTimestamp = Date()
    
    private var gestureProcessor = HandGestureProcessor()
    
    @objc func openContentTable(_: Any?) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let secondViewController = storyboard.instantiateViewController(withIdentifier: "ContentTable") as! ContentTableViewController
        let navBarOnModal: MyNavigationController = MyNavigationController(rootViewController: secondViewController)
        navBarOnModal.delegateCamera = self
        secondViewController.delegateCameraView = self
        secondViewController.currentSelectedContent = contentToGet
        self.present(navBarOnModal, animated: true, completion: nil)
    }
    
    @objc func showFingerspellingMessage(_: Any) {
        let alert = UIAlertController(title: "Fingerspelling", message: "We will be signing this word one character at a time", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true)
    }
    
    @objc func showWarning(_: Any) {
        var title = "Warning"
        var overallMessage = ""
        if isDeviceTooOld == true {
            overallMessage += "You are using an older device. This may impact the app's ability to recognize signs. This app works best on iPhone 11 and above."
        }
        if isDeviceTooOld == true && isBrightnessTooLow == true {
            title = "Warnings"
            overallMessage += "\n\n" //want it only if there are 2 messages. Else there will be too much white space
        }
        if isBrightnessTooLow == true {
            overallMessage += "Lighting is low. This may impact the app's ability to recognize signs."
        }
        let alert = UIAlertController(title: title, message: overallMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true)
    }
    
    @objc func showNumberOfHandsMessage(_: Any) {
        guard let content = contentToGet else {
            return
        }
        let title = "Note"
        let overallMessage = "This requires you to use " + String(content.maximumHandCount) + " hands. It is advisable to place your device on a surface horizontally and try the sign."
        let alert = UIAlertController(title: title, message: overallMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true)
    }
    
    @objc func cameraLayerTapped(_: Any?) {
        //shake the Show list button
        if contentToGet == nil {
            let midX = topButton.center.x
            let midY = topButton.center.y
            let animation = CABasicAnimation(keyPath: "position")
            animation.duration = 0.06
            animation.repeatCount = 4
            animation.autoreverses = true
            animation.fromValue = CGPoint(x: midX - 10, y: midY)
            animation.toValue = CGPoint(x: midX + 10, y: midY)
            topButton.layer.add(animation, forKey: "position")
        }
    }
    
    func toggleASLFingerspellingIconVisibility() {
        if contentToGet?.isFingerspelling == true {
            ASLImageView.isHidden = false
        }
        else {
            ASLImageView.isHidden = true
        }
    }
    
    func toggleWarningIconVisibility() {
        if isDeviceTooOld == false && isBrightnessTooLow == false {
            warningImageView.isHidden = true
        }
        else {
            warningImageView.isHidden = false
        }
    }
    
    @IBAction func settingsTapped(_ sender: Any) {
        let settingsUrl = URL(string: UIApplication.openSettingsURLString)!
        UIApplication.shared.open(settingsUrl)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        drawOverlay.frame = view.layer.bounds
        drawOverlay.lineWidth = 5
        drawOverlay.backgroundColor = #colorLiteral(red: 0.9999018312, green: 1, blue: 0.9998798966, alpha: 0.5).cgColor
        drawOverlay.strokeColor = #colorLiteral(red: 0.6, green: 0.1, blue: 0.3, alpha: 1).cgColor
        drawOverlay.fillColor = #colorLiteral(red: 0.9999018312, green: 1, blue: 0.9998798966, alpha: 0).cgColor
        drawOverlay.lineCap = .round
        view.layer.addSublayer(drawOverlay)
        // This sample app detects one hand only.
        handPoseRequest.maximumHandCount = 2
        // Add state change handler to hand gesture processor.
    /*    gestureProcessor.didChangeStateClosure = { [weak self] state in
            self?.handleGestureStateChange(state: state)
        }   */
        // Add double tap gesture recognizer for clearing the draw path.
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
        recognizer.numberOfTouchesRequired = 1
        recognizer.numberOfTapsRequired = 2
        view.addGestureRecognizer(recognizer)
        
     /*   let topStackView = UIStackView()
        topStackView.alignment = .leading
        topStackView.axis = .vertical
        topStackView.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        topStackView.frame = CGRect(x: 0, y: 75, width: view.frame.width, height: view.frame.height)
        let fGuesture = UITapGestureRecognizer(target: self, action: #selector(self.openModes(_:)))
        topStackView.addGestureRecognizer(fGuesture)
        topStackView.isUserInteractionEnabled = true
        topStackView.isMultipleTouchEnabled = true
        view.addSubview(topStackView)
        
        let index = textToGet.index(textToGet.startIndex, offsetBy: currentIndex)
        tvTopBig.text = String(textToGet[index])
        actionClassifier = try? ASL_J2s_1strain(configuration: MLModelConfiguration())
        tvTopBig.font = UIFont.systemFont(ofSize: tvTopBigTextSize)
        tvTopBig.sizeToFit()
        tvTopBig.textColor = .black
        tvTopBig.backgroundColor = .none
        tvTopBig.frame = CGRect(x: 0, y: 0, width: topStackView.frame.width - 50, height: topStackView.frame.height)
        tvTopBig.isUserInteractionEnabled = false
        topStackView.addSubview(tvTopBig)   */
        
        let fGuestureFingerspellingImage = UITapGestureRecognizer(target: self, action: #selector(self.showFingerspellingMessage(_:)))
        ASLImageView.isUserInteractionEnabled = true
        ASLImageView.addGestureRecognizer(fGuestureFingerspellingImage)
        
        let fGuestureWarningImage = UITapGestureRecognizer(target: self, action: #selector(self.showWarning(_:)))
        warningImageView.isUserInteractionEnabled = true
        warningImageView.addGestureRecognizer(fGuestureWarningImage)
        let fGuestureNumberOfHands = UITapGestureRecognizer(target: self, action: #selector(self.showNumberOfHandsMessage(_:)))
        stackViewHandsNumber.isUserInteractionEnabled = true
        stackViewHandsNumber.addGestureRecognizer(fGuestureNumberOfHands)
        
        topButton.addTarget(self, action: #selector(self.openContentTable(_:)), for: .touchUpInside)
        let fGuesture = UITapGestureRecognizer(target: self, action: #selector(self.openContentTable(_:)))
        topStackViewStoryboard.addGestureRecognizer(fGuesture)
        topStackViewStoryboard.isUserInteractionEnabled = true
        topStackViewStoryboard.isMultipleTouchEnabled = true
        bottomLabel.font = UIFont(name: "Georgia", size: tvTopBigTextSize + 25)
        resetSetup()
        
        tvMiddleBig.text = "👍"  //"✓" //"✔"
        tvMiddleBig.font = UIFont.systemFont(ofSize: 150) //setup thumbs up above as the size adjusts properly
        tvMiddleBig.sizeToFit()
        tvMiddleBig.textColor = .green
        tvMiddleBig.backgroundColor = .none
        tvMiddleBig.center = view.center
        tvMiddleBig.isHidden = true
        view.addSubview(tvMiddleBig)
        
        topInstructionLabel.text = "Pick a word from our list and try signing it"
        topLabel.isHidden = true
        topButton.titleLabel?.text = "Show List"
        bottomImageView.isHidden = true
        
        let modelIdentified = modelIdentifier().components(separatedBy: ",")
        if modelIdentified.isEmpty == false {
            let firstHalf = modelIdentified[0]
            if let number = Int(firstHalf.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                //iPhone 11 and above
                //number given here is always the public model number + 1
                //iPhone 12 = modelIdentified 13
                if number < 12 {
                    isDeviceTooOld = true
                    toggleWarningIconVisibility()
                }
            }
        }
        
    }
    
    func modelIdentifier() -> String {
        if let simulatorModelIdentifier = ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] { return simulatorModelIdentifier }
        var sysinfo = utsname()
        uname(&sysinfo) // ignore return value
        return String(bytes: Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN)), encoding: .ascii)!.trimmingCharacters(in: .controlCharacters)
    }
    

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        do {
            if cameraFeedSession == nil {
                cameraView.previewLayer.videoGravity = .resizeAspectFill
                try setupAVSession()
                cameraView.previewLayer.session = cameraFeedSession
                
                let fGuesture = UITapGestureRecognizer(target: self, action: #selector(self.cameraLayerTapped(_:)))
                cameraView.addGestureRecognizer(fGuesture)
                cameraView.isUserInteractionEnabled = true
                cameraView.isMultipleTouchEnabled = true
                
                let swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(self.openContentTable(_:)))
                    swipeUp.direction = .up
                    cameraView.addGestureRecognizer(swipeUp)
            }
            cameraFeedSession?.startRunning()
        } catch {
            AppError.display(error, inViewController: self)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        cameraFeedSession?.stopRunning()
        super.viewWillDisappear(animated)
    }
    
    func setupAVSession() throws {
        // Select a front facing camera, make an input.
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw AppError.captureSessionSetup(reason: "Could not find a front facing camera.")
        }
        
        guard let deviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            //throw AppError.captureSessionSetup(reason: "Could not create video device input.")
            cameraPermissionFailUI()
            return
        }
        
        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = AVCaptureSession.Preset.high
        
        // Add a video input.
        guard session.canAddInput(deviceInput) else {
            throw AppError.captureSessionSetup(reason: "Could not add video device input to the session")
        }
        session.addInput(deviceInput)
        
        let dataOutput = AVCaptureVideoDataOutput()
        if session.canAddOutput(dataOutput) {
            session.addOutput(dataOutput)
            // Add a video data output.
            dataOutput.alwaysDiscardsLateVideoFrames = true
            dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            dataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        } else {
            throw AppError.captureSessionSetup(reason: "Could not add video data output to the session")
        }
        session.commitConfiguration()
        cameraFeedSession = session
}
    
    func processPoints(thumbTip: CGPoint?, indexTip: CGPoint?) {
        // Check that we have both points.
        guard let thumbPoint = thumbTip, let indexPoint = indexTip else {
            // If there were no observations for more than 2 seconds reset gesture processor.
            if Date().timeIntervalSince(lastObservationTimestamp) > 2 {
                gestureProcessor.reset()
            }
            cameraView.showPoints([], color: .clear)
            return
        }
        
        // Convert points from AVFoundation coordinates to UIKit coordinates.
        let previewLayer = cameraView.previewLayer
        let thumbPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: thumbPoint)
        let indexPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: indexPoint)
        
        // Process new points
        gestureProcessor.processPointsPair((thumbPointConverted, indexPointConverted))
    }
    
    private func handleGestureStateChange(state: HandGestureProcessor.State) {
        let pointsPair = gestureProcessor.lastProcessedPointsPair
        var tipsColor: UIColor
        switch state {
        case .possiblePinch, .possibleApart:
            // We are in one of the "possible": states, meaning there is not enough evidence yet to determine
            // if we want to draw or not. For now, collect points in the evidence buffer, so we can add them
            // to a drawing path when required.
            evidenceBuffer.append(pointsPair)
            tipsColor = .orange
        case .pinched:
            // We have enough evidence to draw. Draw the points collected in the evidence buffer, if any.
            for bufferedPoints in evidenceBuffer {
                updatePath(with: bufferedPoints, isLastPointsPair: false)
            }
            // Clear the evidence buffer.
            evidenceBuffer.removeAll()
            // Finally, draw the current point.
            updatePath(with: pointsPair, isLastPointsPair: false)
            tipsColor = .green
        case .apart, .unknown:
            // We have enough evidence to not draw. Discard any evidence buffer points.
            evidenceBuffer.removeAll()
            // And draw the last segment of our draw path.
            updatePath(with: pointsPair, isLastPointsPair: true)
            tipsColor = .red
        }
        cameraView.showPoints([pointsPair.thumbTip, pointsPair.indexTip], color: tipsColor)
    }
    
    private func updatePath(with points: HandGestureProcessor.PointsPair, isLastPointsPair: Bool) {
        // Get the mid point between the tips.
        let (thumbTip, indexTip) = points
        let drawPoint = CGPoint.midPoint(p1: thumbTip, p2: indexTip)

        if isLastPointsPair {
            if let lastPoint = lastDrawPoint {
                // Add a straight line from the last midpoint to the end of the stroke.
                drawPath.addLine(to: lastPoint)
            }
            // We are done drawing, so reset the last draw point.
            lastDrawPoint = nil
        } else {
            if lastDrawPoint == nil {
                // This is the beginning of the stroke.
                drawPath.move(to: drawPoint)
                isFirstSegment = true
            } else {
                let lastPoint = lastDrawPoint!
                // Get the midpoint between the last draw point and the new point.
                let midPoint = CGPoint.midPoint(p1: lastPoint, p2: drawPoint)
                if isFirstSegment {
                    // If it's the first segment of the stroke, draw a line to the midpoint.
                    drawPath.addLine(to: midPoint)
                    isFirstSegment = false
                } else {
                    // Otherwise, draw a curve to a midpoint using the last draw point as a control point.
                    drawPath.addQuadCurve(to: midPoint, controlPoint: lastPoint)
                }
            }
            // Remember the last draw point for the next update pass.
            lastDrawPoint = drawPoint
        }
        // Update the path on the overlay layer.
        drawOverlay.path = drawPath.cgPath
    }
    
    @IBAction func handleGesture(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else {
            return
        }
        evidenceBuffer.removeAll()
        drawPath.removeAllPoints()
        drawOverlay.path = drawPath.cgPath
    }
    
    func prepareInputWithObservations(_ observations: [VNHumanHandPoseObservation]) -> MLMultiArray? {
        let numAvailableFrames = observations.count
        let observationsNeeded = modelObservationsNeeded
        var multiArrayBuffer = [MLMultiArray]()

        for frameIndex in 0 ..< min(numAvailableFrames, observationsNeeded) {
            let pose = observations[frameIndex]
            do {
                let oneFrameMultiArray = try pose.keypointsMultiArray()
                multiArrayBuffer.append(oneFrameMultiArray)
            } catch {
                continue
            }
        }
        
        // If poseWindow does not have enough frames (45) yet, we need to pad 0s
        if numAvailableFrames < observationsNeeded {
            for _ in 0 ..< (observationsNeeded - numAvailableFrames) {
                do {
                    let oneFrameMultiArray = try MLMultiArray(shape: [1, 3, 21], dataType: .double)
                    try resetMultiArray(oneFrameMultiArray)
                    multiArrayBuffer.append(oneFrameMultiArray)
                } catch {
                    continue
                }
            }
        }
        return MLMultiArray(concatenating: [MLMultiArray](multiArrayBuffer), axis: 0, dataType: .float)
    }
    
    func resetMultiArray(_ predictionWindow: MLMultiArray, with value: Double = 0.0) throws {
        let pointer = try UnsafeMutableBufferPointer<Double>(predictionWindow)
        pointer.initialize(repeating: value)
    }
    
    private func animateSignResult(letter : String?) {
        if letter != nil {
            self.tvMiddleBig.text = letter
        }
        else if contentToGet != nil {
            self.tvMiddleBig.text = "✓"
           /* if currentIndex >= contentToGet!.text.count {
                self.tvMiddleBig.text = "👍"
            }
            else {
                self.tvMiddleBig.text = "✓"
            }   */
        }
        self.tvMiddleBig.isHidden = false
        self.tvMiddleBig.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        UIView.animate(withDuration: 1.0,
                       delay: 0,
                       usingSpringWithDamping: 0.2,
                       initialSpringVelocity: 6.0,
                       options: .allowUserInteraction,
                       animations: { [weak self] in
                        self?.tvMiddleBig.transform = .identity
            },
                       completion: { _ in
                           self.tvMiddleBig.isHidden = true
                       })
    }
    
    private func cameraPermissionSuccessUI() {
        self.topStackViewStoryboard.isHidden = false
        self.middleStackView.isHidden = true
        self.bottomStackViewStoryboard.isHidden = false
    }
    
    private func cameraPermissionFailUI() {
        self.topStackViewStoryboard.isHidden = true
        self.middleStackView.isHidden = false
        self.bottomStackViewStoryboard.isHidden = true
    }
    
    func getBrightness(sampleBuffer: CMSampleBuffer) -> Double {
        let rawMetadata = CMCopyDictionaryOfAttachments(allocator: nil, target: sampleBuffer, attachmentMode: CMAttachmentMode(kCMAttachmentMode_ShouldPropagate))
        let metadata = CFDictionaryCreateMutableCopy(nil, 0, rawMetadata) as NSMutableDictionary
        let exifData = metadata.value(forKey: "{Exif}") as? NSMutableDictionary
        let brightnessValue : Double = exifData?[kCGImagePropertyExifBrightnessValue as String] as! Double
        return brightnessValue
    }
    
    func toggleWarningIconAnimation(fadeIn : Bool) {
        if fadeIn == true {
            //fade in
            DispatchQueue.main.sync {
                warningImageView.alpha = 0.0
                UIView.animate(withDuration: 0.5, animations: {
                    self.warningImageView.alpha = 1.0
                })
            }
            
        }
        else {
            //fade out
            DispatchQueue.main.sync {
                warningImageView.alpha = 1.0
                UIView.animate(withDuration: 0.5, animations: {
                    self.warningImageView.alpha = 0.0
                })
            }
            
        }
    }
    
    private func analyticsLogListItemRecognized(item: String) {
        Analytics.logEvent("se6_ios_listitem_recognized", parameters: [
            "item_name" : item
        ])
    }
    
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        var thumbTip: CGPoint?
        var indexTip: CGPoint?
        var middleTip: CGPoint?
        var ringTip : CGPoint?
        var littleTip : CGPoint?
        
      /*  defer {
            DispatchQueue.main.sync {
                self.processPoints(thumbTip: thumbTip, indexTip: indexTip)
            }
        }   */
        
        if AVCaptureDevice.authorizationStatus(for: .video) != .authorized {
            //not authorized
            DispatchQueue.main.sync {
                cameraPermissionFailUI()
            }
            return
        }
        else {
            DispatchQueue.main.sync {
                cameraPermissionSuccessUI()
            }
        }

        let brightness = getBrightness(sampleBuffer: sampleBuffer)
        if brightness > 0 {
            //high brightness, warning should not be visible
            isBrightnessTooLow = false
            DispatchQueue.main.sync {
                toggleWarningIconVisibility()
            }
            //toggleWarningIconAnimation(fadeIn: false)
        }
        else {
            //low brightness, warning should be visible
            isBrightnessTooLow = true
            DispatchQueue.main.sync {
                toggleWarningIconVisibility()
            }
            //toggleWarningIconAnimation(fadeIn: true)
        }

        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
        do {
            // Perform VNDetectHumanHandPoseRequest
            try handler.perform([handPoseRequest])
            // Continue only when a hand was detected in the frame.
            // Since we set the maximumHandCount property of the request to 1, there will be at most one observation.
            guard let observation = handPoseRequest.results?.first else {
                if classifier != nil {
                 /*   DispatchQueue.main.sync {
                        middleStackViewNoHands.isHidden = false
                    }   */ //Not working well for WHERE
                }
                
                return
            }
            //By now we know results is not null
            let observation2 = handPoseRequest.results!.count > 1 ? handPoseRequest.results?.last : nil
            // Get points for thumb and index finger.
            let thumbPoints = try observation.recognizedPoints(.thumb)
            let indexFingerPoints = try observation.recognizedPoints(.indexFinger)
            let middleFingerPoints = try observation.recognizedPoints(.middleFinger)
            let ringFingerPoints = try observation.recognizedPoints(.ringFinger)
            let littleFingerPoints = try observation.recognizedPoints(.littleFinger)
            // Look for tip points.
            guard let thumbTipPoint = thumbPoints[.thumbTip],
                    let indexTipPoint = indexFingerPoints[.indexTip],
                    let middleTipPoint = middleFingerPoints[.middleTip],
                    let ringTipPoint = ringFingerPoints[.ringTip],
                    let littleTipPoint = littleFingerPoints[.littleTip]
            else {
                return
            }
            
            // Ignore low confidence points.
            guard thumbTipPoint.confidence > 0.3
                    && indexTipPoint.confidence > 0.3
                    && middleTipPoint.confidence > 0.3
                    && ringTipPoint.confidence > 0.3
                    && littleTipPoint.confidence > 0.3
            else {
                //Not working too well. Need more time on this
              /*  DispatchQueue.main.sync {
                    middleStackViewHandDistance.isHidden = false
                }   */
                return
            }
          /*  DispatchQueue.main.sync {
                middleStackViewNoHands.isHidden = true
            }   */ //Not working well for WHERE
         /*   DispatchQueue.main.sync {
                middleStackViewHandDistance.isHidden = true
            }   */ //Not working too well. Need more time on this
            
            // Convert points from Vision coordinates to AVFoundation coordinates.
            thumbTip = CGPoint(x: thumbTipPoint.location.x, y: 1 - thumbTipPoint.location.y)
            indexTip = CGPoint(x: indexTipPoint.location.x, y: 1 - indexTipPoint.location.y)
            middleTip = CGPoint(x: middleTipPoint.location.x, y: 1 - middleTipPoint.location.y)
            ringTip = CGPoint(x: ringTipPoint.location.x, y: 1 - ringTipPoint.location.y)
            littleTip = CGPoint(x: littleTipPoint.location.x, y: 1 - littleTipPoint.location.y)

            //Hand Pose Classifier
            guard let text = contentToGet?.text else {
                //This is for free text mode. Used for testing purposes
              /*  guard let keypointsMultiArray = try? observation.keypointsMultiArray() else { fatalError() }
                            let handPosePrediction = try (classifier as? ISL_0TO9_10)?.prediction(poses: keypointsMultiArray)
                if handPosePrediction != nil {
                    let confidence = handPosePrediction?.labelProbabilities[handPosePrediction!.label]!
                    if confidence != nil && confidence! > 0.8 {
                        print("******** "+handPosePrediction!.label+" *****************")
                        if handPosePrediction!.label.uppercased() != "BACKGROUND"
                            && handPosePrediction!.label.uppercased() != "OPEN"
                            && handPosePrediction!.label.uppercased() != "TRANSITION" {
                            processPrediction(label: handPosePrediction!.label.capitalized)
                        }
                        return
                    }
                }   */
                return
            }
            if contentToGet?.isFingerspelling == false && contentToGet?.isPose == false {
                //Hand Action Classifier
                frameCounter += 1
                if frameCounter % 2 == 0 {
                    //Its coming in as 60 fps. We want 30 fps
                    return
                }
                if poseObservations.count >= modelObservationsNeeded {
                    poseObservations.removeFirst()
                }
                poseObservations.append(observation)
                let posesMultiArray = prepareInputWithObservations(poseObservations)
                var posesMultiArray2 : MLMultiArray?
                if observation2 != nil {
                    if poseObservations2.count >= modelObservationsNeeded {
                        poseObservations2.removeFirst()
                    }
                    poseObservations2.append(observation2!)
                    posesMultiArray2 = prepareInputWithObservations(poseObservations2)
                }
                
                if text.uppercased() == "BATHROOM" {
                    guard let predictions = try? (classifier as? ASL_Bathroom_0_5strain)?.prediction(poses: posesMultiArray!) else { return }
                    print(predictions.label.capitalized)
                    if predictions.label.uppercased() == text.uppercased() {
                        processPrediction(label: predictions.label.capitalized)
                    }
                }
                else if text.uppercased() == "YES" {
                    guard let predictions = try? (classifier as? ASL_Yes_0_5strain)?.prediction(poses: posesMultiArray!) else { return }
                    print(predictions.label.capitalized)
                    if predictions.label.uppercased() == text.uppercased() {
                        processPrediction(label: predictions.label.capitalized)
                    }
                }
                else if text.uppercased() == "NO" {
                    guard let predictions = try? (classifier as? ASL_No_0_5strain)?.prediction(poses: posesMultiArray!) else { return }
                    print(predictions.label.capitalized)
                    if predictions.label.uppercased() == text.uppercased() {
                        processPrediction(label: predictions.label.capitalized)
                    }
                }
                else if text.uppercased() == "TEACHER" {
                    guard let predictions = try? (classifier as? ASL_Teacher_1_5strain)?.prediction(poses: posesMultiArray!) else { return }
                    print("HAND 1: " + predictions.label.capitalized)
                    if predictions.label.uppercased() == text.uppercased() {
                        if posesMultiArray2 != nil {
                            guard let predictions2 = try? (classifier as? ASL_Teacher_1_5strain)?.prediction(poses: posesMultiArray2!) else { return }
                            print("HAND 2: " + predictions2.label.capitalized)
                            if predictions2.label.uppercased() == text.uppercased() {
                                processPrediction(label: predictions2.label.capitalized)
                            }
                        }
                        
                    }
                }
                else if text.uppercased() == "JUDGE" {
                    guard let predictions = try? (classifier as? ASL_Judge2_1strain)?.prediction(poses: posesMultiArray!) else { return }
                    print("HAND 1: " + predictions.label.capitalized)
                    if predictions.label.uppercased() == text.uppercased() {
                        if posesMultiArray2 != nil {
                            guard let predictions2 = try? (classifier as? ASL_Judge2_1strain)?.prediction(poses: posesMultiArray2!) else { return }
                            print("HAND 2: " + predictions2.label.capitalized)
                            if predictions2.label.uppercased() == text.uppercased() {
                                processPrediction(label: predictions2.label.capitalized)
                            }
                        }
                        
                    }
                }
                else if text.uppercased() == "THANKSGIVING" {
                    guard let predictions = try? (classifier as? ASL_ThanksgivingTurkey2_1strain)?.prediction(poses: posesMultiArray!) else { return }
                    print(predictions.label.capitalized)
                    if predictions.label.uppercased() == text.uppercased() {
                        processPrediction(label: predictions.label.capitalized)
                    }
                }
                else if text.uppercased() == "HALLOWEEN" {
                    guard let predictions = try? (classifier as? ASL_Halloween2_1strain)?.prediction(poses: posesMultiArray!) else { return }
                    print("HAND 1: " + predictions.label.capitalized)
                    if predictions.label.uppercased() == text.uppercased() {
                        if posesMultiArray2 != nil {
                            guard let predictions2 = try? (classifier as? ASL_Halloween2_1strain)?.prediction(poses: posesMultiArray2!) else { return }
                            print("HAND 2: " + predictions2.label.capitalized)
                            if predictions2.label.uppercased() == text.uppercased() {
                                processPrediction(label: predictions2.label.capitalized)
                            }
                        }
                        
                    }
                }
                else if text.uppercased() == "SOCCER" && contentToGet?.signLangType == Content.SignLanguageType.ASL {
                    guard let predictions = try? (classifier as? ASL_Soccer1_1strain)?.prediction(poses: posesMultiArray!) else { return }
                    print("HAND 1: " + predictions.label.capitalized)
                    if predictions.label.uppercased() == text.uppercased() {
                        if posesMultiArray2 != nil {
                            guard let predictions2 = try? (classifier as? ASL_Soccer1_1strain)?.prediction(poses: posesMultiArray2!) else { return }
                            print("HAND 2: " + predictions2.label.capitalized)
                            if predictions2.label.uppercased() == text.uppercased() {
                                processPrediction(label: predictions2.label.capitalized)
                            }
                        }
                        
                    }
                }
                else if text.uppercased() == "SOCCER" && contentToGet?.signLangType == Content.SignLanguageType.ISL {
                    guard let predictions = try? (classifier as? ISL_Soccer_2strain)?.prediction(poses: posesMultiArray!) else { return }
                    print("HAND 1: " + predictions.label.capitalized)
                    if predictions.label.uppercased() == text.uppercased() {
                        if posesMultiArray2 != nil {
                            guard let predictions2 = try? (classifier as? ISL_Soccer_2strain)?.prediction(poses: posesMultiArray2!) else { return }
                            print("HAND 2: " + predictions2.label.capitalized)
                            if predictions2.label.uppercased() == text.uppercased() {
                                processPrediction(label: predictions2.label.capitalized)
                            }
                        }
                        
                    }
                }
                else if text.uppercased() == "AMBULANCE" {
                    guard let predictions = try? (classifier as? ASL_Ambulance_1strain)?.prediction(poses: posesMultiArray!) else { return }
                    print(predictions.label.capitalized)
                    if predictions.label.uppercased() == text.uppercased() {
                        processPrediction(label: predictions.label.capitalized)
                    }
                }
                else if text.uppercased() == "EASTER" {
                    guard let predictions = try? (classifier as? ASL_Easter_1strain)?.prediction(poses: posesMultiArray!) else { return }
                    print("HAND 1: " + predictions.label.capitalized)
                    if predictions.label.uppercased() == text.uppercased() {
                        if posesMultiArray2 != nil {
                            guard let predictions2 = try? (classifier as? ASL_Easter_1strain)?.prediction(poses: posesMultiArray2!) else { return }
                            print("HAND 2: " + predictions2.label.capitalized)
                            if predictions2.label.uppercased() == text.uppercased() {
                                processPrediction(label: predictions2.label.capitalized)
                            }
                        }
                        
                    }
                }
                else if text.uppercased() == "CELEBRATE" {
                    guard let predictions = try? (classifier as? ASL_Celebrate)?.prediction(poses: posesMultiArray!) else { return }
                    print("HAND 1: " + predictions.label.capitalized)
                    if predictions.label.uppercased() == text.uppercased() {
                        if posesMultiArray2 != nil {
                            guard let predictions2 = try? (classifier as? ASL_Celebrate)?.prediction(poses: posesMultiArray2!) else { return }
                            print("HAND 2: " + predictions2.label.capitalized)
                            if predictions2.label.uppercased() == text.uppercased() {
                                processPrediction(label: predictions2.label.capitalized)
                            }
                        }
                        
                    }
                }
                else if text.uppercased() == "TENNIS" {
                    guard let predictions = try? (classifier as? ASL_Tennis2_1_5strain)?.prediction(poses: posesMultiArray!) else { return }
                    print(predictions.label.capitalized)
                    if predictions.label.uppercased() == text.uppercased() {
                        processPrediction(label: predictions.label.capitalized)
                    }
                }
                else if text.uppercased() == "FIRE" {
                    guard let predictions = try? (classifier as? ASL_Fire_1strain)?.prediction(poses: posesMultiArray!) else { return }
                    print("HAND 1: " + predictions.label.capitalized)
                    if predictions.label.uppercased() == text.uppercased() {
                        if posesMultiArray2 != nil {
                            guard let predictions2 = try? (classifier as? ASL_Fire_1strain)?.prediction(poses: posesMultiArray2!) else { return }
                            print("HAND 2: " + predictions2.label.capitalized)
                            if predictions2.label.uppercased() == text.uppercased() {
                                processPrediction(label: predictions2.label.capitalized)
                            }
                        }
                        
                    }
                }
                else if text.uppercased() == "LATER" {
                    guard let predictions = try? (classifier as? ASL_Later_0_5strain)?.prediction(poses: posesMultiArray!) else { return }
                    print(predictions.label.capitalized)
                    if predictions.label.uppercased() == text.uppercased() {
                        processPrediction(label: predictions.label.capitalized)
                    }
                }
                else if text.uppercased() == "WHERE" {
                    guard let predictions = try? (classifier as? ASL_Where_0_5strain)?.prediction(poses: posesMultiArray!) else { return }
                    print(predictions.label.capitalized)
                    if predictions.label.uppercased() == text.uppercased() {
                        processPrediction(label: predictions.label.capitalized)
                    }
                }
                else if text.uppercased() == "MILK" {
                    guard let predictions = try? (classifier as? ASL_Milk_0_5strain)?.prediction(poses: posesMultiArray!) else { return }
                    print(predictions.label.capitalized)
                    if predictions.label.uppercased() == text.uppercased() {
                        processPrediction(label: predictions.label.capitalized)
                    }
                }
                else if text.uppercased() == "GOODBYE" {
                    guard let predictions = try? (classifier as? ASL_Goodbye_0_5strain)?.prediction(poses: posesMultiArray!) else { return }
                    print(predictions.label.capitalized)
                    if predictions.label.uppercased() == text.uppercased() {
                        processPrediction(label: predictions.label.capitalized)
                    }
                }
                else if text.uppercased() == "WHICH" {
                    guard let predictions = try? (classifier as? ASL_Which)?.prediction(poses: posesMultiArray!) else { return }
                    print(predictions.label.capitalized)
                    if predictions.label.uppercased() == text.uppercased() {
                        processPrediction(label: predictions.label.capitalized)
                    }
                }
                else if text.uppercased() == "YOURWELCOME" {
                    guard let predictions = try? (classifier as? ASL_YourWelcome2_0_5strain)?.prediction(poses: posesMultiArray!) else { return }
                    print(predictions.label.capitalized)
                    if predictions.label.uppercased() == text.uppercased() {
                        processPrediction(label: predictions.label.capitalized)
                    }
                }
                else if text.uppercased() == "CHRISTMAS" {
                    guard let predictions = try? (classifier as? ASL_Christmas3_1strain)?.prediction(poses: posesMultiArray!) else { return }
                    print(predictions.label.capitalized)
                    if predictions.label.uppercased() == text.uppercased() {
                        processPrediction(label: predictions.label.capitalized)
                    }
                }
                return
            }
            if contentToGet?.isFingerspelling == false && contentToGet?.isPose == true {
                if text.uppercased() == "I LOVE YOU" {
                    print("Looking for pose: " + String("I LOVE YOU"))
                    guard let keypointsMultiArray = try? observation.keypointsMultiArray() else { fatalError() }
                                let handPosePrediction = try (classifier as? ASL_ILoveYou3)?.prediction(poses: keypointsMultiArray)
                    if handPosePrediction != nil {
                        let confidence = handPosePrediction?.labelProbabilities[handPosePrediction!.label]!
                        if confidence != nil && confidence! > 0.8 {
                            print("******** "+handPosePrediction!.label+" *****************")
                            if handPosePrediction!.label.uppercased() == text.uppercased() {
                                processPrediction(label: handPosePrediction!.label.capitalized)
                            }
                            return
                        }
                    }
                }
                return
            }
            
            //Fingerspelling section
            let index = text.index(text.startIndex, offsetBy: currentIndex)
            let nextChar = text[index]
            if nextChar == "H" || nextChar == "O" || nextChar == "I" {
                print("Looking for pose: " + String(nextChar))
                guard let keypointsMultiArray = try? observation.keypointsMultiArray() else { fatalError() }
                            let handPosePrediction = try (classifier as? ASL_HOLI10)?.prediction(poses: keypointsMultiArray)
                if handPosePrediction != nil {
                    let confidence = handPosePrediction?.labelProbabilities[handPosePrediction!.label]!
                    if confidence != nil && confidence! > 0.8 {
                        print("******** "+handPosePrediction!.label+" *****************")
                        if handPosePrediction!.label.uppercased() == nextChar.uppercased() {
                            processPrediction(label: handPosePrediction!.label.capitalized)
                        }
                        return
                    }
                }
            }
            else if nextChar == "A" || nextChar == "Y" {
                print("Looking for pose: " + String(nextChar))
                guard let keypointsMultiArray = try? observation.keypointsMultiArray() else { fatalError() }
                            let handPosePrediction = try (classifier as? ASL_AIY7)?.prediction(poses: keypointsMultiArray)
                if handPosePrediction != nil {
                    let confidence = handPosePrediction?.labelProbabilities[handPosePrediction!.label]!
                    if confidence != nil && confidence! > 0.8 {
                        print("******** "+handPosePrediction!.label+" *****************")
                        if handPosePrediction!.label.uppercased() == nextChar.uppercased() {
                            processPrediction(label: handPosePrediction!.label.capitalized)
                        }
                        return
                    }
                }
            }
            else if nextChar == "C" || nextChar == "O" {
                print("Looking for pose: " + String(nextChar))
                guard let keypointsMultiArray = try? observation.keypointsMultiArray() else { fatalError() }
                            let handPosePrediction = try (classifier as? ASL_CO2)?.prediction(poses: keypointsMultiArray)
                if handPosePrediction != nil {
                    let confidence = handPosePrediction?.labelProbabilities[handPosePrediction!.label]!
                    if confidence != nil && confidence! > 0.8 {
                        print("******** "+handPosePrediction!.label+" *****************")
                        if handPosePrediction!.label.uppercased() == nextChar.uppercased() {
                            processPrediction(label: handPosePrediction!.label.capitalized)
                        }
                        return
                    }
                }
            }
            else if nextChar == "D" {
                print("Looking for pose: " + String(nextChar))
                guard let keypointsMultiArray = try? observation.keypointsMultiArray() else { fatalError() }
                            let handPosePrediction = try (classifier as? ASL_D)?.prediction(poses: keypointsMultiArray)
                if handPosePrediction != nil {
                    let confidence = handPosePrediction?.labelProbabilities[handPosePrediction!.label]!
                    if confidence != nil && confidence! > 0.8 {
                        print("******** "+handPosePrediction!.label+" *****************")
                        if handPosePrediction!.label.uppercased() == nextChar.uppercased() {
                            processPrediction(label: handPosePrediction!.label.capitalized)
                        }
                        return
                    }
                }
            }
            else if nextChar == "E" {
                print("Looking for pose: " + String(nextChar))
                guard let keypointsMultiArray = try? observation.keypointsMultiArray() else { fatalError() }
                            let handPosePrediction = try (classifier as? ASL_E10)?.prediction(poses: keypointsMultiArray)
                if handPosePrediction != nil {
                    let confidence = handPosePrediction?.labelProbabilities[handPosePrediction!.label]!
                    if confidence != nil && confidence! > 0.8 {
                        print("******** "+handPosePrediction!.label+" *****************")
                        if handPosePrediction!.label.uppercased() == nextChar.uppercased() {
                            processPrediction(label: handPosePrediction!.label.capitalized)
                        }
                        return
                    }
                }
            }
            else if nextChar == "L" {
                print("Looking for pose: " + String(nextChar))
                guard let keypointsMultiArray = try? observation.keypointsMultiArray() else { fatalError() }
                            let handPosePrediction = try (classifier as? ASL_L2)?.prediction(poses: keypointsMultiArray)
                if handPosePrediction != nil {
                    let confidence = handPosePrediction?.labelProbabilities[handPosePrediction!.label]!
                    if confidence != nil && confidence! > 0.8 {
                        print("******** "+handPosePrediction!.label+" *****************")
                        if handPosePrediction!.label.uppercased() == nextChar.uppercased() {
                            processPrediction(label: handPosePrediction!.label.capitalized)
                        }
                        return
                    }
                }
            }
            else if nextChar == "I" {
                print("Looking for pose: " + String(nextChar))
                guard let keypointsMultiArray = try? observation.keypointsMultiArray() else { fatalError() }
                            let handPosePrediction = try (classifier as? ASL_I2)?.prediction(poses: keypointsMultiArray)
                if handPosePrediction != nil {
                    let confidence = handPosePrediction?.labelProbabilities[handPosePrediction!.label]!
                    if confidence != nil && confidence! > 0.8 {
                        print("******** "+handPosePrediction!.label+" *****************")
                        if handPosePrediction!.label.uppercased() == nextChar.uppercased() {
                            processPrediction(label: handPosePrediction!.label.capitalized)
                        }
                        return
                    }
                }
            }
            
            //
            
            //Hand Action Classifier
            frameCounter += 1
            if frameCounter % 2 == 0 {
                //Its coming in as 60 fps. We want 30 fps
                return
            }
            if poseObservations.count >= modelObservationsNeeded {
                poseObservations.removeFirst()
            }
            poseObservations.append(observation)
            
       /*     guard let posesMultiArray = prepareInputWithObservations(poseObservations),
                  let predictions = try? actionClassifier?.prediction(poses: posesMultiArray) else {
                return
            }   */
            let posesMultiArray = prepareInputWithObservations(poseObservations)
            if posesMultiArray != nil {
                if nextChar == "J" {
                    print("Looking for: " + String(nextChar))
                    guard let predictions = try? (classifier as? ASL_J2s_1strain)?.prediction(poses: posesMultiArray!) else { return }
                    print(predictions.label.capitalized)
                    if predictions.label.uppercased() == nextChar.uppercased() {
                        processPrediction(label: predictions.label.capitalized)
                    }
                }
                else if nextChar == "Z" {
                    print("Looking for action: " + String(nextChar))
                    guard let predictions = try? (classifier as? ASL_Z2s_1strain)?.prediction(poses: posesMultiArray!) else { return }
                    print(predictions.label.capitalized)
                    if predictions.label.uppercased() == nextChar.uppercased() {
                        processPrediction(label: predictions.label.capitalized)
                    }
                }
            }
        /*    let predictionsZ = try? (actionClassifier as? ASL_Z2s_1strain)?.prediction(poses: posesMultiArray)
            let predictions = textToGet == "J" ? predictionsJ : predictionsZ
            print(predictions.label.capitalized)
            if predictions.label.uppercased() != "BACKGROUND" {
                DispatchQueue.main.sync {
                    animateSignResult(letter: predictions.label.capitalized)
                    frameCounter = 0
                    poseObservations = [] //clear pose observations
                    if textToGet == "J" {
                        textToGet = "Z"
                        actionClassifier = try? ASL_Z2s_1strain(configuration: MLModelConfiguration())
                    }
                    else {
                        textToGet = "J"
                        actionClassifier = try? ASL_J2s_1strain(configuration: MLModelConfiguration())
                    }
                }
            }   */
            
            //return
            
            //
        } catch {
            cameraFeedSession?.stopRunning()
            let error = AppError.visionError(error: error)
            DispatchQueue.main.async {
                error.displayInViewController(self)
            }
        }
    }
    
    func processPrediction(label: String) {
        if contentToGet == nil {
            DispatchQueue.main.sync {
                topLabel.text = topLabel.text! + label
            }
            return
        }
        analyticsLogListItemRecognized(item: label)
        DispatchQueue.main.sync {
            animateSignResult(letter: nil)
            frameCounter = 0
            poseObservations = []
            poseObservations2 = []
            currentIndex = currentIndex + 1
            if contentToGet?.isFingerspelling == true {
                var nextChar : String = ""
                while true {
                    //loop to account for spaces
                    guard let text = contentToGet?.text else { break }
                    let index = text.index(text.startIndex, offsetBy: currentIndex)
                    if currentIndex >= text.count {
                        //animateSignResult(letter: nil)
                        resetSetup()
                        return
                    }
                    nextChar = String(text[index])
                    if nextChar != " " { break }
                    currentIndex = currentIndex + 1
                }
                setupNextCharacter(inputNextChar: Character(nextChar))
            }
            
        }
    }
    
    private func setupNextCharacter(inputNextChar : Character?) {
        guard let nextChar = inputNextChar?.uppercased() else {
            //This is for free text mode. Used for testing purposes
            //classifier = try? ISL_0TO9_10(configuration: MLModelConfiguration())
            return
        }
        setupStringWithCharacterHighlighted()
        updateBottomUI(text: String(nextChar))
        if nextChar == "H" || nextChar == "O" || nextChar == "I" {
            classifier = try? ASL_HOLI10(configuration: MLModelConfiguration())
        }
        else if nextChar == "A" || nextChar == "Y" {
            classifier = try? ASL_AIY7(configuration: MLModelConfiguration())
        }
        else if nextChar == "C" || nextChar == "O" {
            classifier = try? ASL_CO2(configuration: MLModelConfiguration())
        }
        else if nextChar == "D" {
            classifier = try? ASL_D(configuration: MLModelConfiguration())
        }
        else if nextChar == "E" {
            classifier = try? ASL_E10(configuration: MLModelConfiguration()) //E3
        }
        else if nextChar == "L" {
            classifier = try? ASL_L2(configuration: MLModelConfiguration())
        }
        else if nextChar == "I" {
            classifier = try? ASL_I2(configuration: MLModelConfiguration())
        }
        else if nextChar == "J" {
            classifier = try? ASL_J2s_1strain(configuration: MLModelConfiguration())
        }
        else if nextChar == "Z" {
            classifier = try? ASL_Z2s_1strain(configuration: MLModelConfiguration())
        }
    }
    
    private func setupNextWord(word : String?) {
        let wordUppercased = word?.uppercased()
        if wordUppercased == "I LOVE YOU" {
            classifier = try? ASL_ILoveYou3(configuration: MLModelConfiguration())
        }
        else if wordUppercased == "BATHROOM" {
            classifier = try? ASL_Bathroom_0_5strain(configuration: MLModelConfiguration())
        }
        else if wordUppercased == "YES" {
            classifier = try? ASL_Yes_0_5strain(configuration: MLModelConfiguration())
        }
        else if wordUppercased == "NO" {
            classifier = try? ASL_No_0_5strain(configuration: MLModelConfiguration())
        }
        else if wordUppercased == "TEACHER" {
            classifier = try? ASL_Teacher_1_5strain(configuration: MLModelConfiguration())
        }
        else if wordUppercased == "JUDGE" {
            classifier = try? ASL_Judge2_1strain(configuration: MLModelConfiguration())
        }
        else if wordUppercased == "THANKSGIVING" {
            classifier = try? ASL_ThanksgivingTurkey2_1strain(configuration: MLModelConfiguration())
        }
        else if wordUppercased == "HALLOWEEN" {
            classifier = try? ASL_Halloween2_1strain(configuration: MLModelConfiguration())
        }
        else if wordUppercased ==  "SOCCER" && contentToGet?.signLangType == Content.SignLanguageType.ISL {
            classifier = try? ISL_Soccer_2strain(configuration: MLModelConfiguration())
        }
        else if wordUppercased == "SOCCER" && contentToGet?.signLangType == Content.SignLanguageType.ASL {
            classifier = try? ASL_Soccer1_1strain(configuration: MLModelConfiguration())
        }
        else if wordUppercased == "AMBULANCE" {
            classifier = try? ASL_Ambulance_1strain(configuration: MLModelConfiguration())
        }
        else if wordUppercased == "EASTER" {
            classifier = try? ASL_Easter_1strain(configuration: MLModelConfiguration())
        }
        else if wordUppercased == "CELEBRATE" {
            classifier = try? ASL_Celebrate(configuration: MLModelConfiguration())
        }
        else if wordUppercased == "TENNIS" {
            classifier = try? ASL_Tennis2_1_5strain(configuration: MLModelConfiguration())
        }
        else if wordUppercased == "FIRE" {
            classifier = try? ASL_Fire_1strain(configuration: MLModelConfiguration())
        }
        else if wordUppercased == "LATER" {
            classifier = try? ASL_Later_0_5strain(configuration: MLModelConfiguration())
        }
        else if wordUppercased == "WHERE" {
            classifier = try? ASL_Where_0_5strain(configuration: MLModelConfiguration())
        }
        else if wordUppercased == "MILK" {
            classifier = try? ASL_Milk_0_5strain(configuration: MLModelConfiguration())
        }
        else if wordUppercased == "GOODBYE" {
            classifier = try? ASL_Goodbye_0_5strain(configuration: MLModelConfiguration())
        }
        else if wordUppercased == "WHICH" {
            classifier = try? ASL_Which(configuration: MLModelConfiguration())
        }
        else if wordUppercased == "YOURWELCOME" {
            classifier = try? ASL_YourWelcome2(configuration: MLModelConfiguration())
        }
        else if wordUppercased == "CHRISTMAS" {
            classifier = try? ASL_Christmas3_1strain(configuration: MLModelConfiguration())
        }
        else if wordUppercased == "TWITTER" {
            //classifier = try? ASL_Twitter_1strain(configuration: MLModelConfiguration())
        }
        updateBottomUI(text: word)
    }
    
    private func getMutableStringBig(text: String) -> NSMutableAttributedString {
        let myMutableString = NSMutableAttributedString(string: text, attributes: [NSAttributedString.Key.font:UIFont(name: "Georgia", size: tvTopBigTextSize)!])
        return myMutableString
    }
    
    private func setupStringWithCharacterHighlighted() {
        guard let text = contentToGet?.text else { return }
        let myMutableString = getMutableStringBig(text: text)
        myMutableString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.green, range: NSRange(location:currentIndex,length:1))
            // set label Attribute
            //tvTopBig.attributedText = myMutableString
            topLabel.attributedText = myMutableString
    }
    
    private func resetSetup() {
        frameCounter = 0
        poseObservations = [] //clear pose observations
        poseObservations2 = []
        currentIndex = 0
        guard let content = contentToGet else {
            setupNextCharacter(inputNextChar: nil)
            return
        }
        if content.isFingerspelling == false {
            ASLImageView.isHidden = true
            if content.maximumHandCount > 1 {
                labelHandsNumber.text = String(content.maximumHandCount)
                stackViewHandsNumber.isHidden = false
            }
            else {
                stackViewHandsNumber.isHidden = true
            }
            setupNextWord(word: content.text)
            topLabel.attributedText = getMutableStringBig(text: content.text)
            topLabel.isHidden = false
            bottomLabel.isHidden = true //This is not needed if we are not fingerspelling. Its only useful when showing the active character in fingerspelling mode
            return
        }
        topLabel.isHidden = false
        ASLImageView.isHidden = false
        stackViewHandsNumber.isHidden = true
        let index = content.text.index(content.text.startIndex, offsetBy: currentIndex)
        let nextChar = content.text[index]
        setupNextCharacter(inputNextChar: nextChar)
    }
    
    private func updateBottomUI(text : String?) {
        if text == nil {
            let txt = "Show Hand"
            let newImage = UIImage(named: "open_hand")
            if newImage != nil { startFade(newText: txt, newImage: newImage!) }
        }
        else if contentToGet?.signLangType == Content.SignLanguageType.ISL {
            let fileName = "india_flag"
            let newImage : UIImage? = UIImage(named: fileName)
            if newImage != nil { startFade(newText: text!, newImage: newImage!) }
        }
        else {
            let prefix = "ASL"
            let fileName = prefix + "_" + text!
            let newImage : UIImage? = UIImage(named: fileName)
            if newImage != nil { startFade(newText: text!, newImage: newImage!) }
        }
    }
    
    private func startFade(newText: String, newImage: UIImage) {

        bottomStackViewStoryboard.alpha = 1.0

        // fade out
        UIView.animate(withDuration: 1.0, animations: {
            self.bottomStackViewStoryboard.alpha = 0.0
        }) { (finished) in
            // fade in
            UIView.animate(withDuration: 1.0, animations: {
                self.bottomLabel.text = newText
                self.bottomImageView.image = newImage
                self.bottomStackViewStoryboard.alpha = 1.0
            })
        }
    }
}

protocol CameraViewControllerProtocol {
    
    func modalLoaded()
    func modalDismissed()
    func newContentReceived(content : Content)
}

extension CameraViewController :  CameraViewControllerProtocol {
    
    func modalLoaded() {
        cameraFeedSession?.stopRunning()
    }
    
    func modalDismissed() {
        cameraFeedSession?.startRunning()
    }
    
    func newContentReceived(content : Content) {
        contentToGet = content
        modelObservationsNeeded = contentToGet?.modelObservationsNeeded ?? modelObservationsNeeded
        handPoseRequest.maximumHandCount = contentToGet?.maximumHandCount ?? handPoseRequest.maximumHandCount
        Analytics.logEvent("se6_ios_listitem_selected", parameters: [
            "item_name" : content.text
        ])
        topInstructionLabel.text = "Try signing:"
        bottomImageView.isHidden = false
        resetSetup()
    }
}

