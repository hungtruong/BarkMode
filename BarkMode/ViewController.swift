//
//  ViewController.swift
//  BarkMode
//
//  Created by Hung Truong on 7/13/19.
//  Copyright © 2019 Hung Truong. All rights reserved.
//

import AVFoundation
import UIKit
import SoundAnalysis

enum AudioClassificationType: String {
    case notBark = "Not Bark"
    case bark = "Bark"
}

class ViewController: UIViewController {

//    var captureSession = AVCaptureSession()
    var audioEngine = AVAudioEngine()
    var streamAnalyzer: SNAudioStreamAnalyzer!
    let analysisQueue = DispatchQueue(label: "com.hung.barkmode")
    var isBark = false
    override func viewDidLoad() {
        super.viewDidLoad()
        
        switch AVAudioSession.sharedInstance().recordPermission {
        case AVAudioSessionRecordPermission.granted:
            print("Permission granted")
        case AVAudioSessionRecordPermission.denied:
            print("Pemission denied")
        case AVAudioSessionRecordPermission.undetermined:
            print("Request permission here")
            AVAudioSession.sharedInstance().requestRecordPermission({ (granted) in
                // Handle granted
            })
            return
        @unknown default:
            return
        }
        
        
        let barkClassifier = BarkMode()
        let model: MLModel = barkClassifier.model

        let inputFormat = audioEngine.inputNode.inputFormat(forBus: 0)
        streamAnalyzer = SNAudioStreamAnalyzer(format: inputFormat)
        
        do {
            // Prepare a new request for the trained model.
            let request = try SNClassifySoundRequest(mlModel: model)
            try streamAnalyzer.add(request, withObserver: self)
        } catch {
            print("Unable to prepare request: \(error.localizedDescription)")
            return
        }
        
        do {
            try audioEngine.start()
        } catch {
            print(error)
        }
        
        self.audioEngine.inputNode.installTap(onBus: 0, bufferSize: 8192, format: inputFormat) {
            buffer, time in
            
            // Analyze the current audio buffer.
            self.analysisQueue.async {
                self.streamAnalyzer.analyze(buffer, atAudioFramePosition: time.sampleTime)
            }
        }
    }
    
    func toggleMode() {
        switch UITraitCollection.current.userInterfaceStyle {
        case .light:
            UITraitCollection.current = UITraitCollection(userInterfaceStyle: .dark)
            overrideUserInterfaceStyle = .dark
        case .dark, .unspecified:
            fallthrough
        default:
            UITraitCollection.current = UITraitCollection(userInterfaceStyle: .light)
            overrideUserInterfaceStyle = .light
        }
    }
}

extension ViewController : SNResultsObserving {
    
    func request(_ request: SNRequest, didProduce result: SNResult) {
        
        // Get the top classification.
        guard let result = result as? SNClassificationResult,
            let classification = result.classifications.first else { return }
        
        // Determine the time of this result.
        let formattedTime = String(format: "%.2f", result.timeRange.start.seconds)
        print("Analysis result for audio at time: \(formattedTime)")
        
        let confidence = classification.confidence * 100.0
        let percent = String(format: "%.2f%%", confidence)
        
        // Print the result as Instrument: percentage confidence.
        print("\(classification.identifier): \(percent) confidence.\n")
        
        
        if confidence > 85.0 {
            guard let resultType = AudioClassificationType(rawValue: classification.identifier) else {
                return
            }
            DispatchQueue.main.async {
                switch resultType {
                case .bark:
                    if !self.isBark {
                        self.toggleMode()
                        self.isBark.toggle()
                    }
                case .notBark:
                    if self.isBark {
                        self.isBark.toggle()
                    }
                }
            }
        }
        
        
    }
    
    func request(_ request: SNRequest, didFailWithError error: Error) {
        print("The the analysis failed: \(error.localizedDescription)")
    }
    
    func requestDidComplete(_ request: SNRequest) {
        print("The request completed successfully!")
    }
}
