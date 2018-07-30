//
//  CollectionViewController.swift
//  PhotoKit_ex1
//
//  Created by Chan Hong Wing on 21/2/2017.
//  Copyright © 2017年 Chan Hong Wing. All rights reserved.
//
//http://www.hangge.com/blog/cache/detail_1233.html
//https://www.youtube.com/watch?v=8xf-NztULEY&t=66s
import UIKit
import Photos
import SwiftPhotoGallery

class CollectionViewController: UICollectionViewController {
    
    //Search Bar
    let searchBar:UISearchBar = UISearchBar()
    //Variables added for search function
//    var filteredAssetsFetchResults:PHFetchResult<PHAsset>! = nil
    var shouldShowSearchResults = false
    
    ///取得的資源结果，用了存放的PHAsset
    var assetsFetchResults:PHFetchResult<PHAsset>!
    var myImageArray:[UIImage]!
    
    ///圖片-縮略圖大小
    var assetGridThumbnailSize:CGSize!
    
    /// 帶緩存的圖片管理對象
    var imageManager:PHCachingImageManager!

    override func viewDidLoad() {
        super.viewDidLoad()
        setCollectionCell()
        createSearchBar()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        getPHAsset(type: 1)
        self.collectionView?.reloadData()
        //根據單元格的尺寸計算我們需要的縮略圖大小
        let scale = UIScreen.main.scale
        let cellSize = (self.collectionViewLayout as! UICollectionViewFlowLayout).itemSize
        assetGridThumbnailSize = CGSize(width:cellSize.width*scale ,
                                        height:cellSize.height*scale)
        //由底部開始 http://stackoverflow.com/questions/21800400/start-uicollectionview-at-bottom
//        let contentSize:CGSize = (self.collectionView?.collectionViewLayout.collectionViewContentSize)!
//        if (contentSize.height > (self.collectionView?.bounds.size.height)!) {
//            let point = CGPoint(x: 0,y :contentSize.height - (self.collectionView?.bounds.size.height)!)
//            collectionView?.contentOffset = point
//        }
    }
    
    
    
    func getPHAsset(type:Int,sortID:[String]?=nil){
        
        //獲取所有資源
        let allPhotosOptions = PHFetchOptions()
        //按照創建時間倒序排列
        allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate",
                                                             ascending: false)]
        //只獲取圖片 unknown = 0 image = 1  video = 2 audio = 3
        allPhotosOptions.predicate = NSPredicate(format: "mediaType = %d",
                                                 type)
        if sortID != nil {
                allPhotosOptions.predicate = NSPredicate(format: "localIdentifier IN %@", sortID!)
        }
        
        assetsFetchResults = PHAsset.fetchAssets(with: PHAssetMediaType.image,
                                                 options: allPhotosOptions)
        // 初始化和重置緩存
        self.imageManager = PHCachingImageManager()
        self.resetCachedAssets()
        
    }
    
    //重置缓存
    func resetCachedAssets(){
        self.imageManager.stopCachingImagesForAllAssets()
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.assetsFetchResults.count
    }

    //CollectionView行數
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let identify:String = "Cell"
        let cell = (self.collectionView?.dequeueReusableCell(withReuseIdentifier: identify, for: indexPath))! as UICollectionViewCell
        let asset = self.assetsFetchResults[indexPath.row]
    
//        print("localIdentifier ",self.assetsFetchResults[0].localIdentifier)

        //縮略圖
            self.imageManager.requestImage(for: asset, targetSize: assetGridThumbnailSize,
                                           contentMode: PHImageContentMode.aspectFit,
                                           options: nil) { (image, nfo) in
                                            (cell.contentView.viewWithTag(1) as! UIImageView).image = image
                                            
//                                            print(image!)
            }
        return cell
    }
    // 單元格點擊響應
    override func collectionView(_ collectionView: UICollectionView,
                                 didSelectItemAt indexPath: IndexPath) {
        print("didSelectItemAt")

        let gallery = SwiftPhotoGallery(delegate: self, dataSource: self)
        
        gallery.backgroundColor = UIColor.black
        gallery.pageIndicatorTintColor = UIColor.gray.withAlphaComponent(0.5)
        gallery.currentPageIndicatorTintColor = UIColor(red: 0.0, green: 0.66, blue: 0.875, alpha: 1.0)
        gallery.hidePageControl = false
        gallery.modalPresentationStyle = .custom
        
        self.present(gallery, animated: false, completion: { () -> Void in
            gallery.currentPage = indexPath.row
        })
    }
    }
extension CollectionViewController:UISearchBarDelegate{

    func createSearchBar(){
        searchBar.showsCancelButton = false
        searchBar.placeholder = "Enter your search here!"
        searchBar.delegate = self
        self.navigationItem.titleView = searchBar
    }
    
    override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        searchBar.endEditing(true)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.endEditing(true)
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty{
            getPHAsset(type: 1)
        }else{
            let idArray: [String]? = DBManager.shared.load_ID_imageTagTable(tag: searchText)
            print("idArrat: ",idArray ?? "00000")
            getPHAsset(type: 1, sortID: idArray)
        }
        self.collectionView?.reloadData()
    }
}

extension CollectionViewController{
    
    func setCollectionCell(){
        //方法1：讓單元格寬度動態變化
        //http://www.hangge.com/blog/cache/detail_762.html
        let layout = self.collectionViewLayout as! UICollectionViewFlowLayout
        //間隔
        let spacing:CGFloat = 2
        //水平間隔
        layout.minimumInteritemSpacing = spacing
        //垂直行間距
        layout.minimumLineSpacing = spacing
        //列數
        let columnsNum = 4
        //整個view的寬度
        let collectionViewWidth = self.collectionView!.bounds.width
        //計算單元格的寬度
        let itemWidth = ((collectionViewWidth - spacing * CGFloat(columnsNum-1)) / CGFloat(columnsNum))
        //設置單元格寬度和高度
        layout.itemSize = CGSize(width:itemWidth, height:itemWidth)
    }
    
}

// MARK: SwiftPhotoGalleryDataSource Methods
extension CollectionViewController: SwiftPhotoGalleryDataSource {
    
    func numberOfImagesInGallery(gallery: SwiftPhotoGallery) -> Int {
        print("CollectionViewController___numberOfImagesInGallery")
        return self.assetsFetchResults.count
    }
    
    func imageInGallery(gallery: SwiftPhotoGallery, forIndex: Int) -> UIImage? {
        print("CollectionViewController___imageInGallery")

        print("forIndex: ",forIndex)
        let myAsset = self.assetsFetchResults[forIndex]
        return getThumbnail(asset: myAsset)
    }
    
    //http://stackoverflow.com/questions/38283416/while-converting-phasset-to-uiimage-losing-transparency
    func getThumbnail(asset: PHAsset) -> UIImage? {
        
        var thumbnail: UIImage?
        
        let manager = PHImageManager.default()
        
        let options = PHImageRequestOptions()
        
        options.version = .original
        options.isSynchronous = true
        
        manager.requestImageData(for: asset, options: options) { data, _, _, _ in
            
            if let data = data {
                thumbnail = UIImage(data: data)
            }
        }
        return thumbnail
    }

}

// MARK: SwiftPhotoGalleryDelegate Methods
extension CollectionViewController: SwiftPhotoGalleryDelegate {
    
    func galleryDidTapToClose(gallery: SwiftPhotoGallery) {
        dismiss(animated: true, completion: nil)        
    }
    
    func barItem_add_OnClick(currentPage:Int){
        print("currentPage: ",currentPage)
        print("addID: ",assetsFetchResults[currentPage].localIdentifier)

    }
    func barItem_share_OnClick(currentPage:Int){
        print("currentPage: ",currentPage)
        
//        // image to share
//        let image = self.getThumbnail(asset: assetsFetchResults[currentPage])
//        
//        // set up activity view controller
//        let imageToShare = [ image! ]
//        let activityViewController = UIActivityViewController(activityItems: imageToShare, applicationActivities: nil)
//        activityViewController.popoverPresentationController?.sourceView = self.view // so that iPads won't crash
//        
//        // exclude some activity types from the list (optional)
//        activityViewController.excludedActivityTypes = [ UIActivityType.airDrop, UIActivityType.postToFacebook ]
//        
//        // present the view controller
//        if presentedViewController == nil {
//            self.present(activityViewController, animated: true, completion: nil)
//        } else{
//            self.dismiss(animated: false) { () -> Void in
//                self.present(activityViewController, animated: true, completion: nil)
//            }
//        }
        
    }
    
}


