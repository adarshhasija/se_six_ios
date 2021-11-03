/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The app's main view controller object.
*/

import UIKit
import AVFoundation
import Vision

class CameraViewController: UIViewController {

    var classifier : Any?
    let modelObservationsNeeded = 30
    var poseObservations = [VNHumanHandPoseObservation]()
    var frameCounter = 0
    var textToGet : String = "JZAECMINOSYT"
    var currentIndex = 0
    private var cameraView: CameraView { view as! CameraView }
    
    private let videoDataOutputQueue = DispatchQueue(label: "CameraFeedDataOutput", qos: .userInteractive)
    private var cameraFeedSession: AVCaptureSession?
    private var handPoseRequest = VNDetectHumanHandPoseRequest()
    
    @IBOutlet weak var topStackViewStoryboard: UIStackView!
    @IBOutlet weak var topLabel: UILabel!
    @IBOutlet weak var topButton: UIButton!
    
    
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
    
    @objc func openModes(_: Any) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let secondViewController = storyboard.instantiateViewController(withIdentifier: "ModesTable") as! ModesTableViewController
        let navBarOnModal: MyNavigationController = MyNavigationController(rootViewController: secondViewController)
        navBarOnModal.delegateCamera = self
        secondViewController.delegateCameraView = self
        self.present(navBarOnModal, animated: true, completion: nil)
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
        handPoseRequest.maximumHandCount = 1
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
        
        topButton.addTarget(self, action: #selector(self.openModes(_:)), for: .touchUpInside)
        let fGuesture = UITapGestureRecognizer(target: self, action: #selector(self.openModes(_:)))
        topStackViewStoryboard.addGestureRecognizer(fGuesture)
        topStackViewStoryboard.isUserInteractionEnabled = true
        topStackViewStoryboard.isMultipleTouchEnabled = true
        bottomLabel.font = UIFont(name: "Georgia", size: tvTopBigTextSize + 25)
        resetSetup()
        
        tvMiddleBig.text = "✓" //"✔"
        tvMiddleBig.font = UIFont.systemFont(ofSize: 150)
        tvMiddleBig.sizeToFit()
        tvMiddleBig.textColor = .green
        tvMiddleBig.backgroundColor = .none
        tvMiddleBig.center = view.center
        tvMiddleBig.isHidden = true
        view.addSubview(tvMiddleBig)
    }
    

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        do {
            if cameraFeedSession == nil {
                cameraView.previewLayer.videoGravity = .resizeAspectFill
                try setupAVSession()
                cameraView.previewLayer.session = cameraFeedSession
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
        else {
            self.tvMiddleBig.text = "✓"
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

        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
        do {
            // Perform VNDetectHumanHandPoseRequest
            try handler.perform([handPoseRequest])
            // Continue only when a hand was detected in the frame.
            // Since we set the maximumHandCount property of the request to 1, there will be at most one observation.
            guard let observation = handPoseRequest.results?.first else {
                return
            }
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
                return
            }
            
            // Convert points from Vision coordinates to AVFoundation coordinates.
            thumbTip = CGPoint(x: thumbTipPoint.location.x, y: 1 - thumbTipPoint.location.y)
            indexTip = CGPoint(x: indexTipPoint.location.x, y: 1 - indexTipPoint.location.y)
            middleTip = CGPoint(x: middleTipPoint.location.x, y: 1 - middleTipPoint.location.y)
            ringTip = CGPoint(x: ringTipPoint.location.x, y: 1 - ringTipPoint.location.y)
            littleTip = CGPoint(x: littleTipPoint.location.x, y: 1 - littleTipPoint.location.y)
            
            
            //Hand Pose Classifier
            let index = textToGet.index(textToGet.startIndex, offsetBy: currentIndex)
            let nextChar = textToGet[index]
            if nextChar == "E" || nextChar == "M" || nextChar == "N" || nextChar == "S" || nextChar == "T" {
                guard let keypointsMultiArray = try? observation.keypointsMultiArray() else { fatalError() }
                            let handPosePrediction = try (classifier as? ASL_EMNST)?.prediction(poses: keypointsMultiArray)
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
            else if nextChar == "A" || nextChar == "I" || nextChar == "Y" {
                guard let keypointsMultiArray = try? observation.keypointsMultiArray() else { fatalError() }
                            let handPosePrediction = try (classifier as? ASL_AIY2)?.prediction(poses: keypointsMultiArray)
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
                print("Looking for: " + String(nextChar))
                if nextChar == "J" {
                    guard let predictions = try? (classifier as? ASL_J2s_1strain)?.prediction(poses: posesMultiArray!) else { return }
                    print(predictions.label.capitalized)
                    if predictions.label.uppercased() == nextChar.uppercased() {
                        processPrediction(label: predictions.label.capitalized)
                    }
                }
                else if nextChar == "Z" {
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
        DispatchQueue.main.sync {
            animateSignResult(letter: nil)
            frameCounter = 0
            poseObservations = []
            currentIndex = currentIndex + 1
            if currentIndex >= textToGet.count {
                //animateSignResult(letter: nil)
                resetSetup()
                return
            }
            let index = textToGet.index(textToGet.startIndex, offsetBy: currentIndex)
            let nextChar = textToGet[index]
            setupNextCharacter(nextChar: nextChar)
        }
    }
    
    private func setupNextCharacter(nextChar : Character) {
        setupStringWithCharacterHighlighted()
        updateBottomUI(text: String(nextChar))
        if nextChar == "E" || nextChar == "M" || nextChar == "N" || nextChar == "S" || nextChar == "T" {
            classifier = try? ASL_EMNST(configuration: MLModelConfiguration())
        }
        else if nextChar == "A" || nextChar == "I" || nextChar == "Y" {
            classifier = try? ASL_AIY2(configuration: MLModelConfiguration())
        }
        else if nextChar == "C" || nextChar == "O" {
            classifier = try? ASL_CO2(configuration: MLModelConfiguration())
        }
        else if nextChar == "J" {
            classifier = try? ASL_J2s_1strain(configuration: MLModelConfiguration())
        }
        else if nextChar == "Z" {
            classifier = try? ASL_Z2s_1strain(configuration: MLModelConfiguration())
        }
    }
    
    private func setupStringWithCharacterHighlighted() {
        let myMutableString = NSMutableAttributedString(string: textToGet, attributes: [NSAttributedString.Key.font:UIFont(name: "Georgia", size: tvTopBigTextSize)!])
        myMutableString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.green, range: NSRange(location:currentIndex,length:1))
            // set label Attribute
            //tvTopBig.attributedText = myMutableString
            topLabel.attributedText = myMutableString
    }
    
    private func resetSetup() {
        frameCounter = 0
        poseObservations = [] //clear pose observations
        currentIndex = 0
        let index = textToGet.index(textToGet.startIndex, offsetBy: currentIndex)
        let nextChar = textToGet[index]
        setupNextCharacter(nextChar: nextChar)
    }
    
    private func updateBottomUI(text : String?) {
        if text == nil {
            let txt = "Show Hand"
            let newImage = UIImage(named: "open_hand")
            if newImage != nil { startFade(newText: txt, newImage: newImage!) }
        }
        else {
            let fileName = "ASL_" + text!
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
    func newTextReceived(text : String)
}

extension CameraViewController :  CameraViewControllerProtocol {
    
    func modalLoaded() {
        cameraFeedSession?.stopRunning()
    }
    
    func modalDismissed() {
        cameraFeedSession?.startRunning()
    }
    
    func newTextReceived(text : String) {
        textToGet = text
        resetSetup()
    }
}

