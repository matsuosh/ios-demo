//
//  ViewController.swift
//  Raptter
//
//  Created by matsuosh on 2016/09/24.
//  Copyright © 2016年 matsuosh. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation

class RecordingViewController: UIViewController {

    @IBOutlet weak var recordingButton: UIButton! {
        didSet {
            recordingButton.addTarget(
                self,
                action: #selector(RecordingViewController.recordingButtonTapped(button:)),
                for: .touchUpInside)
        }
    }
    @IBOutlet weak var trackButton: UIButton! {
        didSet {
            trackButton.setTitle("TRACK1", for: .normal)
            trackButton.addTarget(
                self,
                action: #selector(RecordingViewController.trackButtonTapped(button:)),
                for: .touchUpInside)
        }
    }

    var isRecoding = false {
        didSet {
            trackButton.isEnabled = isRecoding == false
        }
    }
    var isStopped = false
    var output: AVCaptureMovieFileOutput?

    //var audioPlayer: AVAudioPlayer?
    
    var introPlayer: AVAudioPlayer?
    var mainPlayer: AVAudioPlayer?

    override func viewDidLoad() {
        super.viewDidLoad()

        // AVCaptureSessionを作る。
        let session = AVCaptureSession()
        session.sessionPreset = AVCaptureSessionPresetHigh
        session.addInput({
            let device = AVCaptureDevice.defaultDevice(
                withDeviceType: AVCaptureDeviceType.builtInWideAngleCamera,
                mediaType: AVMediaTypeVideo,
                position: AVCaptureDevicePosition.front)
            return try! AVCaptureDeviceInput(device: device)
            }())
        session.addInput({
            let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)
            return try! AVCaptureDeviceInput(device: device)
            }())
        output = AVCaptureMovieFileOutput()
        session.addOutput(output)
        
        // VideoPreviewLayerを作る。
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        previewLayer?.frame = view.layer.frame
        view.layer.addSublayer(previewLayer!)
        view.bringSubview(toFront: recordingButton)
        view.bringSubview(toFront: trackButton)

        session.startRunning()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //prepareToIntroPlayer()
        prepareToMainPlayer()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func recordingButtonTapped(button: UIButton) {
        if !isRecoding {
//            introPlayer?.play()
            startRecording()
            /*
            updateTime {
                self.startRecording()
            }
            recordingButton.setImage(UIImage(named: "circle2"), for: .normal)
            */
        } else {
            isStopped = true
            stopRecording()
        }
    }

    func trackButtonTapped(button: UIButton) {
        if button.titleLabel!.text == "TRACK1" {
            button.setTitle("TRACK2", for: .normal)
        } else {
            button.setTitle("TRACK1", for: .normal)
        }
        prepareToMainPlayer()
    }

    var timeInSeconds = 3
    let timeInterval = 1
    func updateTime(completion: @escaping () -> ()) {
        print("updateTime")
        timeInSeconds -= timeInterval
        print("\(timeInSeconds)")
        if timeInSeconds > 0 {
            Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { (timer) in
                self.recordingButton.setImage(UIImage(named: "circle2"), for: .normal)
                self.updateTime(completion: completion)
            }
        } else {
            timeInSeconds = 3
            self.recordingButton.setImage(UIImage(named: "circle"), for: .normal)
            completion()
        }
    }

    func startRecording() {
        isRecoding = true
        UIView.animate(
            withDuration: 0.5,
            delay: 0.0,
            options: [.repeat, .autoreverse, .allowUserInteraction],
            animations: {
                self.recordingButton.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            },
            completion: nil)
        let fileURL: URL = {
            let filename: String = {
                let formatter = DateFormatter()
                formatter.dateFormat = "YYYYMMddHHmmss"
                return formatter.string(from: Date()) + ".mov"
            }()
            return URL(fileURLWithPath: NSTemporaryDirectory() + filename)
        }()
        output?.startRecording(toOutputFileURL: fileURL, recordingDelegate: self)
        mainPlayer?.play()
        print("startRecording")
    }

    func stopRecording() {
        isRecoding = false
        output?.stopRecording()
        UIView.animate(withDuration: 0.5, delay: 1.0, options: [], animations: {
            self.recordingButton.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            }, completion: nil)
        recordingButton.layer.removeAllAnimations()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "playMovie" {
            let controller = segue.destination as! MovieViewController
            controller.fileURLs = [sender as! URL]
        }
    }

    private func prepareToIntroPlayer() {
        if let player = introPlayer {
            player.delegate = nil
        }
        let resource = "intro2"
        if let bundle = Bundle.main.path(forResource: resource, ofType: "wav") {
            let fileURL = URL(fileURLWithPath: bundle)
            introPlayer = try! AVAudioPlayer(contentsOf: fileURL)
            introPlayer?.delegate = self
            introPlayer?.prepareToPlay()
        }
    }

    func playIntro() {
        introPlayer?.play()
    }

    func prepareToMainPlayer() {
        if let player = mainPlayer {
            player.delegate = nil
        }
        //let resource = "track1-2"
        let resource: String
        if trackButton.currentTitle == "TRACK1" {
            resource = "track1-2"
        } else {
            resource = "track2-2"
        }
        if let bundle = Bundle.main.path(forResource: resource, ofType: "wav") {
            let fileURL = URL(fileURLWithPath: bundle)
            mainPlayer = try! AVAudioPlayer(contentsOf: fileURL)
            mainPlayer?.delegate = self
            mainPlayer?.prepareToPlay()
        }
    }

}

extension RecordingViewController: AVCaptureFileOutputRecordingDelegate {
    
    func capture(_ captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
        print("capture")
    }
    
    func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
        if (error) != nil {
            return
        }
        if isStopped {
            mainPlayer?.stop()
            prepareToMainPlayer()
            try! FileManager.default.removeItem(at: outputFileURL)
            return
        }
        let thumbnail: Data = {
            let asset = AVAsset(url: outputFileURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            let image = try! generator.copyCGImage(at: asset.duration, actualTime: nil)
            return UIImagePNGRepresentation(UIImage(cgImage: image))!
        }()
        let fileName = outputFileURL.lastPathComponent.replacingOccurrences(of: "mov", with: "png")
        let fileURL = URL(fileURLWithPath: fileName, relativeTo: URL(fileURLWithPath: NSTemporaryDirectory()))
        let result = FileManager.default.createFile(atPath: fileURL.path, contents: thumbnail, attributes: nil)
        print("result: \(result), atPath: \(fileURL.path)")
        performSegue(withIdentifier: "playMovie", sender: outputFileURL)
    }

}

extension RecordingViewController: AVAudioPlayerDelegate {

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if isIntro(fileURL: player.url!) {
            startRecording()
        } else {
            isStopped = false
            stopRecording()
        }
    }

    private func isIntro(fileURL: URL) -> Bool {
        return fileURL.lastPathComponent == "intro2.wav"
    }

}
