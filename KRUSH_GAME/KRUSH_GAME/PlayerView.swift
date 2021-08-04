//
//  PlayerView.swift
//  KRUSH_GAME
//
//  Created by Krishnarjun on 01/08/21.
//

import UIKit
import AVFoundation

///UIView` subclass backed by an `AVPlayerLayer` layer.
class PlayerView: UIView {
    
    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }

    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }

    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
}

