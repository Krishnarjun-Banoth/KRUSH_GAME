//
//  LandingViewController.swift
//  KRUSH_GAME
//
//  Created by Krishnarjun on 01/08/21.
//

import Foundation
import AVFoundation
import CoreMotion
import UIKit
import CoreLocation

class LandingViewController: UIViewController {
    /// MARK: Properties
    
    let player = AVPlayer()
    let motionManager = CMMotionManager()
    let locationManager = CLLocationManager()
    private var timeObserverToken: Any?
    private var playerItemStatusObserver: NSKeyValueObservation?
    private var playerTimeControlStatusObserver: NSKeyValueObservation?
    static let pauseButtonImageName = "PauseButton"
    static let playButtonImageName = "PlayButton"
    private var previousLocation = CLLocation(latitude: 0.0, longitude: 0.0)
    /// MARK: - IBOutlet properties
    @IBOutlet weak var playerView: PlayerView!
    @IBOutlet weak var playPauseButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.becomeFirstResponder() // To get shake gesture
        
        guard let movieURL = Bundle.main.url(forResource: "bullrun", withExtension: "mp4") else {
                return
        }
        // Create an asset instance to represent the media file.
        let asset = AVURLAsset(url: movieURL)
        loadPropertyValues(forAsset: asset)
        
        play()
        senseDeviceMotion()
        getLocationUpdates()
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        pause()
        if let timeObserverToken = timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
        
        super.viewWillDisappear(animated)
    }
    
    /// We are willing to become first responder to get shake motion
    override var canBecomeFirstResponder: Bool {
        get {
            return true
        }
    }

    /// Enable detection of shake motion
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            togglePlay(self)
        }
    }
    
    
    /// MARK: - Asset Property Handling
    
    func loadPropertyValues(forAsset newAsset: AVURLAsset) {
        /// Load and test the following asset keys before playback begins.
        let assetKeysRequiredToPlay = [
            "playable",
            "hasProtectedContent"
        ]

        newAsset.loadValuesAsynchronously(forKeys: assetKeysRequiredToPlay) {
            DispatchQueue.main.async {
                if self.validateValues(forKeys: assetKeysRequiredToPlay, forAsset: newAsset) {
                    self.setupPlayerObservers()
                    self.playerView.player = self.player
                    self.player.replaceCurrentItem(with: AVPlayerItem(asset: newAsset))
                }
            }
        }
    }

   /// Confirm the successfull loading of all the asset's keys and verify their values.
    func validateValues(forKeys keys: [String], forAsset newAsset: AVAsset) -> Bool {
        for key in keys {
            var error: NSError?
            if newAsset.statusOfValue(forKey: key, error: &error) == .failed {
                let stringFormat = NSLocalizedString("The media failed to load the key \"%@\"",
                                                     comment: "You can't use this AVAsset because one of it's keys failed to load.")
                
                let message = String.localizedStringWithFormat(stringFormat, key)
                handleErrorWithMessage(message, error: error)
                
                return false
            }
        }
        
        if !newAsset.isPlayable || newAsset.hasProtectedContent {
            let message = NSLocalizedString("The media isn't playable or it contains protected content.",
                                            comment: "You can't use this AVAsset because it isn't playable or it contains protected content.")
            handleErrorWithMessage(message)
            return false
        }
        
        return true
    }
    
    /// MARK: - Key-Value Observing
    
    /// - Tag: PeriodicTimeObserver
    func setupPlayerObservers() {
        playerTimeControlStatusObserver = player.observe(\AVPlayer.timeControlStatus,
                                                         options: [.initial, .new]) { [unowned self] _, _ in
            DispatchQueue.main.async {
                self.setPlayPauseButtonImage()
            }
        }
        playerItemStatusObserver = player.observe(\AVPlayer.currentItem?.status, options: [.new, .initial]) { [unowned self] _, _ in
            DispatchQueue.main.async {
                self.updateUIforPlayerItemStatus()
            }
        }
    }
    
    
    @IBAction func togglePlay(_ sender: Any) {
        switch player.timeControlStatus {
        case .playing:
            pause()
        case .paused:
            let currentItem = player.currentItem
            if currentItem?.currentTime() == currentItem?.duration {
                playFromStart()
            } else {
                play()
            }
        default:
            pause()
        }
    }
    
    /// Adjust the play/pause button image to reflect the current play state.
    func setPlayPauseButtonImage() {
        var buttonImage: UIImage?
        
        switch self.player.timeControlStatus {
        case .playing:
            buttonImage = UIImage(named: LandingViewController.pauseButtonImageName)
        case .paused, .waitingToPlayAtSpecifiedRate:
            buttonImage = UIImage(named: LandingViewController.playButtonImageName)
        @unknown default:
            buttonImage = UIImage(named: LandingViewController.pauseButtonImageName)
        }
        guard let image = buttonImage else { return }
        self.playPauseButton.setImage(image, for: .normal)
    }
    
    func updateUIforPlayerItemStatus() {
        guard let currentItem = player.currentItem else { return }
        switch currentItem.status {
        case .failed:
            playPauseButton.isEnabled = false
            handleErrorWithMessage(currentItem.error?.localizedDescription ?? "", error: currentItem.error)
        case .readyToPlay:
            playPauseButton.isEnabled = true
        default:
            playPauseButton.isEnabled = false
        }
    }

    func getLocationUpdates() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 1
        let status = CLLocationManager.authorizationStatus()
        switch status {
        case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
                return
        case .denied, .restricted:
            let message = NSLocalizedString("Location Services disabled",
                                            comment: "Please enable Location Services in Settings")
            handleErrorWithMessage(message)
            return
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
            break

        @unknown default:
            break
        }
        
        
    }
    
}

///MARK: Handy methods
extension LandingViewController {
    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }
    
    func playFromStart() {
        player.currentItem?.seek(to: .zero, completionHandler: { (status) in
            if status {
                print("Replaying from the Start")
            } else {
                print("Failed to Replay from the Start")
            }
           
        })
    }
    
    func increseVolume() {
        player.volume = player.volume + 0.1
    }
    
    func decreaseVolume() {
        player.volume = player.volume - 0.1
    }
    
    /// MARK: - Error Handling
    func handleErrorWithMessage(_ message: String, error: Error? = nil) {
        if let err = error {
            print("Error occurred with message: \(message), error: \(err).")
        }
        let alertTitle = NSLocalizedString("Error", comment: "Alert title for errors")
        
        let alert = UIAlertController(title: alertTitle, message: message,
                                      preferredStyle: UIAlertController.Style.alert)
        let alertActionTitle = NSLocalizedString("OK", comment: "OK on error alert")
        let alertAction = UIAlertAction(title: alertActionTitle, style: .default, handler: nil)
        alert.addAction(alertAction)
        present(alert, animated: true, completion: nil)
    }
}

///MARK: Device Motion Handling
extension LandingViewController {
    func senseDeviceMotion() {
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { (data, error) in
            
            if let motionData =  data {
                let xRotation = (motionData.rotationRate.x).rounded()
                let zRotation = (motionData.rotationRate.z).rounded()
                if xRotation > 1 {
                    self.increseVolume()
                } else if xRotation < 0 {
                    self.decreaseVolume()
                } else {
                    //Do nothing
                }
                
                if zRotation > 1 {
                    self.player.currentItem?.seek(to: self.player.currentTime() + CMTime(seconds: zRotation, preferredTimescale: 1), completionHandler: { (status) in
                       
                    })
                } else if zRotation < 0 {
                    self.player.currentItem?.seek(to: self.player.currentTime() - CMTime(seconds: zRotation, preferredTimescale: 1), completionHandler: { (status) in
                       
                    })
                } else {
                    //Do nothing
                }
            }
        }
    }
    
}

///MARK : Location mangaer Delegate Methods
extension LandingViewController : CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let currentLocation = locations.last {
            let distanceDiffers = currentLocation.distance(from: previousLocation)
            if distanceDiffers > 10 {
                playFromStart()
            }
            previousLocation = currentLocation
        
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error)
    }
    
    func locationManager(_ manager: CLLocationManager,
                         didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
          case .restricted, .denied:
             // Disable your app's location features
             break
                
          case .authorizedWhenInUse:
             // Enable your app's location features.
             locationManager.startUpdatingLocation()
             break
                
          case .authorizedAlways:
             // Enable or prepare your app's location features that can run any time.
             locationManager.startUpdatingLocation()
             break
                
          case .notDetermined:
             break
          @unknown default:
             break
        }
    }
}
