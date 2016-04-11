// JsonDB
//
// Copyright (c) 2014 Pierre-David Bélanger <pierredavidbelanger@gmail.com>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation
import XCTest

class SwiftSpec: XCTestCase {
    
    func testSwiftUseCase() throws {
        
        // TODO: quick fixed to compile and run with success, but this is a mess. Rewrite in good Swift.  
        
        let dbPath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent("/JsonDB_Swift_db.sqlite")
        if NSFileManager.defaultManager().fileExistsAtPath(dbPath) {
            try NSFileManager.defaultManager().removeItemAtPath(dbPath)
        }
        
        let db = JDBDatabase(atPath: dbPath, withOptions: [JDBDatabaseOptionVerboseKey: 1])
        XCTAssertNotNil(db)
        XCTAssertEqual(db.collectionNames().count, 0)
        
        let collection = db.collection("test")
        XCTAssertNotNil(collection)
        XCTAssertEqual(db.collectionNames().count, 1)
        
        let usersData = NSData(contentsOfURL: NSBundle(forClass: SwiftSpec.self).URLForResource("users", withExtension: "json")!)
        let users: Array<[String : AnyObject]> = try NSJSONSerialization.JSONObjectWithData(usersData!, options:NSJSONReadingOptions()) as! Array<[String : AnyObject]>
        for user in users {
            collection.save(user)
        }
        XCTAssertEqual(collection.find(nil).count(), 100 as UInt)
        
        let view = collection.viewForPaths(["isActive", "name", "age", "tags"])
        XCTAssertNotNil(view)
        
        let criteria = ["isActive": false, "name": ["$like": "Mari%"], "age": ["$ge": 40], "tags": ["$in": ["consequat"]]]
        let query = view.find(criteria)
        XCTAssertNotNil(query)
        
        let projectionResults = query.allAndProjectKeyPaths(["isActive", "name", "age", "tags"]);
        XCTAssertEqual(projectionResults.count, 1)
        //XCTAssertEqual(projectionResults[0]["name"] as String, "Maricela Todd")
        
        var document = query.first() as! [String : AnyObject]
        XCTAssertNotNil(document)
        XCTAssertEqual(document["company"] as? String, "VERTIDE")
        
        document = collection.find(criteria).firstAndModify { (document) -> JDBModifyOperation in
            return JDBModifyOperation.Remove.union(JDBModifyOperation.ReturnOld)
        } as! [String : AnyObject]
        XCTAssertNotNil(document)
        XCTAssertEqual(document["index"] as? Int, 0)
        XCTAssertEqual(query.count(), 0 as UInt)
    }
}
