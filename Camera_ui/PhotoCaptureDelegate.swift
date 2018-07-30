//
//  PhotoCaptureDelegate.swift
//  camera_v2
//
//  Created by Wing on 8/2/2017.
//  Copyright © 2017年 WingCH. All rights reserved.
//

import UIKit
import AVFoundation
import Photos
import ImageIO


//https://chengwey.com/ios-10-by-tutorials-bi-ji-shi-er/

class PhotoCaptureDelegate: NSObject {
    // 1 提供閉包在照相過程中的關鍵節點執行
    var photoCaptureBegins: (() -> ())? = .none//~無野
    var photoCaptured: (() -> ())? = .none
    //縮圖
    var thumbnailCaptured: ((UIImage?) -> ())? = .none
    // PHAsset代表照片庫中的一個資源，可以獲取和保存資源
    fileprivate let completionHandler: (PhotoCaptureDelegate, PHAsset?) -> ()
    // 2 用於存儲來自輸出的數據
    fileprivate var photoData: Data? = .none
    fileprivate var gpsLocation : CLLocation? = nil
    fileprivate var imageTag : String? = nil
    // 3 確保完成 completion 被設置，其他閉包都是可選的  @escaping屬性標記閉包
    init(completionHandler: @escaping (PhotoCaptureDelegate, PHAsset?) -> ()) {
        self.completionHandler = completionHandler
    }
    // 4 一旦所有都完成，調用 completion 閉包
    fileprivate func cleanup(asset: PHAsset? = .none) {
        completionHandler(self, asset)
    }
}

extension PhotoCaptureDelegate: AVCapturePhotoCaptureDelegate{
    
    //接收由ViewController 的 gps 資料
    func setLocation(gps:CLLocation) -> Void {
        self.gpsLocation = gps
    }
    
    //接收tag 的資料
    func setTag(tag:String) -> Void {
        self.imageTag = tag
    }
    
    // Process data completed
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer
        photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        guard let photoSampleBuffer = photoSampleBuffer else {
            print("Error capturing photo \(String(describing: error))")
            return
        }
        
//        if !((self.imageTag?.isEmpty)!){
//
//            let rawMetadata = CMCopyDictionaryOfAttachments(nil, photoSampleBuffer, CMAttachmentMode(kCMAttachmentMode_ShouldPropagate))
//            let metadata = CFDictionaryCreateMutableCopy(nil, 0, rawMetadata) as NSMutableDictionary
//            let exifData = metadata.value(forKey: "{Exif}") as? NSMutableDictionary
//            print("tag: ",self.imageTag!)
//            //https://medium.com/@kwylez/custom-exif-data-using-swift-4ff7f0f9cca7
//            //中文 表情5得 會變 -> ?
//                exifData?[kCGImagePropertyExifUserComment] =  self.imageTag!//冇括號會save 5晒
//            //            print("EXIF DATA: \(String(describing: exifData!))")
//        
//            metadata.setValue(exifData, forKey: "{Exif}")
//        
//            CMSetAttachments(photoSampleBuffer, metadata as CFDictionary, CMAttachmentMode(kCMAttachmentMode_ShouldPropagate))
//        }

        
        //e個已經系張相
        photoData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer,previewPhotoSampleBuffer: previewPhotoSampleBuffer)
        
     
////        print("photoData: ",UIImage(data: photoData!)!)
//
//        //get exif
//        //http://stackoverflow.com/questions/31888319/swift-accesing-exif-dictionary
//        let imageSource = CGImageSourceCreateWithData(photoData! as CFData, nil)
//        let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource!, 0, nil)! as NSDictionary
////
//        print("imageProperties: ",imageProperties)


    }
    

    // Entire process completed
    func capture(_ captureOutput: AVCapturePhotoOutput,   didFinishCaptureForResolvedSettings
        resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        // 1 檢查以確保一切都如預期
        guard error == nil, let photoData = photoData else {//guard類似if 但系行else先
            print("Error \(String(describing: error)) or no data")
            cleanup()
            return
        }

        // 2 申請訪問相冊的權限，PHAsset用來表示相冊中的相片和影片
        PHPhotoLibrary.requestAuthorization {
            [unowned self]
            (status) in
            // 3 鑒權失敗的話，執行 completion 閉包
            guard status == .authorized  else {
                print("Need authorisation to write to the photo library")
                self.cleanup()
                return
            }
            // 4 保存照片到相冊，並獲取 PHAsset
            var assetIdentifier: String?
            PHPhotoLibrary.shared().performChanges({
                let creationRequest = PHAssetCreationRequest.forAsset()
                let placeholder = creationRequest.placeholderForCreatedAsset
                creationRequest.addResource(with: .photo,data: photoData, options: .none)
                creationRequest.location = self.gpsLocation
                assetIdentifier = placeholder?.localIdentifier
                
            }, completionHandler: {(success, error) in if let error = error {
                print("Error saving to the photo library: \(error)")
            }else{
                var asset: PHAsset? = .none
                if let assetIdentifier = assetIdentifier {//not nil
                    //e到save id and tag to FMDB
                    if !((self.imageTag?.isEmpty)!){
                        DBManager.shared.insertImageType_imageTagTable(imageID: assetIdentifier, imageTag: self.imageTag)
//                        DBManager.shared.show_ImageTagTableDara()
                    }
                    asset = PHAsset.fetchAssets(
                        withLocalIdentifiers: [assetIdentifier],
                        options: .none).firstObject
                }
                
                self.cleanup(asset: asset)
                }
            })
        }
    }
    
    func capture(_ captureOutput: AVCapturePhotoOutput,
                 willCapturePhotoForResolvedSettings
        resolvedSettings: AVCaptureResolvedPhotoSettings) {
        photoCaptureBegins?()
    }
    
    func capture(_ captureOutput: AVCapturePhotoOutput,
                 didCapturePhotoForResolvedSettings
        resolvedSettings: AVCaptureResolvedPhotoSettings) {
        photoCaptured?()
    }
    
}
