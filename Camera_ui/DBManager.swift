//
//  DBManager.swift
//  FMDBTut
//
//  Created by Chan Hong Wing on 30/3/2017.
//  Copyright © 2017年 Appcoda. All rights reserved.
//
//http://www.appcoda.com.tw/fmdb-sqlite-database/

import UIKit
import FMDB

class DBManager: NSObject {
    //Singleton 唯一的對象
    static let shared: DBManager = DBManager()
    //數據庫檔案名
    let databaseFileName = "database.sqlite"
    //數據庫檔案路徑
    var pathToDatabase: String!
    //一個 FMDatabase 物件 (來自 FMDB 庫)，通過它來訪問和操作真正的數據庫
    var database: FMDatabase!
    
    let imageTag_tableName = "imageTagTable"
    let field_ImageID = "imageID"
    let field_ImageTag = "imageTag"
    
    let tagDictionary_tableName = "tagDictionaryTable"
    let field_tagName = "tagName"

    
    override init() {
        super.init()
        //將數據庫路徑指定為 documents 目錄 + 數據庫檔案名
        let documentsDirectory = (NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString) as String
        pathToDatabase = documentsDirectory.appending("/\(databaseFileName)")
    }
    
    //用於表示數據庫是否創建成功
    func createDatabase() -> Bool {
        var created = false
        
        if !FileManager.default.fileExists(atPath: pathToDatabase) {
            database = FMDatabase(path: pathToDatabase!)
            
            if database != nil {
                // 創造數據庫
                if database.open() {
                    
                    let createImageTagTableQuery = "CREATE TABLE \(imageTag_tableName) ( \(field_ImageID) TEXT NOT NULL, \(field_ImageTag) TEXT NOT NULL, PRIMARY KEY(\(field_ImageID)) );"
                    let createTagDictionaryTableQuery = "CREATE TABLE \(tagDictionary_tableName) ( \(field_tagName) TEXT, PRIMARY KEY(\(field_tagName)) );"
                    
                    let query = createImageTagTableQuery + createTagDictionaryTableQuery;
                    
                    if database.executeStatements(query) {
                        created = true
                    }else{
                        print("Failed to insert initial data into the database.")
                        print(database.lastError(), database.lastErrorMessage())
                    }
                    database.close()
                    
                    //做到 "一些建議" 個part
                }
                else {
                    print("Could not open the database.")
                }
            }
        }
        return created
    }
    
    //打開數據庫
    func openDatabase() -> Bool {
        if database == nil {
            if FileManager.default.fileExists(atPath: pathToDatabase) {
                database = FMDatabase(path: pathToDatabase)
                print("database path: ",pathToDatabase)
            }
        }
        
        if database != nil {
            //嘗試打開數據庫
            if database.open() {
                return true
            }
        }
        
        return false
    }
    
    func insertImageType_imageTagTable(imageID:String?=nil, imageTag:String?=nil) {
        if openDatabase(){
            
            let query = "insert into \(imageTag_tableName) (\(field_ImageID), \(field_ImageTag)) values (?,?);"
            do {
                try database.executeUpdate(query, values: [imageID!,imageTag!])
                database.close()

            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    func insertImageType_tagDictionaryTable(tag:String?=nil) {
        if openDatabase(){
            
            let query = "insert into \(tagDictionary_tableName) (\(field_tagName)) values (?);"
            do {
                try database.executeUpdate(query, values: [tag!])
                database.close()
                
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    

    
    func deleteTagDictionary(tag: String){
        if openDatabase() {
            let query = "delete from \(tagDictionary_tableName) where \(field_tagName)=?"
            
            do {
                try database.executeUpdate(query, values: [tag])
            }
            catch {
                print(error.localizedDescription)
            }
            database.close()
        }
    }
    
    func loadAllRow_TagDictionaryTableDara() -> [String]!{
        var tagArray:[String] = []

        if openDatabase() {
            let query = "select * from tagDictionaryTable;"
            do {
                let results = try database.executeQuery(query, values: nil)
                while results.next(){
                    let tag:String = results.string(forColumn: field_tagName)
                    tagArray.append(tag)
                }
            } catch {
                print(error.localizedDescription)
            }
            database.close()
        }
        return tagArray
    }
    
    func load_ID_imageTagTable(tag:String) -> [String]!{
        var idArray:[String] = []
        
        if openDatabase() {
            let query = "select \(field_ImageID) from \(imageTag_tableName) where \(field_ImageTag) LIKE ?;"
            do {
                let results = try database.executeQuery(query, values: ["%\(tag)%"])
                while results.next(){
                    let id:String = results.string(forColumn: field_ImageID)
                    idArray.append(id)
                }
            } catch {
                print(error.localizedDescription)
            }
            database.close()
        }
        print(idArray)
        return idArray
    }
    
    func show_ImageTagTableDara() {
        if openDatabase(){
            let query = "select * from \(imageTag_tableName);"
            do {
                let results = try database.executeQuery(query, values: nil)
                
                //print table style http://stackoverflow.com/questions/28138689/format-println-output-in-a-table
                //Establish column widths
                let column1PadLength = 50
                let columnDefaultPadLength = 12
                
                let headerString = "ID".padding(toLength: column1PadLength, withPad: " ", startingAt: 0) + "Tag".padding(toLength: columnDefaultPadLength, withPad: " ", startingAt: 0)
                let lineString = "".padding(toLength: headerString.characters.count, withPad: "-", startingAt: 0)
                
                print("\(headerString)\n\(lineString)")
                
                while results.next(){
                    let id:String = results.string(forColumn: field_ImageID)
                    let tag:String = results.string(forColumn: field_ImageTag)
                    
                    let dataString = id.padding(toLength: column1PadLength, withPad: " ", startingAt: 0) +
                        tag.padding(toLength: columnDefaultPadLength, withPad: " ", startingAt: 0)
                    print("\(dataString)")
                }
                print("\(lineString)")
                
            } catch {
                print(error.localizedDescription)
            }
            database.close()
        }
    }
    
    func show_TagDictionaryTableDara() {
        if openDatabase(){
            let query = "select * from tagDictionaryTable;"
            do {
                let results = try database.executeQuery(query, values: nil)
                
                //print table style http://stackoverflow.com/questions/28138689/format-println-output-in-a-table
                //Establish column widths
                let column1PadLength = 8
                
                let headerString = "Tag".padding(toLength: column1PadLength, withPad: " ", startingAt: 0)
                let lineString = "".padding(toLength: headerString.characters.count, withPad: "-", startingAt: 0)
                
                print("\(headerString)\n\(lineString)")
                
                while results.next(){
                    let tag:String = results.string(forColumn: field_tagName)
                    let dataString = tag.padding(toLength: column1PadLength, withPad: " ", startingAt: 0)
                    print("\(dataString)")
                }
                print("\(lineString)")
                
            } catch {
                print(error.localizedDescription)
            }
            database.close()
        }
    }
    
    func removeAllData_imageTagTable(){
        if openDatabase() {
            let query = "DELETE FROM \(imageTag_tableName)"
            do {
                _ = try database.executeUpdate(query, values: nil)
            } catch {
                print(error.localizedDescription)
            }
            database.close()
        }
    }
    

}
