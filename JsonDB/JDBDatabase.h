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

#import "JsonDB.h"

extern NSString * const JDBErrorDomain;

extern NSString * const JDBDatabaseOptionVerboseKey;
extern NSString * const JDBDatabaseOptionNSJSONWritingOptionsKey;
extern NSString * const JDBDatabaseOptionNSJSONReadingOptionsKey;
extern NSString * const JDBDatabaseOptionManageIdentifierKey;
extern NSString * const JDBDatabaseOptionIdentifierPathKey;

typedef void (^JDBErrorHandler)(JDBDatabase *database, NSError *error);
typedef id (^JDBIdentifierFactory)(JDBDatabase *database, id context);

extern JDBErrorHandler const JDBErrorHandlerDefault;

extern JDBIdentifierFactory const JDBIdentifierFactoryDefault;

/**
 JDBDatabase is the entry point of JsonDB. 
 
 It gives acces to the set of collection (`JDBCollection`).
 
 ## Example
 
    // Create a file path where to open/save the database (here, on iOS, in the application's Document directory)
    NSString *dbPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"/main.jsondb"];
 
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
    expect(cheaters[0][@"playerName"]).to.equal(@"John Appleseed");

    // Find the first one with a score over 9000, flag it as a cheater and return the old document
    NSDictionary *over9000 = [[collection find:@{@"score": @{@"$gt": @9000}}] firstAndModify:^JDBModifyOperation(NSMutableDictionary *document) {
        document[@"cheatMode"] = @YES;
        return JDBModifyOperationUpdate | JDBModifyOperationReturnOld;
    }];
    expect(over9000[@"cheatMode"]).to.equal(NO);
 
 ## Thread safety
 
 All `JDBDatabase` instances, also its `JDBCollection`, `JDBView` and `JDBQuery` are thread safe.
 
 Many thread can use those objects to read and write to the database at the same time.
 
 But you have to keep in mind that:
 
 - all write operations (save, modify and remove) are performed sequencially in their transaction.
 - all read operations (find, count) are performed in parrallel and see what is commited only.
 
 ## Mutability
 
 When a non mutable object is expected in a method signature or returns by the method,
 the library actually expect it to not be mutated, no defensive copy are made.
 
 */
@interface JDBDatabase : NSObject

/**
 The global error handler (`JDBErrorHandler`). Defaults to `JDBErrorHandlerDefault` wich is implemented with only a simple `NSLog` to the console.
 */
@property (copy) JDBErrorHandler errorHandler;

/**
 The global identifier factory (`JDBIdentifierFactory`). Defaults to `JDBIdentifierFactoryDefault` wich is implemented with a `return [[NSUUID UUID] UUIDString];`.
 */
@property (copy) JDBIdentifierFactory identifierFactory;

/// @name Database creation

/** 
 Alloc and init an in memory `JDBDatabase` with default option values.
 
 @return A new in mempry `JDBDatabase`
 */
+ (instancetype)databaseInMemory;

/**
 Alloc and init an persistent `JDBDatabase` with default option values.
 
 @param path The file path where to save the database
 @return A new persistent `JDBDatabase`
 */
+ (instancetype)databaseAtPath:(NSString *)path;

/**
 Alloc and init an in memory `JDBDatabase` with default option values.
 
 @return A new in mempry `JDBDatabase`
 */
+ (instancetype)databaseInMemoryWithOptions:(NSDictionary *)options;

/**
 Alloc and init an persistent `JDBDatabase` with default option values.
 
 @param path The file path where to save the database
 @return A new persistent `JDBDatabase`
 */
+ (instancetype)databaseAtPath:(NSString *)path withOptions:(NSDictionary *)options;

/// @name Collections access

/**
 @return The collection's name managed by this database.
 */
- (NSArray *)collectionNames;

/**
 Get (after creating it if not already created) a collection of document given its name.
 
 @param name The name of the collection
 @return A `JDBCollection`
 */
- (JDBCollection *)collection:(NSString *)name;

- (void)cleanup;

@end
