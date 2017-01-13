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
    var isAutoCaptureMode:Bool = false  //自動撮影モード
    
    let locationManager:CLLocationManager = CLLocationManager()
    var initMap = false
    var lastLocation:CLLocationCoordinate2D?
    var address:String?
    
    var myPhoto_global:MyPhoto?     //プレビュー表示時に一時保存する場所
    var isPreviewMode = false       //プレビュー未確定フラグ
    var isManualCapture = false       //マニュアル撮影かどうか
    
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
    var range:Int = 1000
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
    @IBAction func btnCurrentLoactionAction(_ sender: Any) {
        let centerCordinate: CLLocationCoordinate2D = self.mapView.userLocation.coordinate
        
        // 現在地表示
        let rect: MKCoordinateSpan = MKCoordinateSpanMake(0.05,0.05)
        let region: MKCoordinateRegion = MKCoordinateRegionMake(centerCordinate, rect)
        
        mapView.setRegion(region, animated: true)
        mapView.setUserTrackingMode(MKUserTrackingMode.follow, animated: true)

    }
    
    @IBAction func btnConfig(_ sender: AnyObject) {

        //Configに遷移する時にAutoモードをOFFにする
        self.isAutoCaptureMode = false
        self.labelLog.text = "■ Auto Shot : Stopped"
        
        //self.btnAutoCapture.setTitle("● Start Capture", for: UIControlState())
        self.btnAutoCapture.setImage(#imageLiteral(resourceName: "start_shoot"), for: UIControlState())
        self.btnAutoCapture.imageView?.contentMode = UIViewContentMode.scaleAspectFit
        
        performSegue(withIdentifier: "configSegue", sender: sender)
    }
    
    @IBAction func btnCapture(_ sender: AnyObject) {
        self.doManualCapture()
    }
    
    @IBAction func btnAutoCapture(_ sender: AnyObject) {
        
        if(self.isAutoCaptureMode == false)
        {
            self.isAutoCaptureMode = true
            self.labelLog.text = "● Auto Shoot : detecting distance.."
            
            UIApplication.shared.isIdleTimerDisabled = true
            
            let button = sender as! UIButton
            //button.setTitle("■ Stop Capture", for: UIControlState())
            button.setImage(#imageLiteral(resourceName: "stop_shoot"), for: UIControlState())
            button.imageView?.contentMode = UIViewContentMode.scaleAspectFit
            
            //開始位置を原点とする
            lastPostLocation = lastLocation
        }
        else
        {
            self.isAutoCaptureMode = false
            self.labelLog.text = "■ Auto Shoot : Stopped"

            UIApplication.shared.isIdleTimerDisabled = false
            
            let button = sender as! UIButton
            //button.setTitle("● Start Capture", for: UIControlState())
            button.setImage(#imageLiteral(resourceName: "start_shoot"), for: UIControlState())
            button.imageView?.contentMode = UIViewContentMode.scaleAspectFit

        }
    }

    // MARK: - Methods
    // MARK: 静止画を取得する
    func getCaptureImage()->Data {
        //画像添付
        var imageData:Data? = nil
        if isAvailableVideo {
            
            if (session != nil) {
                self.session!.stopRunning()
                imageData = UIImageJPEGRepresentation(self.imageViewVideo.image!,1)!
                //imageData = UIImageJPEGRepresentation(self.preView.toImage()!,1)
                self.session!.startRunning()
            }
            
        }
        
        if (imageData == nil)
        {
            imageData = UIImageJPEGRepresentation(UIImage(named: "neko.png")!,1)!
        }

        return imageData!
    }
    
    // MARK: 手動で撮影する
    func doManualCapture()
    {
        print("doManualCapture")
        
        if(lastLocation?.latitude == 0.0 && lastLocation?.longitude == 0.0)
        {
            let alert:UIAlertController = UIAlertController(title:"Location Error",
                                                            message: "Please wait for initialize location.",
                                                            preferredStyle: UIAlertControllerStyle.alert)
            
            let cancelAction  = UIAlertAction(title: "OK",
                                                           style: UIAlertActionStyle.cancel,
                                                           handler:{
                                                            (action:UIAlertAction!) -> Void in
                                                            print("OK")
            })
            alert.addAction(cancelAction)
            self.present(alert, animated: true, completion: nil)
            
            return
        }

        if(self.isPreviewMode == true){return}  //プレビュー中は新たな画像を撮影しない
        self.isPreviewMode = true
        
        let image = self.getCaptureImage()
        
        let mp = MyPhoto()
        if let t = self.address { mp.address = t}
        
        if let t = self.lastLocation {
            mp.latitude = t.latitude as NSNumber?
            mp.longiture = t.longitude as NSNumber?
        }
        mp.image = image
        mp.photoid = UUID().uuidString
        mp.date = Date()

        self.myPhoto_global = mp    //グローバルに一時保存
        self.isManualCapture = true
        
        self.capturedImage = UIImage.init(data: image) //for preview
        self.performSegue(withIdentifier: "previewSegue", sender: nil)
    }

    // MARK: 自動で撮影する（一定距離毎に呼ばれる）
    func doAutoCapture()
    {
        print("doAutoCapture")
        
        if(self.isPreviewMode == true){return}  //プレビュー中は新たな画像を撮影しない
        isPreviewMode = true
        
        let image = self.getCaptureImage()
        
        let mp = MyPhoto()
        if let t = self.address { mp.address = t}
        
        if let t = self.lastLocation {
            mp.latitude = t.latitude as NSNumber?
            mp.longiture = t.longitude as NSNumber?
        }
        mp.image = image
        mp.photoid = UUID().uuidString
        mp.date = Date()

        self.myPhoto_global = mp    //グローバルに一時保存
        self.isManualCapture = false
        
        self.capturedImage = UIImage.init(data: image) //for preview
        self.performSegue(withIdentifier: "previewSegue", sender: nil)
    }

    // 撮影を確定する（プレビュー表示後）
    func confirmCapture(mp:MyPhoto)
    {
        self.saveToCoreData(mp:mp)

        // Postした位置を記録して次回の距離差分判定に使用する
        lastPostLocation = lastLocation

        if(self.isRelationToTwitter)
        {
            self.postTweet((mp.image)!)
        }

        self.setPin(mp: mp)
    }

    // MARK:Pinを立てる
    func setPin(mp:MyPhoto)
    {
        let format = DateFormatter()
        format.dateFormat = "yyyy-MM-dd HH:mm"
        
        let pin = MyAnnotation(location: CLLocationCoordinate2DMake(mp.latitude as! CLLocationDegrees, mp.longiture as! CLLocationDegrees))
        pin.identity = mp.photoid
        pin.title = format.string(from: mp.date! as Date)
        pin.subtitle = mp.address!
        
        mapView.addAnnotation(pin)
    }
    
    // MARK:CoreDataにセーブする
    func saveToCoreData(mp:MyPhoto)
    {
        // Save Data to CoreData
        let photo = Photo( entity: entryDescription, insertInto: managedContext)
        
        photo.address = mp.address
        photo.latitude = mp.latitude
        photo.longiture = mp.longiture
        photo.image = mp.image
        photo.photoid = mp.photoid
        photo.date = mp.date
        
        do {
            try managedContext.save()
        } catch let error as NSError  {
            print("Could not save \(error), \(error.userInfo)")
        }
    }
    
    // MARK: Twitterに投稿する
    fileprivate func postTweet(_ imageData:Data) {
        // ツイートしたい文章をセット
        //var status = "\(range)m間隔でTweet中 "
        var status = ""
        if let t = address
        {
            status = t + " #DrivingCamera"
        }
        
        Util.doTweet(status,imageData: imageData, location: lastLocation)
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
        //locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        
        // 位置情報取得間隔の指定
        locationManager.distanceFilter = 50.0
        //locationManager.distanceFilter = 100.0
        
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
        
        // CoreData Load
        self.fetchCoreData(nil)
    }
    
    // メモリ管理のため
    override func viewWillAppear(_ animated: Bool) {
    }
    
    // メモリ管理のため
    override func viewDidDisappear(_ animated: Bool) {
 
        UIApplication.shared.isIdleTimerDisabled = false
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //MARK: - CoreData関連Methods
    //MARK: CoreDataからデータ読み込み（全データ）してPinを立てる
//    func fetchCoreData() {
//        self.fetchCoreData(nil)
//    }
    
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
            format.dateFormat = "yyyy-MM-dd HH:mm"
            
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
        if let t = fetchPhotoData(photoid) {
            return UIImage(data: t.image!)!
        }
        else
        {
            return UIImage(named: "neko.png")!
        }
    }

    func fetchPhotoData(_ photoid:String) -> Photo?
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
        
        return photos[0]
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
                    if let photo = self.fetchPhotoData(t)
                    {
                        photoViewCon.myPin = myPin

                        let mp = MyPhoto()
                        mp.address = photo.address
                        mp.image = photo.image
                        mp.latitude = photo.latitude
                        mp.longiture = photo.longiture
                        
                        photoViewCon.mp = mp
                    }
                }
            }
            else if identifier == "previewSegue"
            {
                let previewCon = segue.destination as! PreviewViewController
                previewCon.mp = myPhoto_global
                previewCon.isManualCapture = self.isManualCapture
            }
        }
        else
        {
            print("no segue identifier")
        }
    }
    
    // MARK: - カメラとストリーミングのセットアップ
    func configureCamera()
    {
        session = AVCaptureSession()
        //session.sessionPreset = AVCaptureSessionPresetMedium
        session.sessionPreset = AVCaptureSessionPresetHigh

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
    
    // MARK: - 緯度経度から住所を求める
    func reverseGeoCode(_ location2D:CLLocationCoordinate2D)
    {
        if(location2D.latitude == 0.0 && location2D.longitude == 0.0)
        {
            self.labelAddress.text = "initializing location.."
            return
        }
        
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: location2D.latitude, longitude: location2D.longitude)
        
        geocoder.reverseGeocodeLocation(location,
                                        completionHandler: { (placemarks, error) -> Void in
                                            
                                            if placemarks == nil
                                            {
                                                self.address = ""
                                                self.labelAddress.text = "fetching address.."
                                            }
                                            else
                                            {
                                                for placemark in placemarks! {
                                                    
                                                    /*
                                                     print("Name: \(placemark.name)")
                                                     print("Country: \(placemark.country)")
                                                     print("thoroughfare: \(placemark.thoroughfare)")
                                                     print("administrativeArea: \(placemark.administrativeArea)")
                                                     print("subAdministrativeArea: \(placemark.subAdministrativeArea)")
                                                     print("Locality: \(placemark.locality)")
                                                     print("PostalCode: \(placemark.postalCode)")
                                                     print("areaOfInterest: \(placemark.areasOfInterest)")
                                                     print("Ocean: \(placemark.ocean)")
                                                    */
                                                    
                                                    var ads:String = "";
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
    @IBAction func unwindActionFromPreview(_ segue: UIStoryboardSegue) {
        print("unwindActionFromPreview!")
        
        let previewCon = segue.source as! PreviewViewController
        self.confirmCapture(mp: previewCon.mp!)
        
        self.isPreviewMode = false
    }
    
    
    @IBAction func unwindAction(_ segue: UIStoryboardSegue) {
        // とりあえず空
        print(segue.identifier!)

        if segue.identifier == "UnwindConfig"
        {
            let ud = UserDefaults()
            
            if let t:Int = ud.integer(forKey: "TweetRange") as Int?
            {
                range = Util.DistRangeIdxToMeter(t)
                print("%d",range)
                //labelLog.text = String("\(range)m")
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
            print("not use unwind save -> see unwindActionFromPreview")
            
            /*
            let previewCon = segue.source as! PreviewViewController
            self.confirmCapture(mp: previewCon.mp!)

            self.isPreviewMode = false
            */
        }
        else if segue.identifier == "UnwindPreviewCancel"
        {
            print("UnwindPreviewCancel")
            
            //プレビュー終了
            self.isPreviewMode = false
            
            //自動撮影時は、キャンセル時でも撮影距離をリセットする
            if(self.isManualCapture == false)
            {
                lastPostLocation = lastLocation
            }
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
        
        //lastLocation = self.mapView.userLocation.coordinate
        lastLocation = manager.location?.coordinate
        
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
                
                let dist = cur.distance(from: twd)  // 前回撮影（またはプレビューキャンセル）した場所からどのくらい離れたか
                print("Diff:\(dist)")
                
                let remainDistance = Double(range) - dist
                self.labelLog.text = "● Auto Shooting : last \(String(format:"%.1f",remainDistance))m"
                
                if(remainDistance <= 0)
                {
                    isPost = true
                }
            }
            else
            {
                // ここに来るかは要検討
                isPost = true
            }
            
            if isPost
            {
                self.doAutoCapture()
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

