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

class ViewController: UIViewController,CLLocationManagerDelegate,MKMapViewDelegate,AVCaptureVideoDataOutputSampleBufferDelegate {

    // MARK: - プロパティ
    //var timer:NSTimer!
    var isAutoCaptureMode:Bool! = false
    
    let locationManager:CLLocationManager = CLLocationManager()
    var initMap = false
    var lastLocation:CLLocationCoordinate2D?
    var captureSession:AVCaptureSession!
    
    var preView:UIView?
    
    var address:String?
    
    
    
    // Videoが使用可能かどうか
    var isAvailableVideo = true
    
    // Twitter Param
    var lastPostLocation:CLLocationCoordinate2D?
    var range:Int!
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
    @IBAction func btnConfig(sender: AnyObject) {
        performSegueWithIdentifier("configSegue", sender: sender)
    }
    
    @IBAction func btnCapture(sender: AnyObject) {
        self.doCapture()
    }
    
    @IBAction func btnAutoCapture(sender: AnyObject) {
        
        if(self.isAutoCaptureMode == false)
        {
            self.isAutoCaptureMode = true
            
            let button = sender as! UIButton
            button.setTitle("Stop Capture", forState: UIControlState.Normal)
        }
        else
        {
            self.isAutoCaptureMode = false
            
            let button = sender as! UIButton
            button.setTitle("Start Capture", forState: UIControlState.Normal)
        }
    }
    
    // MARK: - Methods
    // MARK: キャプチャの保存を実行する
    func doCapture()
    {
        print("doCapture")
        
        //画像添付
        var imageData:NSData!
        if isAvailableVideo {
            self.captureSession.stopRunning()
            imageData = UIImageJPEGRepresentation(self.imageViewVideo.image!,1)!
            self.captureSession.startRunning()
        }
        else
        {
            imageData = UIImageJPEGRepresentation(UIImage(named: "neko.png")!,1)!
        }

        // Save Data to CoreData
        let photo = Photo(entity: entryDescription, insertIntoManagedObjectContext: managedContext)
        
        if let t = self.address { photo.address = t}
        photo.latitude = lastLocation!.latitude
        photo.longiture = lastLocation!.longitude
        photo.image = imageData
        photo.photoid = NSUUID().UUIDString
        photo.date = NSDate()
        
        do {
            try managedContext.save()
        } catch let error as NSError  {
            print("Could not save \(error), \(error.userInfo)")
        }
        
        if(self.isRelationToTwitter)
        {
            self.postTweet(imageData)
        }
        
        if let t:CLLocationCoordinate2D = lastLocation
        {
            let format = NSDateFormatter()
            format.dateFormat = "yyyy-MM-dd HH:mm:ss"

            let pin = MyAnnotation(location: t)
            pin.identity = photo.photoid
            pin.title = format.stringFromDate(photo.date!)
            pin.subtitle = photo.address!
            
            // 地図にピンを立てる
            mapView.addAnnotation(pin)
        }
        
        // Postした位置を記録して次回の距離差分判定に使用する
        lastPostLocation = lastLocation
        
    }
    
    // MARK: - ViewController Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // CoreData
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        managedContext = appDelegate.managedObjectContext
        entryDescription =  NSEntityDescription.entityForName("Photo",inManagedObjectContext:managedContext)
        
        let defaults = NSUserDefaults()
        
        //Tweet間隔読み込み
        if let t:Int = defaults.integerForKey("TweetRange")
        {
            range = Util.DistRangeIdxToMeter(t)
        }
        else
        {
            range = 50;
        }
        
        locationManager.delegate = self

        // 測位の精度を 100ｍ とする
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        
        // 位置情報取得間隔の指定
        locationManager.distanceFilter = 50.0
        
        // 用途の指定
        locationManager.activityType = CLActivityType.AutomotiveNavigation
        
        // 位置情報サービスへの認証状態を取得する
        let status = CLLocationManager.authorizationStatus()
        if status == CLAuthorizationStatus.NotDetermined {
            // 未認証ならリクエストダイアログ出す
            locationManager.requestWhenInUseAuthorization();
        }
        locationManager.startUpdatingLocation()
        
        // MapView設定
        mapView.delegate = self
        mapView.setUserTrackingMode(MKUserTrackingMode.Follow, animated: true)
        
        // ビデオ画像ストリーミング開始
        self.configureCamera()
        
        // CoreData Load Test
        self.fetchCoreData()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
        
    // MARK: 画像をキャプチャーしてTwitterに投稿し、Pinを立てる
    private func postTweet(imageData:NSData) {
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
    
    func fetchCoreData(predicate:NSPredicate?)
    {
        let fetchRequest = NSFetchRequest(entityName: "Photo")

        if let t = predicate {
            fetchRequest.predicate = t
        }
        
        var photos = [Photo]()
        do {
            let results =
                try managedContext.executeFetchRequest(fetchRequest)
            photos = results as! [Photo]
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        
        for photo in photos {
            
            // imageはメモリを食うので、Pinを表示するタイミングで別途取得する
            let lat:Double = Double(photo.latitude!)
            let lon:Double = Double(photo.longiture!)
            let date:NSDate = photo.date!
            
            let format = NSDateFormatter()
            format.dateFormat = "yyyy-MM-dd HH:mm:ss"
            
            // ピンを作成する（identityを追加したカスタムクラスを使用する）
            let pin:MyAnnotation = MyAnnotation(location: CLLocationCoordinate2D(latitude: lat, longitude: lon))
            
            pin.title = format.stringFromDate(date)
            pin.subtitle = photo.address!
            pin.identity = photo.photoid
            
            // 地図にピンを立てる
            mapView.addAnnotation(pin)
        }
    }
    
    // MARK: photoidから画像を取得する
    func fetchImage(photoid:String) -> UIImage
    {
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        
        let predicate = NSPredicate(format: "photoid = %@",photoid)
        fetchRequest.predicate = predicate
        
        var photos = [Photo]()
        
        do {
            let results =
                try managedContext.executeFetchRequest(fetchRequest)
            photos = results as! [Photo]
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        
        return UIImage(data:photos[0].image!)!
    }
    
    //MARK: photoidをキーにして削除を行う
    func deleteCoreData(photoid:String)
    {
        let fetchRequest = NSFetchRequest(entityName: "Photo")

        let predicate = NSPredicate(format: "photoid = %@",photoid)
        fetchRequest.predicate = predicate
        
        do {
            let results = try managedContext.executeFetchRequest(fetchRequest)
            
            for result in results {
                managedContext.deleteObject(result as! NSManagedObject)
            }
            // 保存を忘れず
            try managedContext.save()
            
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
    }
    
    // MARK: - 遷移先の PhotoDetailViewControllerに値を渡して表示する
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let identifier = segue.identifier {
            if identifier == "PhotoDetailViewSegue" {

                let annotationView = sender as! MKAnnotationView
                let myPin = annotationView.annotation as! MyAnnotation

                let photoViewCon = segue.destinationViewController as! PhotoDetailViewController

                if let t = myPin.identity {
                    photoViewCon.photoImage = fetchImage(t)
                    photoViewCon.photoid = myPin.identity
                    photoViewCon.myPin = myPin
                    photoViewCon.address = myPin.subtitle                    
                }
            }
        }
    }
    
    // MARK: - カメラとストリーミングのセットアップ
    func configureCamera()
    {
        captureSession = AVCaptureSession()
        //captureSession.sessionPreset = AVCaptureSessionPresetMedium
        captureSession.sessionPreset = AVCaptureSessionPresetHigh
        
        var camera:AVCaptureDevice!
        var videoInput:AVCaptureDeviceInput! = nil
        
        // find back camera
        for caputureDevice: AnyObject in AVCaptureDevice.devices() {
            // 背面カメラを取得
            if caputureDevice.position == AVCaptureDevicePosition.Back {
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
        
        if captureSession.canAddInput(videoInput)
        {
            captureSession.addInput(videoInput)
        }

        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.setSampleBufferDelegate(self, queue:dispatch_get_main_queue())
        dataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey : Int(kCVPixelFormatType_32BGRA)
        ]
        captureSession.addOutput(dataOutput)
        
        /// preview test
        
        //スクリーンの幅
        let screenWidth = UIScreen.mainScreen().bounds.size.width;
        //スクリーンの高さ
        let screenHeight = UIScreen.mainScreen().bounds.size.height;
        // プレビュー用のビューを生成
        preView = UIView(frame: CGRectMake(0.0, 0.0, screenWidth, screenHeight))

        let captureVideoPreviewLayer:AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
        captureVideoPreviewLayer.frame = self.view.bounds;
        captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;

        let previewLayer:CALayer  = self.preView!.layer;
        previewLayer.masksToBounds = true
        previewLayer.addSublayer(captureVideoPreviewLayer);
        
        self.view.addSubview(self.preView!)
        ///
        
        captureSession.startRunning()
        
        do {
            
            if camera != nil
            {
                try camera.lockForConfiguration()
                // フレームレート
                camera.activeVideoMinFrameDuration = CMTimeMake(1, 15)
                
                camera.unlockForConfiguration()
            }
        } catch _ {
        }
    }
    
    // MARK: - 緯度経度から住所を求める
    func reverseGeoCode(location2D:CLLocationCoordinate2D)
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
    @IBAction func unwindAction(segue: UIStoryboardSegue) {
        // とりあえず空
        print(segue.identifier!)

        if segue.identifier == "UnwindConfig"
        {
            let ud = NSUserDefaults()
            
            if let t:Int = ud.integerForKey("TweetRange")
            {
                range = Util.DistRangeIdxToMeter(t)
                labelLog.text = String("\(range)m")
            }
            
            if let t:Bool = ud.boolForKey("RelationTwitter")
            {
                self.isRelationToTwitter = t
            }
        }
        else if segue.identifier == "UnwindPhotoDetail"
        {
            // Pinを削除する
            let photoDetailViewCon = segue.sourceViewController as! PhotoDetailViewController
            self.mapView.removeAnnotation(photoDetailViewCon.myPin!)
            
            // CoreDataから削除する
            self.deleteCoreData(photoDetailViewCon.myPin!.identity!)
        }
        
        
    }
    
    // MARK: - Delegates
    // MARK: Annotationが表示されるときに呼ばれる
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        
        if let myAnnotation = annotation as? MyAnnotation
        {
            print(myAnnotation.identity)
            
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
                image.drawInRect(CGRectMake(0, 0, size.width, size.height))
                
                let resizeImage = UIGraphicsGetImageFromCurrentImageContext()
                
                UIGraphicsEndImageContext()
                
                annotationView.annotation = myAnnotation
                
                // 描画した写真を設定する
                annotationView.image = resizeImage
                
                // タップした時に Callout(吹き出し)が表示されるようにする
                annotationView.canShowCallout = true
                
                // Callout(吹き出し)にディスクロージャを表示する
                annotationView.rightCalloutAccessoryView = UIButton(type: UIButtonType.DetailDisclosure)
                
                return annotationView
            }
        }
        return nil
    }
    
    // MARK: Callout(吹き出し)をタップした時に呼ばれる
    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        self.performSegueWithIdentifier("PhotoDetailViewSegue", sender: view)
        
        // Annotation を非選択にして Callout(吹き出し)を非表示にする
        mapView.deselectAnnotation(view.annotation, animated: true)
    }
    
    // MARK: キャプチャーの取得時に呼ばれる
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {

        //イメージバッファーの取得
        let buffer:CVImageBufferRef!
        buffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        
        //イメージバッファーのロック
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        
        // イメージバッファ情報の取得
        //var base: UInt8
        var width: size_t
        var height: size_t
        var bytesPerRow: size_t
        
        let base = UnsafeMutablePointer<UInt8>(CVPixelBufferGetBaseAddress(buffer));
        width = CVPixelBufferGetWidth(buffer);
        height = CVPixelBufferGetHeight(buffer);
        bytesPerRow = CVPixelBufferGetBytesPerRow(buffer);
        
        // ビットマップコンテキストの作成
        var colorSpace:CGColorSpaceRef!
        var cgContext:CGContextRef!
        colorSpace = CGColorSpaceCreateDeviceRGB();
        
        //let bitmapInfo:CGBitmapInfo = [.ByteOrder32Little, CGBitmapInfo(rawValue: ~CGBitmapInfo.AlphaInfoMask.rawValue | CGImageAlphaInfo.PremultipliedFirst.rawValue)]
        
        let bitmapInfo = CGBitmapInfo(rawValue: (CGBitmapInfo.ByteOrder32Little.rawValue | CGImageAlphaInfo.PremultipliedFirst.rawValue) as UInt32)
        
        cgContext = CGBitmapContextCreate(
            base,
            width,
            height,
            8,
            bytesPerRow,
            colorSpace,
            bitmapInfo.rawValue
        );
        
        //CGColorSpaceRelease(colorSpace);
        
        // 画像の作成
        var cgImage:CGImageRef!
        var image:UIImage!
        cgImage = CGBitmapContextCreateImage(cgContext);
        
        //image = [UIImage imageWithCGImage:cgImage scale:1.0f orientation:UIImageOrientationRight];
        image = UIImage(CGImage: cgImage, scale: 1.0, orientation: UIImageOrientation.Right);
        //CGImageRelease(cgImage);
        //CGContextRelease(cgContext);
        
        // イメージバッファのアンロック
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)));
        
        // 画像の表示
        imageViewVideo.image = image;
    }

    // MARK: 位置情報が更新された時に呼ばれる
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
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
        
        if(self.isAutoCaptureMode!)
        {
            // 前回の位置から離れたか判断して、離れている場合はキャプチャの保存を実行する
            var isPost = false;
            
            if(lastLocation != nil && lastPostLocation != nil)
            {
                let cur = CLLocation(latitude: self.lastLocation!.latitude,longitude:self.lastLocation!.longitude)
                let twd = CLLocation(latitude: self.lastPostLocation!.latitude,longitude:self.lastPostLocation!.longitude)
                
                let dist = cur.distanceFromLocation(twd)
                print("Diff:\(dist)")
                
                if(dist > Double(range))
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
                self.doCapture()
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

