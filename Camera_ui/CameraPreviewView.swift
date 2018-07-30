//
//  CameraPreviewView.swift
//  Camera_ui
//
//  Created by Chan Hong Wing on 28/3/2017.
//  Copyright © 2017年 Chan Hong Wing. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

class CameraPreviewView: UIView {

    //1 指定一個 CALayer 的子類作為 main layer
    override static var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    //2 便利方法提供一個 layer
    var cameraPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    //3 需要一個 AVCaptureSession 來顯示來自攝像頭的輸入
    var session: AVCaptureSession? {
        get {
            return cameraPreviewLayer.session
        }
        set {
            cameraPreviewLayer.session = newValue
        }
    }

}
