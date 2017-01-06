//
//  ViewController.swift
//  DriveLog_swift
//
//  Created by TANAKAHiroki on 2016/04/24.
//  Copyright © 2016年 TANAKAHiroki. All rights reserved.
//

import UIKit
import MapKit
import AVFoundation
import Accounts
import Social
import CoreData

/*
extension UIView {
    func toImage() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(self.frame.size, false, 0.0)
        let context = UIGraphicsGetCurrentContext()
        context!.translateBy(x: 0.0, y: 0.0)
        self.layer.render(in: context!)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
}
*/

class ViewController: UIViewController,CLLocationManagerDelegate,MKMapViewDelegate,AVCaptureVideoDataOutputSampleBufferDelegate {

    // MARK: - プロパティ
    var isAutoCaptureMode:Bool = false  //自動撮影モード
    
    let locationManager:CLLocationManager = CLLocationManager()
    var initMap = false
    var lastLocation:CLLocationCoordinate2D?
    var address:String?
    
    // For AVCapture
    var input:AVCaptureDeviceInput?
    
    //var output:AVCaptureStillImageOutput!
    var output:AVCaptureVideoDataOutput!
    
    var session:AVCaptureSession!
    //var preView:UIView!
    var camera:AVCaptureDevice?
    
    var capturedImage:UIImage?
    
    // Videoが使用可能かどうか
    var isAvailableVideo = true
    
    // Twitter Param
    var lastPostLocation:CLLocationCoordinate2D?
    var range:Int?
    var isRelationToTwitter = false

    // CoreData
    var entryDescription:NSEntityDescription!
    var managedContext:NSManagedObjectContext!
    
    // MARK: - Outlets
    @IBOutlet weak var labelLog: UILabel!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var imageViewVideo: UIImageView!
    @IBOutlet weak var labelAddress: UILabel!
    @IBOutlet weak var btnAutoCapture: UIButton!
    
    // MARK: - Actions
    @IBAction func btnConfig(_ sender: AnyObject) {
        performSegue(withIdentifier: "configSegue", sender: sender)
    }
    
    @IBAction func btnCapture(_ sender: AnyObject) {
        self.doCapture(manualMode:true)
    }
    
    @IBAction func btnAutoCapture(_ sender: AnyObject) {
        
        if(self.isAutoCaptureMode == false)
        {
            self.isAutoCaptureMode = true
            
            let button = sender as! UIButton
            button.setTitle("Stop Capture", for: UIControlState())
        }
        else
        {
            self.isAutoCaptureMode = false
            
            let button = sender as! UIButton
            button.setTitle("Start Capture", for: UIControlState())
        }
    }
    
    // MARK: - Methods
    // MARK: キャプチャの保存を実行する
    
    func doCapture(manualMode:Bool = false)
    {
        print("doCapture")
        
        //画像添付
        var imageData:Data? = nil
        if isAvailableVideo {
            
            if (session != nil) {
                self.session!.stopRunning()
                imageData = UIImageJPEGRepresentation(self.imageViewVideo.image!,1)!
                //imageData = UIImageJPEGRepresentation(self.preView.toImage()!,1)
                self.session!.startRunning()
            }
            
            /*  still image
            let connection = output.connection(withMediaType: AVMediaTypeVideo)
            output.captureStillImageAsynchronously(from: connection, completionHandler: { (imageDataBuffer, error)->Void in
                let myImageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataBuffer)
                //_ = UIImage(data: myImageData!)!
                imageData = myImageData
            })
            */
            
            /*
            self.takeStillPicture()
            if let t = self.captureImageData
            {
                imageData = t
            }
            else
            {
                print("no captureImage")
                return
            }
            */
        }
        
        if (imageData == nil)
        {
            imageData = UIImageJPEGRepresentation(UIImage(named: "neko.png")!,1)!
        }

        if (manualMode)
        {
            self.capturedImage = UIImage.init(data: imageData!) //for preview
            self.performSegue(withIdentifier: "previewSegue", sender: nil)
        }
        else
        {
            // Save Data to CoreData
            let photo = Photo(entity: entryDescription, insertInto: managedContext)
            
            if let t = self.address { photo.address = t}
            photo.latitude = lastLocation!.latitude as NSNumber?
            photo.longiture = lastLocation!.longitude as NSNumber?
            photo.image = imageData
            photo.photoid = UUID().uuidString
            photo.date = Date()
            
            do {
                try managedContext.save()
            } catch let error as NSError  {
                print("Could not save \(error), \(error.userInfo)")
            }
            
            if(self.isRelationToTwitter)
            {
                self.postTweet(imageData!)
            }
            
            if let t:CLLocationCoordinate2D = lastLocation
            {
                let format = DateFormatter()
                format.dateFormat = "yyyy-MM-dd HH:mm:ss"

                let pin = MyAnnotation(location: t)
                pin.identity = photo.photoid
                pin.title = format.string(from: photo.date! as Date)
                pin.subtitle = photo.address!
                
                // 地図にピンを立てる
                mapView.addAnnotation(pin)
            }
            
            // Postした位置を記録して次回の距離差分判定に使用する
            lastPostLocation = lastLocation
        }
        
    }
    
    // MARK: - ViewController Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        
        // CoreData
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        managedContext = appDelegate.managedObjectContext
        entryDescription =  NSEntityDescription.entity(forEntityName: "Photo",in:managedContext)
        
        let defaults = UserDefaults()
        
        //Tweet間隔読み込み
        if let t:Int = defaults.integer(forKey: "TweetRange") as Int?
        {
            range = Util.DistRangeIdxToMeter(t)
        }
        else
        {
            range = 100;
        }
        
        locationManager.delegate = self

        // 測位の精度を 100ｍ とする
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        
        // 位置情報取得間隔の指定
        locationManager.distanceFilter = 50.0
        
        // 用途の指定
        locationManager.activityType = CLActivityType.automotiveNavigation
        
        // 位置情報サービスへの認証状態を取得する
        let status = CLLocationManager.authorizationStatus()
        if status == CLAuthorizationStatus.notDetermined {
            // 未認証ならリクエストダイアログ出す
            locationManager.requestWhenInUseAuthorization();
        }
        locationManager.startUpdatingLocation()
        
        // MapView設定
        mapView.delegate = self
        mapView.setUserTrackingMode(MKUserTrackingMode.follow, animated: true)
        
        // ビデオ画像ストリーミング開始
        self.configureCamera()
        
        // CoreData Load Test
        self.fetchCoreData()
    }
    
    // メモリ管理のため
    override func viewWillAppear(_ animated: Bool) {
        // スクリーン設定
        //setupDisplay()
        // カメラの設定
        //setupCamera()
    }
    
    // メモリ管理のため
    override func viewDidDisappear(_ animated: Bool) {
        // camera stop メモリ解放
//        if (session != nil)
//        {
//            session!.stopRunning()
//            
//            for output in session!.outputs {
//                session!.removeOutput(output as? AVCaptureOutput)
//            }
//            
//            for input in session!.inputs {
//                session!.removeInput(input as? AVCaptureInput)
//            }
//            session = nil
//            camera = nil
//        }
    }
    
//    func setupDisplay(){
//        //スクリーンの幅
//        let screenWidth = UIScreen.main.bounds.size.width;
//        //スクリーンの高さ
//        let screenHeight = UIScreen.main.bounds.size.width*3/4;
//        
//        // プレビュー用のビューを生成
//        preView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: screenWidth, height: screenHeight))
//        
//    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
        
    // MARK: 画像をキャプチャーしてTwitterに投稿し、Pinを立てる
    fileprivate func postTweet(_ imageData:Data) {
        // ツイートしたい文章をセット
        var status = "\(range)m間隔でTweet中 "
        if(address == nil)
        {
            status += "現在位置測定中"
        }
        else
        {
            status += address!
        }
        
        Util.doTweet(status,imageData: imageData, location: lastLocation)
    }

    //MARK: - CoreData関連Methods
    //MARK: CoreDataからデータ読み込み（全データ）してPinを立てる
    func fetchCoreData() {
        self.fetchCoreData(nil)
    }
    
    func fetchCoreData(_ predicate:NSPredicate?)
    {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Photo")

        if let t = predicate {
            fetchRequest.predicate = t
        }
        
        var photos = [Photo]()
        do {
            let results =
                try managedContext.fetch(fetchRequest)
            photos = results as! [Photo]
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        
        for photo in photos {
            
            // imageはメモリを食うので、Pinを表示するタイミングで別途取得する
            let lat:Double = Double(photo.latitude!)
            let lon:Double = Double(photo.longiture!)
            let date:Date = photo.date! as Date
            
            let format = DateFormatter()
            format.dateFormat = "yyyy-MM-dd HH:mm:ss"
            
            // ピンを作成する（identityを追加したカスタムクラスを使用する）
            let pin:MyAnnotation = MyAnnotation(location: CLLocationCoordinate2D(latitude: lat, longitude: lon))
            
            pin.title = format.string(from: date)
            pin.subtitle = photo.address!
            pin.identity = photo.photoid
            
            // 地図にピンを立てる
            mapView.addAnnotation(pin)
        }
    }
    
    // MARK: photoidから画像を取得する
    func fetchImage(_ photoid:String) -> UIImage
    {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Photo")
        
        let predicate = NSPredicate(format: "photoid = %@",photoid)
        fetchRequest.predicate = predicate
        
        var photos = [Photo]()
        
        do {
            let results =
                try managedContext.fetch(fetchRequest)
            photos = results as! [Photo]
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        
        if let t = photos[0].image
        {
            return UIImage(data:t as Data)!
        }
        return UIImage(named: "neko.png")!
        
        //return UIImage(data:photos[0].image!)!
    }
    
    //MARK: photoidをキーにして削除を行う
    func deleteCoreData(_ photoid:String)
    {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Photo")

        let predicate = NSPredicate(format: "photoid = %@",photoid)
        fetchRequest.predicate = predicate
        
        do {
            let results = try managedContext.fetch(fetchRequest)
            
            for result in results {
                managedContext.delete(result as! NSManagedObject)
            }
            // 保存を忘れず
            try managedContext.save()
            
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
    }
    
    // MARK: - 遷移先のSegue(ViewController)に値を渡して表示する
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let identifier = segue.identifier {
            
            print(identifier)
            
            if identifier == "PhotoDetailViewSegue"
            {

                let annotationView = sender as! MKAnnotationView
                let myPin = annotationView.annotation as! MyAnnotation

                let photoViewCon = segue.destination as! PhotoDetailViewController

                if let t = myPin.identity {
                    photoViewCon.photoImage = fetchImage(t)
                    photoViewCon.photoid = myPin.identity
                    photoViewCon.myPin = myPin
                    photoViewCon.address = myPin.subtitle                    
                }
            }
            else if identifier == "previewSegue"
            {
                let previewCon = segue.destination as! PreviewViewController
                //previewCon.imageView.image = self.capturedImage
                //previewCon.textbotTweet.text = "ほげほげほげ"
                previewCon.photoImage = self.capturedImage
                previewCon.tweetText = "ほげーー"
            }
        }
    }
    
    // MARK: - カメラとストリーミングのセットアップ
    func configureCamera()
    {
        session = AVCaptureSession()
        session.sessionPreset = AVCaptureSessionPresetMedium
        //session.sessionPreset = AVCaptureSessionPresetHigh

        output = AVCaptureVideoDataOutput()
        //output = AVCaptureStillImageOutput()
        
        var camera:AVCaptureDevice!
        var videoInput:AVCaptureDeviceInput! = nil
        
        // find back camera
        for caputureDevice: AnyObject in AVCaptureDevice.devices() as [AnyObject] {
            // 背面カメラを取得
            if caputureDevice.position == AVCaptureDevicePosition.back {
                camera = caputureDevice as? AVCaptureDevice
            }
        }
        
        if camera == nil
        {
            isAvailableVideo = false
            return
        }
        
        // カメラからの入力データ
        do {
            videoInput = try AVCaptureDeviceInput(device: camera) as AVCaptureDeviceInput
        } catch let error as NSError {
            print(error)
        }
        
        if session.canAddInput(videoInput)
        {
            session.addInput(videoInput)
        }

        output.setSampleBufferDelegate(self, queue:DispatchQueue.main)
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as AnyHashable : Int(kCVPixelFormatType_32BGRA)
        ]
        session.addOutput(output)
        
        /// preview test
//        //スクリーンの幅
//        let screenWidth = UIScreen.main.bounds.size.width;
//        //スクリーンの高さ
//        let screenHeight = UIScreen.main.bounds.size.height;
//        // プレビュー用のビューを生成
//        preView = UIView(frame: CGRect(x:0.0, y:0.0, width:screenWidth, height:screenHeight/2))
//
//        let captureVideoPreviewLayer:AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.session)
//        captureVideoPreviewLayer.frame = self.view.bounds;
//        captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
//
//        let previewLayer:CALayer  = self.preView!.layer;
//        previewLayer.masksToBounds = true
//        previewLayer.addSublayer(captureVideoPreviewLayer);
//        
//        self.view.addSubview(self.preView!)
        ///
        
        
        do {
            
            if camera != nil
            {
                try camera.lockForConfiguration()
                // フレームレート
                camera.activeVideoMinFrameDuration = CMTimeMake(1, 10)
                camera.unlockForConfiguration()
            }
        } catch _ {
        }

        session.startRunning()
    }
    
//    func setupCamera(){
//        
//        // セッション
//        session = AVCaptureSession()
//        
//        //for caputureDevice: AnyObject in AVCaptureDevice.devices() {
//        for caputureDevice in AVCaptureDevice.devices() as [AnyObject] {
//
//            // 背面カメラを取得
//            if caputureDevice.position == AVCaptureDevicePosition.back {
//                camera = caputureDevice as? AVCaptureDevice
//            }
//            // 前面カメラを取得
//            //if caputureDevice.position == AVCaptureDevicePosition.Front {
//            //    camera = caputureDevice as? AVCaptureDevice
//            //}
//        }
//        
//        // カメラからの入力データ
//        do {
//            input = try AVCaptureDeviceInput(device: camera) as AVCaptureDeviceInput
//        } catch let error as NSError {
//            print(error)
//            self.isAvailableVideo = false
//            return
//        }
//        
//        // 入力をセッションに追加
//        if(session.canAddInput(input)) {
//            session.addInput(input)
//        }
//        
//        // 静止画出力のインスタンス生成
//        output = AVCaptureStillImageOutput()
//        // 出力をセッションに追加
//        if(session.canAddOutput(output)) {
//            session.addOutput(output)
//        }
//        
//        // セッションからプレビューを表示を
//        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
//        
//        previewLayer?.frame = preView.frame
//        
//        //        previewLayer.videoGravity = AVLayerVideoGravityResize
//        //        previewLayer.videoGravity = AVLayerVideoGravityResizeAspect
//        previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
//        
//        // レイヤーをViewに設定
//        // これを外すとプレビューが無くなる、けれど撮影はできる
//        self.view.layer.addSublayer(previewLayer!)
//        
//        session.startRunning()
//    }

    
//    func takeStillPicture(){
//        // ビデオ出力に接続.
//        if let connection:AVCaptureConnection? = output.connection(withMediaType: AVMediaTypeVideo){
//            // ビデオ出力から画像を非同期で取得
//            output.captureStillImageAsynchronously(from: connection, completionHandler: { (imageDataBuffer, error) -> Void in
//                
//                // 取得画像のDataBufferをJpegに変換
//                let imageData:Data = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataBuffer)
//                
//                // JpegからUIImageを作成.
//                //let image:UIImage = UIImage(data: imageData)!
//                self.captureImageData = imageData
//                
//                // アルバムに追加.
//                UIImageWriteToSavedPhotosAlbum(UIImage(data:imageData)!, self, nil, nil)
//            })
//        }
//    }
    

    // MARK: - 緯度経度から住所を求める
    func reverseGeoCode(_ location2D:CLLocationCoordinate2D)
    {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: location2D.latitude, longitude: location2D.longitude)
        
        geocoder.reverseGeocodeLocation(location,
                                        completionHandler: { (placemarks, error) -> Void in
                                            
                                            if placemarks == nil
                                            {
                                                self.address = ""
                                                self.labelAddress.text = "現在位置取得中"
                                            }
                                            else
                                            {
                                                for placemark in placemarks! {
                                                    /*
                                                     print("Name: \(placemark.name)")
                                                     print("Country: \(placemark.country)")
                                                     print("ISOcountryCode: \(placemark.ISOcountryCode)")
                                                     print("administrativeArea: \(placemark.administrativeArea)")
                                                     print("subAdministrativeArea: \(placemark.subAdministrativeArea)")
                                                     print("Locality: \(placemark.locality)")
                                                     print("PostalCode: \(placemark.postalCode)")
                                                     print("areaOfInterest: \(placemark.areasOfInterest)")
                                                     print("Ocean: \(placemark.ocean)")
                                                     */
                                                    
                                                    var ads:String = "@";
                                                    if let t = placemark.administrativeArea{ads = ads + t + " "}
                                                    if let t = placemark.locality{ads = ads + t + " "}
                                                    if let t = placemark.thoroughfare{ads = ads + t}
                                                    
                                                    self.address = ads
                                                    self.labelAddress.text = ads
                                                }
                                            }
        })
    }

    // MARK: - 子画面から戻ってきた時に呼ばれる
    @IBAction func unwindAction(_ segue: UIStoryboardSegue) {
        // とりあえず空
        print(segue.identifier!)

        if segue.identifier == "UnwindConfig"
        {
            let ud = UserDefaults()
            
            if let t:Int = ud.integer(forKey: "TweetRange") as Int?
            {
                range = Util.DistRangeIdxToMeter(t)
                labelLog.text = String("\(range)m")
            }
            
            if let t:Bool = ud.bool(forKey: "RelationTwitter") as Bool?
            {
                self.isRelationToTwitter = t
            }
        }
        else if segue.identifier == "UnwindPhotoDetail"
        {
            // Pinを削除する
            let photoDetailViewCon = segue.source as! PhotoDetailViewController
            self.mapView.removeAnnotation(photoDetailViewCon.myPin!)
            
            // CoreDataから削除する
            self.deleteCoreData(photoDetailViewCon.myPin!.identity!)
        }
        else if segue.identifier == "UnwindPreview"
        {
            print("unwind save")
        }
        
    }
    
    // MARK: - Delegates
    // MARK: Annotationが表示されるときに呼ばれる
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        if let myAnnotation = annotation as? MyAnnotation
        {
            print(myAnnotation.identity!)
            
            if myAnnotation === mapView.userLocation { // 現在地を示すアノテーションの場合はデフォルトのまま
                return nil
            } else {
                
                let identifier = "pin"
                
                let annotationView = MKAnnotationView(annotation: myAnnotation, reuseIdentifier: identifier)
                
                let size: CGSize = CGSize(width: 42, height: 42)
                
                let image:UIImage = fetchImage(myAnnotation.identity!)
                
                // 写真を描画する
                UIGraphicsBeginImageContext(size)
                
                //imageArray[Int(annotation.title!!)!].drawInRect(CGRectMake(0, 0, size.width, size.height))
                //UIImage(named: "neko.png")!.drawInRect(CGRectMake(0, 0, size.width, size.height))
                image.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                
                let resizeImage = UIGraphicsGetImageFromCurrentImageContext()
                
                UIGraphicsEndImageContext()
                
                annotationView.annotation = myAnnotation
                
                // 描画した写真を設定する
                annotationView.image = resizeImage
                
                // タップした時に Callout(吹き出し)が表示されるようにする
                annotationView.canShowCallout = true
                
                // Callout(吹き出し)にディスクロージャを表示する
                annotationView.rightCalloutAccessoryView = UIButton(type: UIButtonType.detailDisclosure)
                
                return annotationView
            }
        }
        return nil
    }
    
    // MARK: Callout(吹き出し)をタップした時に呼ばれる
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        self.performSegue(withIdentifier: "PhotoDetailViewSegue", sender: view)
        
        // Annotation を非選択にして Callout(吹き出し)を非表示にする
        mapView.deselectAnnotation(view.annotation, animated: true)
    }
    
    // MARK: キャプチャーの取得時に呼ばれる
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {

        //イメージバッファーの取得
        let buffer:CVImageBuffer!
        buffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        
        //イメージバッファーのロック
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        
        // イメージバッファ情報の取得
        //var base: UInt8
        var width: size_t
        var height: size_t
        var bytesPerRow: size_t
        
        let base = UnsafeMutableRawPointer(CVPixelBufferGetBaseAddress(buffer));
        width = CVPixelBufferGetWidth(buffer);
        height = CVPixelBufferGetHeight(buffer);
        bytesPerRow = CVPixelBufferGetBytesPerRow(buffer);
        
        // ビットマップコンテキストの作成
        var colorSpace:CGColorSpace!
        var cgContext:CGContext!
        colorSpace = CGColorSpaceCreateDeviceRGB();
        
        //let bitmapInfo:CGBitmapInfo = [.ByteOrder32Little, CGBitmapInfo(rawValue: ~CGBitmapInfo.AlphaInfoMask.rawValue | CGImageAlphaInfo.PremultipliedFirst.rawValue)]
        
        let bitmapInfo = CGBitmapInfo(rawValue: (CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) as UInt32)
        
        cgContext = CGContext(
            data: base,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        );
        
        //CGColorSpaceRelease(colorSpace);
        
        // 画像の作成
        var cgImage:CGImage!
        var image:UIImage!
        cgImage = cgContext.makeImage();
        
        //image = [UIImage imageWithCGImage:cgImage scale:1.0f orientation:UIImageOrientationRight];
        image = UIImage(cgImage: cgImage, scale: 1.0, orientation: UIImageOrientation.right);
        //CGImageRelease(cgImage);
        //CGContextRelease(cgContext);
        
        // イメージバッファのアンロック
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)));

 
        // クリッピング
        let imageW = image.size.width
        let cropCGImageRef = image.cgImage!.cropping(to: CGRect(x:0, y:0, width:imageW, height:imageW))
        let cropImage = UIImage(cgImage: cropCGImageRef!,scale: 1.0, orientation:UIImageOrientation.right)
        
        // 画像の表示
        //imageViewVideo.image = image;
        imageViewVideo.image = cropImage;

    }

    // MARK: 位置情報が更新された時に呼ばれる
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        self.mapView.showsUserLocation = true
        
        lastLocation = self.mapView.userLocation.coordinate
        reverseGeoCode(lastLocation!)
        
        if(initMap == false)
        {
            let centerCordinate: CLLocationCoordinate2D = self.mapView.userLocation.coordinate
            
            // 現在地表示
            let rect: MKCoordinateSpan = MKCoordinateSpanMake(0.05,0.05)
            let region: MKCoordinateRegion = MKCoordinateRegionMake(centerCordinate, rect)
            
            mapView.setRegion(region, animated: true)
            
            initMap = true
        }
        
        if(self.isAutoCaptureMode)
        {
            // 前回の位置から離れたか判断して、離れている場合はキャプチャの保存を実行する
            var isPost = false;
            
            if(lastLocation != nil && lastPostLocation != nil)
            {
                let cur = CLLocation(latitude: self.lastLocation!.latitude,longitude:self.lastLocation!.longitude)
                let twd = CLLocation(latitude: self.lastPostLocation!.latitude,longitude:self.lastPostLocation!.longitude)
                
                let dist = cur.distance(from: twd)
                print("Diff:\(dist)")
                
                if(dist > Double(range!))
                {
                    isPost = true
                }
            }
            else
            {
                isPost = true
            }
            
            if isPost
            {
                self.doCapture(manualMode: false)
            }
        }
        
        
//        // 表示範囲のPinを表示する（仮置き）
//        self.mapView.removeAnnotations(mapView.annotations) // 一旦全消し
//        
//        let northWest = CGPointMake(self.mapView.bounds.origin.x,self.mapView.bounds.origin.y);
//        let nwCoord = mapView.convertPoint(northWest,toCoordinateFromView: mapView)
//
//        let southEast = CGPointMake(mapView.bounds.origin.x+mapView.bounds.size.width,mapView.bounds.origin.y+mapView.bounds.size.height);
//        let seCoord = mapView.convertPoint(southEast,toCoordinateFromView: self.mapView)
//        
//        let pr = NSPredicate(format:"latitude > %d and %d > latitude and longiture > %d and %d > longiture",nwCoord.latitude,seCoord.latitude,nwCoord.longitude,seCoord.longitude)
//        
//        self.fetchCoreData(pr)
//        
        
    }
}

