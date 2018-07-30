//
//  ViewController.swift
//  Camera_ui
//
//  Created by Chan Hong Wing on 27/2/2017.
//  Copyright © 2017年 Chan Hong Wing. All rights reserved.
//
//Hide the status bar
//http://stackoverflow.com/questions/32965610/hide-the-status-bar-in-ios-9
//flash button
//http://www.jianshu.com/p/57b2c41448bf


import UIKit
import AVFoundation
import CoreLocation
import ZHDropDownMenu
import TagListView
import RandomColorSwift
//lock orientation of one view controller to portrait mode only in Swift
//http://stackoverflow.com/questions/28938660/how-to-lock-orientation-of-one-view-controller-to-portrait-mode-only-in-swift
struct AppUtility {
    
    static func lockOrientation(_ orientation: UIInterfaceOrientationMask) {
        
        if let delegate = UIApplication.shared.delegate as? AppDelegate {
            delegate.orientationLock = orientation
        }
    }
    
    /// OPTIONAL Added method to adjust lock and rotate to the desired orientation
    static func lockOrientation(_ orientation: UIInterfaceOrientationMask, andRotateTo rotateOrientation:UIInterfaceOrientation) {
        
        self.lockOrientation(orientation)
        
        UIDevice.current.setValue(rotateOrientation.rawValue, forKey: "orientation")
    }
    
}


class ViewController: UIViewController{
    
    //fileprivate = private(java)
    //AVCaptureSession 對象用來處理從攝像頭和麥克風輸入的流
    fileprivate let session = AVCaptureSession()
    //AVCaptureSession 用的Queue
    fileprivate let sessionQueue = DispatchQueue(label: "com.WingCH.camera.session-queue")
    //Location
    let locationManager = CLLocationManager()
    var gpsLocation : CLLocation? = nil
    
    //後鏡頭
    var backCameraDevice : AVCaptureDevice?
    var backCameraDeviceInput: AVCaptureDeviceInput!
    //前鏡頭
    var frontCameraDevice : AVCaptureDevice?
    var frontCameraDeviceInput: AVCaptureDeviceInput!
    //Taking a photo --> output
    fileprivate let photoOutput = AVCapturePhotoOutput()
    fileprivate let videoOutput = AVCaptureVideoDataOutput()

    
    //字典屬性來保持對這些 delegate 的引用
    fileprivate var photoCaptureDelegates = [Int64 : PhotoCaptureDelegate]()
    //記錄最後一個對焦格仔
    var lastFocusRectangle:CAShapeLayer? = nil
    //閃光燈Type
    var flashMode:AVCaptureFlashMode = .off
    
    var typeButton:JDJellyButton!
    //tag menu
    var imageTag:String? = ""
    var tagList:Set<String>=[]{
        didSet{
            print(tagList)
        }
    }
    @IBOutlet weak var tag: ZHDropDownMenu!
    @IBOutlet weak var flashBtn: UIButton!
    @IBOutlet weak var cameraPreviewView: CameraPreviewView!
    @IBOutlet weak var tagListView: TagListView!
    
    
    // 這次只有 modeGroup[0]
    var modeGroup:[[UIImage]] = [[UIImage]]()
    // 總共4個mode
    let mode:[UIImage] = [UIImage(named: "CameraAE")!,
                            UIImage(named: "PhotoAE")!]
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        //location
        locationManager.requestWhenInUseAuthorization()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.startUpdatingLocation()
        
        setJDJellyButton()
        setupMenu()
        tagListView.delegate = self

        //閃光燈
        flashBtn.setImage(UIImage(named: "OptionBarFlashBtn_on"), for: .normal)
        flashBtn.setImage(UIImage(named: "OptionBarFlashBtn_off"), for: .selected)
        //false = 開 true = 關
        flashBtn.isSelected = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppUtility.lockOrientation(.portrait)
        //開始 session
        sessionQueue.async {
            self.session.startRunning()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Don't forget to reset when view is being removed
        AppUtility.lockOrientation(.all)
    }
    
    
    @IBAction func flash_click(_ sender: UIButton) {
        flashBtn.isSelected = !flashBtn.isSelected;
        //因為 flashBtn.isSelected 系 enum 所以不需要 Default
        switch flashBtn.isSelected {
        case true:
            flashMode = .off
        case false:
            flashMode = .on
        }
        
        print("閃光燈: \(!flashBtn.isSelected)")
    }
    
    @IBAction func changeCam(_ sender: UIButton) {
        //Start
        session.beginConfiguration()
        let input = session.inputs.first as? AVCaptureDeviceInput
        let camera = input?.device
        session.removeInput(session.inputs[0] as! AVCaptureInput)
        
        if(camera == backCameraDevice){
            session.addInput(frontCameraDeviceInput);
        }else if(camera == frontCameraDevice){
            session.addInput(backCameraDeviceInput);
        }
        //End
        session.commitConfiguration()
    }
    
    
    @IBAction func takePhoto(_ sender: UIButton) {
        capturePhoto()
        print(UIDevice.current.orientation.isPortrait)
    }

    @IBAction func pinch(_ sender: UIPinchGestureRecognizer) {
        switch  sender.state {
        case .changed:
            print("sender.scale :",sender.scale)
            let input = session.inputs.first as? AVCaptureDeviceInput
            let camera = input?.device
            do {
                try camera?.lockForConfiguration()
                
                var factor = (camera?.videoZoomFactor)! * sender.scale
                //min 1倍 max 5倍
                factor = max(1, min(factor, 5))
                
                camera?.videoZoomFactor = factor
                
                camera?.unlockForConfiguration()
                
            } catch {
                print(error)
            }
        default:
            break
        }
    }
    
    


    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
}


extension ViewController:CLLocationManagerDelegate{
    
    func setCamera(){
        //1 將 session 傳遞給 view，因此它能顯示視圖
        cameraPreviewView.session = session
        //2 暫停 session 隊列，因此不會有任何事情發生
        sessionQueue.suspend()
        //3 請求麥克風和攝像頭的權限
        AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo) {
            success in
            if !success {
                print("Come on, it's a camera app!")
                return
            }
            //4 一旦請求通過，重新開啟 queue
            self.sessionQueue.resume()
        }
        sessionQueue.async {
            [unowned self] in
            //輸出屬性添加到 session 中
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
                self.photoOutput.isHighResolutionCaptureEnabled = true//決定瞭輸出照片的分辨率
            } else {
                print("Unable to add photo output")
                return
            }
            self.prepareCaptureSession()
        }
    }
    
    
    func setVideo(){
        
    }
    
    //一開始setting
    private func prepareCaptureSession() {
        // 1 告訴 session 你將要添加一系列的配置操作
        session.beginConfiguration()
        session.sessionPreset = AVCaptureSessionPresetPhoto
        do {
            // 2 創建一個後置攝像頭設備
            //builtInWideAngleCamera 廣角鏡
            //builtInTelephotoCamera 長焦段鏡頭(iPhone 7 plus only)
            backCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera,mediaType: AVMediaTypeVideo,position:.back)
            frontCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera,mediaType: AVMediaTypeVideo,position:.front)
            //AVMediaTypeAudio 麥克風
            let audioDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)

            
            // 3 創建一個設備輸入表示設備能捕獲的數據
            backCameraDeviceInput = try AVCaptureDeviceInput(device: backCameraDevice)
            frontCameraDeviceInput = try AVCaptureDeviceInput(device: frontCameraDevice)
            let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)

            
            
            // 4 將後鏡頭 添加輸入到 session
            if session.canAddInput(backCameraDeviceInput) && session.canAddInput(audioDeviceInput){
                session.addInput(backCameraDeviceInput)
                session.addInput(audioDeviceInput)
                // 5 返回主線程，只處理垂直方向的情形
                DispatchQueue.main.async {
                    //影像方向
                    self.cameraPreviewView.cameraPreviewLayer.connection.videoOrientation = .portrait
                }
            } else {
                print("Couldn't add device to the session")
                return
            }

        } catch {
            print("Couldn't create video device input: \(error)")
            return
        }
        
        
        // 6 一切順利，確認所以更改
        session.commitConfiguration()
    }
    
    //影相
    fileprivate func capturePhoto() {
        
        // 1 output 對象需要知道相機的方向
        let cameraPreviewLayerOrientation = cameraPreviewView.cameraPreviewLayer.connection.videoOrientation
        print(("Orientation :"),(cameraPreviewLayerOrientation.rawValue),(cameraPreviewLayerOrientation.hashValue))
        // 2 所有的工作都在特定的隊列中異步完成， connection 表示一條媒體流
        //   這條媒體流來自於 inputs 通過 session 直到 output
        sessionQueue.async {
            if let connection = self.photoOutput.connection(withMediaType: AVMediaTypeVideo){
                //相片方向
                connection.videoOrientation = self.getDeviceOrientation()
            }
            // 3 對於 JPEG 拍攝，並沒有太多要設置的
            let photoSettings = AVCapturePhotoSettings()
            //閃光燈 off = 0 on = 1 auto = 2
            photoSettings.flashMode = self.flashMode
            //是否以活動設備支持的最高分辨率捕獲靜止圖像和格式
            photoSettings.isHighResolutionPhotoEnabled = true
            
            // 1 每個 AVCapturePhotoSettings 實例創建時都會被自動分配一個 ID 標識
            let uniqueID = photoSettings.uniqueID
            // 初始化一個 PhotoCaptureDelegate 對象，傳入一個 completion 閉包
            let photoCaptureDelegate = PhotoCaptureDelegate() {
                [unowned self] (photoCaptureDelegate, asset) in
                self.sessionQueue.async {
                    [unowned self] in
                    self.photoCaptureDelegates[uniqueID] = .none//沒有值
                }
            }
            // 2 將 delegate 存入字典中
            self.photoCaptureDelegates[uniqueID] = photoCaptureDelegate
            photoCaptureDelegate.setLocation(gps: self.gpsLocation!)
        
            //Sets -> String 格式:"tag1 tag2 tag3"
            var tagList_String = ""
            
            for tag in self.tagList {
                if tagList_String == "" {
                    tagList_String += tag
                }else{
                    tagList_String += ","+tag
                }
            }
            
            photoCaptureDelegate.setTag(tag: tagList_String)
            
            // 3 開始拍照，並把 setting 和 delegate 傳進去
            self.photoOutput.capturePhoto(
                with: photoSettings, delegate: photoCaptureDelegate)
            
            //4 拍照完成後會閃一下
            photoCaptureDelegate.photoCaptureBegins = { [unowned self] in
                DispatchQueue.main.async {
//                    self.shutterButton.isEnabled = false
                    self.cameraPreviewView.cameraPreviewLayer.opacity = 0
                    UIView.animate(withDuration: 0.2) {
                        self.cameraPreviewView.cameraPreviewLayer.opacity = 1
                    }
                }
            }
            
//            photoCaptureDelegate.photoCaptured = { [unowned self] in
//                DispatchQueue.main.async {
//                    self.shutterButton.isEnabled = true
//                }
//            }
        }
    }
    
    func getDeviceOrientation() -> AVCaptureVideoOrientation{
        let orientation = UIDevice.current.orientation
        var imageOrientation: AVCaptureVideoOrientation = .portrait
        switch orientation {
        case .portrait:
            imageOrientation = .portrait
        case .portraitUpsideDown:
            imageOrientation = .portraitUpsideDown
        case .landscapeRight:
            //5知點解要landscapeLeft 個方向先岩
            imageOrientation = .landscapeLeft
        case .landscapeLeft:
            //5知點解要landscapeRight
            imageOrientation = .landscapeRight
        default: break
        }
        return imageOrientation
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        //拎touch location
        let pointInPreview : CGPoint = (touches.first?.location(in: self.cameraPreviewView))!
        //self.cameraPreviewView.cameraPreviewLayer => AVCaptureVideoPreviewLayer
        let pointInCamera = self.cameraPreviewView.cameraPreviewLayer.captureDevicePointOfInterest((for: pointInPreview))
        
        print(pointInCamera)
        
        //確保點擊相機畫面
        guard (pointInCamera.x>0 && pointInCamera.y>0) else {
            //如果不是點擊相機畫面 不會run下面個d
            return
        }
        
        //locked = 0 autoFocus = 1 continuousAutoFocus = 2
        let focusMode:AVCaptureFocusMode = AVCaptureFocusMode(rawValue: 2)!
        //locked = 0 autoExpose = 1 continuousAutoExposure = 2 custom = 3
        let exposureMode:AVCaptureExposureMode = AVCaptureExposureMode(rawValue: 1)!
        //touch 位置
        let touchPoint:CGPoint = CGPoint(x: (pointInCamera.x), y: (pointInCamera.y))
        
        let input = session.inputs.first as? AVCaptureDeviceInput
        let camera = input?.device
        
        do{
            //lock完先可以改野
            try camera?.lockForConfiguration()
            
            //進行配置
            
            //對焦 *前鏡頭 不支援對焦
            if((camera?.isFocusModeSupported(focusMode))!){
                //0,0 = 左下 1,1 = 右下 好似唔準 但work
                camera?.focusPointOfInterest = touchPoint
                camera?.focusMode = focusMode
            }
            
            //曝光
            if((camera?.isExposureModeSupported(exposureMode))!){
                camera?.exposurePointOfInterest = touchPoint
                camera?.exposureMode = exposureMode
            }
            
            
            //unlock
            camera?.unlockForConfiguration()
            
            //對焦格仔...
            showFocusRectangleAtPoint(pointInPreview)
            
        }catch{
            print(error)
            return
        }
        
    }
    
    func showFocusRectangleAtPoint(_ focusPoint: CGPoint){
        
        if let lastFocusRectangle = lastFocusRectangle {
            
            lastFocusRectangle.removeFromSuperlayer()
            self.lastFocusRectangle = nil
        }
        
        let size = CGSize(width: 75, height: 75)
        print("focusPoint : ",focusPoint)
        let rect = CGRect(origin: CGPoint(x: focusPoint.x - size.width / 2.0, y: focusPoint.y - size.height / 2.0), size: size)
        
        let endPath = UIBezierPath(rect: rect)
        endPath.move(to: CGPoint(x: rect.minX + size.width / 2.0, y: rect.minY))
        endPath.addLine(to: CGPoint(x: rect.minX + size.width / 2.0, y: rect.minY + 5.0))
        endPath.move(to: CGPoint(x: rect.maxX, y: rect.minY + size.height / 2.0))
        endPath.addLine(to: CGPoint(x: rect.maxX - 5.0, y: rect.minY + size.height / 2.0))
        endPath.move(to: CGPoint(x: rect.minX + size.width / 2.0, y: rect.maxY))
        endPath.addLine(to: CGPoint(x: rect.minX + size.width / 2.0, y: rect.maxY - 5.0))
        endPath.move(to: CGPoint(x: rect.minX, y: rect.minY + size.height / 2.0))
        endPath.addLine(to: CGPoint(x: rect.minX + 5.0, y: rect.minY + size.height / 2.0))
        
        let startPath = UIBezierPath(cgPath: endPath.cgPath)
        let scaleAroundCenterTransform = CGAffineTransform(translationX: -focusPoint.x, y: -focusPoint.y).concatenating(CGAffineTransform(scaleX: 2.0, y: 2.0).concatenating(CGAffineTransform(translationX: focusPoint.x, y: focusPoint.y)))
        startPath.apply(scaleAroundCenterTransform)
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = endPath.cgPath
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = UIColor(red:1, green:0.83, blue:0, alpha:0.95).cgColor
        shapeLayer.lineWidth = 1.0
        
        self.cameraPreviewView.layer.addSublayer(shapeLayer)
        lastFocusRectangle = shapeLayer
        //消失用
        CATransaction.begin()
        
        CATransaction.setAnimationDuration(0.2)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut))
        
        CATransaction.setCompletionBlock() {
            if shapeLayer.superlayer != nil {
                shapeLayer.removeFromSuperlayer()
                self.lastFocusRectangle = nil
            }
        }
        
        let appearPathAnimation = CABasicAnimation(keyPath: "path")
        appearPathAnimation.fromValue = startPath.cgPath
        appearPathAnimation.toValue = endPath.cgPath
        shapeLayer.add(appearPathAnimation, forKey: "path")
        
        let appearOpacityAnimation = CABasicAnimation(keyPath: "opacity")
        appearOpacityAnimation.fromValue = 0.0
        appearOpacityAnimation.toValue = 1.0
        shapeLayer.add(appearOpacityAnimation, forKey: "opacity")
        
        let disappearOpacityAnimation = CABasicAnimation(keyPath: "opacity")
        disappearOpacityAnimation.fromValue = 1.0
        disappearOpacityAnimation.toValue = 0.0
        disappearOpacityAnimation.beginTime = CACurrentMediaTime() + 0.8
        disappearOpacityAnimation.fillMode = kCAFillModeForwards
        disappearOpacityAnimation.isRemovedOnCompletion = false
        shapeLayer.add(disappearOpacityAnimation, forKey: "opacity")
        
        CATransaction.commit()
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if locations.count>0{
            self.gpsLocation = locations.first!
//            print("gpsLocation : ", self.gpsLocation!)
        }
    }
}


extension ViewController:JellyButtonDelegate
{
    func setJDJellyButton(){
        typeButton = JDJellyButton()
        var mode_a = mode
        //first root view (PhotoAE:相機)
        typeButton.attachtoView(rootView: self.view,mainbutton: UIImage(named:"PhotoAE")!)
        
        if let index = mode_a.index(of:  UIImage(named:"PhotoAE")!) {
            mode_a.remove(at: index)
        }
        modeGroup.append(mode_a)
        typeButton.delegate = self
        typeButton.datasource = self
        typeButton.setJellyType(type: .UpperLine)
        setCamera()
    }
    
    func JellyButtonHasBeenTap(touch:UITouch,image:UIImage,groupindex:Int,arrindex:Int)
    {
        print("JellyButtonHasBeenTap")
        //選擇完會自動收埋選單
        typeButton.MainButton.closingButtonGroup(expandagain: false)
        //選中個個image 變做root view
        typeButton.attachtoView(rootView: self.view, mainbutton: image)
        
        buttonSelect(index: arrindex)
        
        var mode_a = mode
        if let index = mode_a.index(of: image) {
            mode_a.remove(at: index)
        }
        modeGroup[0] = mode_a
        typeButton.reloadData()
        typeButton.setJellyType(type: .UpperLine)
        
    }
    
    func buttonSelect(index : Int){
        var selectMode : String!
        switch modeGroup[0][index] {
        case UIImage(named: "CameraAE")!:
            selectMode = "CameraAE"
            setVideo()
        case UIImage(named: "PhotoAE")!:
            selectMode = "PhotoAE"
            setCamera()
        default:
            break
        }
        print(selectMode)
    }
    
    
    
}

extension ViewController:JDJellyButtonDataSource
{
    func groupcount()->Int
    {
        return 1
    }
    func imagesource(forgroup groupindex:Int) -> [UIImage]
    {
        return modeGroup[groupindex]
    }
}

extension ViewController:ZHDropDownMenuDelegate
{
    func setupMenu(){
        tag.options = DBManager.shared.loadAllRow_TagDictionaryTableDara()//設置下拉列表項數據
        tag.menuHeight = 200
        tag.delegate = self //設置代理
    }
    func dropDownMenu(_ menu: ZHDropDownMenu!, didChoose index: Int) {
        imageTag = menu.options[index]
        addTag(text: menu.options[index])
        print("imageTag: ",imageTag!)
    }
    
    //編輯完成後回調
    func dropDownMenu(_ menu: ZHDropDownMenu!, didInput text: String!) {
        imageTag = text
        addTag(text:text)
        print(imageTag!)
        if !(imageTag?.isEmpty)! {
            DBManager.shared.insertImageType_tagDictionaryTable(tag: imageTag)
            tag.options = DBManager.shared.loadAllRow_TagDictionaryTableDara()
        }
    }
    
    func removeTagDictionary(_ tag:String){
        DBManager.shared.deleteTagDictionary(tag: tag)
    }

}

extension ViewController:TagListViewDelegate
{
    
    func addTag(text:String){
        //如果taglist入面本身無
        if !tagList.contains(text) {
            tagList.insert(text)

            let tagView = tagListView.addTag(text)
            tagView.tagBackgroundColor = randomColor(hue: .blue, luminosity: .light)
        }
    }
    
    
    func tagPressed(_ title: String, tagView: TagView, sender: TagListView) {
        print("Tag pressed: \(title), \(sender)")
        tagView.isSelected = !tagView.isSelected
    }
    
    func tagRemoveButtonPressed(_ title: String, tagView: TagView, sender: TagListView) {
        print("Tag Remove pressed: \(title), \(sender)")
        tagList.remove(title)
        sender.removeTagView(tagView)
    }
}

