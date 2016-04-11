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

#import <sqlite3.h>

SpecBegin(UseCase)

describe(@"jdb", ^{
    
    __block NSString *dbPath;
    
    beforeAll(^{
        dbPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"/JsonDB_UseCase_db.sqlite"];
        [[NSFileManager defaultManager] removeItemAtPath:dbPath error:nil];
        NSLog(@"dbPath: %@", dbPath);
    });

    it(@"should be simple to use for very simple use case", ^{
        
        // Create/open a database at the specified path
        JDBDatabase *database = [JDBDatabase databaseAtPath:dbPath];
        
        // Create/get a collection of document
        JDBCollection *collection = [database collection:@"GameScore"];
        
        // Insert schema less JSON documents into the collection
        [collection save:@{@"playerName": @"Sean Plott", @"score": @1337, @"cheatMode": @NO}];
        [collection save:@{@"playerName": @"John Smith", @"score": @9001, @"cheatMode": @NO}];
        [collection save:@{@"playerName": @"John Appleseed", @"score": @1234, @"cheatMode": @YES}];
        
        // Find who is cheating (this will returns an array of document)
        NSArray *cheaters = [[collection find:@{@"cheatMode": @YES}] all];
        expect(cheaters).to.haveCountOf(1);
        expect(cheaters[0][@"playerName"]).to.equal(@"John Appleseed");
        
        // Find the Johns ordered alphabetically
        NSArray *johns = [[collection find:@{@"playerName": @{@"$like": @"John %"}} sort:@[@"playerName"]] all];
        expect(johns).to.haveCountOf(2);
        expect(johns[0][@"playerName"]).to.equal(@"John Appleseed");

        // Find the first one with a score over 9000, flag it as a cheater and return the old document
        NSDictionary *over9000 = [[collection find:@{@"score": @{@"$gt": @9000}}] firstAndModify:^JDBModifyOperation(NSMutableDictionary *document) {
            document[@"cheatMode"] = @YES;
            return JDBModifyOperationUpdate | JDBModifyOperationReturnOld;
        }];
        expect(over9000[@"cheatMode"]).to.equal(NO);
    });

    it(@"should be simple to use for simple use case", ^{
        
        // Load JSON data
        NSData *donutsData = [NSData dataWithContentsOfURL:[[NSBundle bundleForClass:[self class]] URLForResource:@"donuts" withExtension:@"json"]];
        NSArray *donutDocuments = [NSJSONSerialization JSONObjectWithData:donutsData options:0 error:nil];
        
        // Open database
        NSMutableDictionary *options = [NSMutableDictionary dictionary];
        // options[JDBDatabaseOptionVerboseKey] = @YES;
        JDBDatabase *database = [JDBDatabase databaseAtPath:dbPath withOptions:options];
        
        // Get a collection of document
        JDBCollection *donuts = [database collection:@"donuts"];
        
        // Insert data into the collection
        [donutDocuments enumerateObjectsUsingBlock:^(NSDictionary *donutDocument, NSUInteger idx, BOOL *stop) {
            [donuts save:donutDocument];
        }];
        
        // Get the number of document in the collection
        NSUInteger donutCount = [[donuts find:nil] count];
        expect(donutCount).to.equal(3);
        
        // Query criteria (i.e.: name != 'Cake' and (ppu = 0.54 or ppu = 0.55))
        NSDictionary *criteria = @{@"name": @{@"$ne": @"Cake"}, @"ppu": @{@"$in": @[@(0.54), @(0.55)]}};
        // Query sort descriptor (i.e.: by name in reverse order)
        NSArray *sort = @[@{@"name": @NO}];
        
        // Query the collection to return all the documents that matches the above criteria and sort descriptor
        NSArray *results = [[donuts find:criteria sort:sort] all];
        expect(results).to.haveCountOf(2);
        
        // Query the collection to return the first document with no criteria but using the above sort descriptor
        id result = [[donuts find:nil sort:sort] first];
        expect(result).toNot.beNil;
        
        // Update the collection (i.e.: set a rating of 5 to all documents matching the criteria name = 'Cake') and return the updated documents
        results = [[donuts find:@{@"name": @"Cake"}] allAndModify:^JDBModifyOperation(NSMutableDictionary *document) {
            document[@"rating"] = @5;
            return JDBModifyOperationUpdate | JDBModifyOperationReturnNew;
        }];
        expect(results).to.haveCountOf(1);
        
        // Remove documents from the collection (i.e.: all document without rating)
        NSUInteger removed = [[donuts find:@{@"rating": [NSNull null]}] removeAll];
        expect(removed).to.equal(2);
        
        // Query the collection and returns the first one (in this case the only one in the collection, named 'Cake')
        NSDictionary *document = [[donuts find:nil] first];
        expect(document[@"name"]).to.equal(@"Cake");
        expect(document[@"rating"]).to.equal(5);
    });
    
    it(@"should be simple to use even for complex use case", ^{
        
        NSNumber *verbose = @NO;
        NSDictionary *options = @{JDBDatabaseOptionNSJSONReadingOptionsKey: @(NSJSONReadingMutableContainers),
                                  JDBDatabaseOptionVerboseKey: verbose};
        JDBDatabase *database = [JDBDatabase databaseAtPath:dbPath withOptions:options];
        
        JDBCollection *usersCollection = [database collection:@"users"];
        
        NSData *usersData = [NSData dataWithContentsOfURL:[[NSBundle bundleForClass:[self class]] URLForResource:@"users" withExtension:@"json"]];
        NSArray *userDocuments = [NSJSONSerialization JSONObjectWithData:usersData options:0 error:nil];
        [userDocuments enumerateObjectsUsingBlock:^(NSDictionary *userDocument, NSUInteger idx, BOOL *stop) {
            [usersCollection save:userDocument];
        }];
        
        JDBView *mainView = [usersCollection viewForPaths:@[@"id", @"index", @"isActive", @"age", @"name", @"gender", @"tags"]];
        
        NSUInteger totalCount = [[mainView find:nil] count];
        NSLog(@"totalCount: %@", @(totalCount));
        
        JDBQuery *activeFemalesQuery = [mainView find:@{@"isActive": @YES, @"gender": @"female"} sort:@[@"name"]];
        NSUInteger activeFemalesCount = [activeFemalesQuery count];
        NSLog(@"activeFemalesCount: %@", @(activeFemalesCount));
        NSArray *activeFemaleNames = [[activeFemalesQuery allAndProjectKeyPaths:@[@"name"]] valueForKeyPath:@"@unionOfObjects.name"];
        NSLog(@"activeFemaleNames: %@", [activeFemaleNames componentsJoinedByString:@", "]);
        
        [activeFemalesQuery allAndModify:^JDBModifyOperation(NSMutableDictionary *document) {
            [document[@"tags"] addObject:@"ActiveFemaleTag"];
            return JDBModifyOperationUpdate;
        }];
    });
    
});

SpecEnd
