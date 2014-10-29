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

#import "JsonDB+Private.h"

NSString * const JDBErrorDomain = @"JDBErrorDomain";

NSString * const JDBDatabaseOptionVerboseKey = @"JDBDatabaseOptionVerboseKey";
NSString * const JDBDatabaseOptionNSJSONWritingOptionsKey = @"JDBDatabaseOptionNSJSONWritingOptionsKey";
NSString * const JDBDatabaseOptionNSJSONReadingOptionsKey = @"JDBDatabaseOptionNSJSONReadingOptionsKey";
NSString * const JDBDatabaseOptionManageIdentifierKey = @"JDBDatabaseOptionManageIdentifierKey";
NSString * const JDBDatabaseOptionIdentifierPathKey = @"JDBDatabaseOptionIdentifierPathKey";

JDBErrorHandler const JDBErrorHandlerDefault = ^(JDBDatabase *database, NSError *error){
    NSLog(@"ERROR in JsonDB: %@", error);
};

JDBIdentifierFactory const JDBIdentifierFactoryDefault = ^id(JDBDatabase *database, id context){
    return [[NSUUID UUID] UUIDString];
};

@interface JDBDatabase () <NSCacheDelegate>

@property (strong) FMDatabaseQueue *writeDatabaseQueue;
@property (strong) FMDatabasePool *readDatabasePool;

@property NSUInteger verbose;

@property (strong) NSCache *collectionsCache;
@property (strong) NSCache *viewCache;

@property NSJSONWritingOptions nsJsonWritingOptions;
@property NSJSONReadingOptions nsJsonReadingOptions;

@property BOOL manageIdentifier;
@property (strong) NSString *identifierPath;

@end

@implementation JDBDatabase

#pragma mark - public

+ (instancetype)databaseInMemory {
    return [self databaseInMemoryWithOptions:nil];
}

+ (instancetype)databaseAtPath:(NSString *)path {
    return [self databaseAtPath:path withOptions:nil];
}

+ (instancetype)databaseInMemoryWithOptions:(NSDictionary *)options {
    return [self databaseAtPath:nil withOptions:options];
}

+ (instancetype)databaseAtPath:(NSString *)path withOptions:(NSDictionary *)options {
    return [[self alloc] initAtPath:path withOptions:options];
}

// TODO: drop collection

- (NSArray *)collectionNames {
    NSMutableArray *collectionNames = [NSMutableArray array];
    [self readInDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT name FROM _jdb_col ORDER BY name"];
        if (!rs) return;
        while ([rs next]) {
            [collectionNames addObject:[rs stringForColumn:@"name"]];
        }
        [rs close];
    }];
    return collectionNames;
}

- (JDBCollection *)collection:(NSString *)name {
    JDBCollection *collection = [self.collectionsCache objectForKey:name];
    if (collection) return collection;
    __block NSError *error = nil;
    [self writeInTransaction:^(FMDatabase *db, BOOL *rollback) {
        BOOL ok = [db executeUpdate:@"INSERT OR IGNORE INTO _jdb_col (name) VALUES (?)", name];
        if (!ok) {
            *rollback = YES;
            [self database:db lastError:&error];
        }
    }];
    if (error) return [self handleError:error];
    collection = [[JDBCollection alloc] initWithDatabase:self andName:name error:&error];
    if (error) return [self handleError:error];
    [self.collectionsCache setObject:collection forKey:name];
    return collection;
}

- (void)cleanup {
    [self.collectionsCache removeAllObjects];
    [self.viewCache removeAllObjects];
    [self.writeDatabaseQueue close];
    [self.readDatabasePool releaseAllDatabases];
}

#pragma mark - private

- (instancetype)initAtPath:(NSString *)path withOptions:(NSDictionary *)options {
    if (self = [super init]) {
        self.errorHandler = JDBErrorHandlerDefault;
        self.identifierFactory = JDBIdentifierFactoryDefault;
        if (path) {
            self.writeDatabaseQueue = [FMDatabaseQueue databaseQueueWithPath:path flags:SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE];
            if (!self.writeDatabaseQueue) {
                [self handleError:[NSError errorWithDomain:JDBErrorDomain code:1
                                                  userInfo:@{NSLocalizedDescriptionKey: @"Unable to open SQLite Database (readwrite)"}]];
                return nil;
            }
            if ([FMDatabase isSQLiteThreadSafe]) {
                self.readDatabasePool = [FMDatabasePool databasePoolWithPath:path flags:SQLITE_OPEN_READONLY];
                if (!self.readDatabasePool) {
                    [self handleError:[NSError errorWithDomain:JDBErrorDomain code:1
                                                      userInfo:@{NSLocalizedDescriptionKey: @"Unable to open SQLite Database (readonly)"}]];
                    return nil;
                }
            }
        } else {
            self.writeDatabaseQueue = [FMDatabaseQueue databaseQueueWithPath:path flags:SQLITE_OPEN_READWRITE | SQLITE_OPEN_MEMORY];
            if (!self.writeDatabaseQueue) {
                [self handleError:[NSError errorWithDomain:JDBErrorDomain code:1
                                                  userInfo:@{NSLocalizedDescriptionKey: @"Unable to open SQLite Database (memory)"}]];
                return nil;
            }
        }
        __block NSError *error = nil;
        [self writeInTransaction:^(FMDatabase *db, BOOL *rollback) {
            BOOL ok = [db executeUpdate:@"CREATE TABLE IF NOT EXISTS _jdb_col (name, UNIQUE (name))"];
            if (!ok) {
                *rollback = YES;
                [self database:db lastError:&error];
            }
        }];
        if (error) {
            [self handleError:error];
            return nil;
        }
        self.verbose = [options[JDBDatabaseOptionVerboseKey] unsignedIntegerValue];
        self.collectionsCache = [[NSCache alloc] init];
        self.viewCache = [[NSCache alloc] init];
        if (self.verbose > 0) {
            [self writeInDatabase:^(FMDatabase *db) {
                db.logsErrors = YES;
                if (self.verbose > 1) db.traceExecution = YES;
            }];
            if (self.readDatabasePool) self.readDatabasePool.delegate = self;
            self.collectionsCache.delegate = self;
            self.viewCache.delegate = self;
        }
#if defined(DEBUG) && DEBUG
        [self writeInDatabase:^(FMDatabase *db) {
            db.crashOnErrors = YES;
        }];
#endif
        self.nsJsonWritingOptions = [options[JDBDatabaseOptionNSJSONWritingOptionsKey] unsignedIntegerValue];
        self.nsJsonReadingOptions = [options[JDBDatabaseOptionNSJSONReadingOptionsKey] unsignedIntegerValue];
        self.manageIdentifier = options[JDBDatabaseOptionManageIdentifierKey] ? [options[JDBDatabaseOptionManageIdentifierKey] boolValue] : YES;
        self.identifierPath = [options[JDBDatabaseOptionIdentifierPathKey] description];
        if (!self.identifierPath) self.identifierPath = @"id";
        // TODO: remove old view ?
    }
    return self;
}

- (id)handleError:(NSError *)error {
    JDBErrorHandler errorHandler = self.errorHandler ? self.errorHandler : JDBErrorHandlerDefault;
    errorHandler(self, error);
    return nil;
}

- (id)database:(FMDatabase *)db lastError:(NSError **)error; {
    if ([db hadError] && error) *error = [db lastError];
    return nil;
}

- (NSData *)dataWithJSONObject:(id)object error:(NSError **)error {
    @try {
        return [NSJSONSerialization dataWithJSONObject:object options:self.nsJsonWritingOptions error:error];
    }
    @catch (NSException *exception) {
        // TODO: we got strange autorelease related crash if userInfo is not nil
        if (error) *error = [NSError errorWithDomain:JDBErrorDomain code:-1 userInfo:nil];
    }
}

- (id)JSONMutableObjectWithData:(NSData *)data error:(NSError **)error {
    @try {
        return [NSJSONSerialization JSONObjectWithData:data options:(self.nsJsonReadingOptions | NSJSONReadingMutableContainers) error:error];
    }
    @catch (NSException *exception) {
        // TODO: we got strange autorelease related crash if userInfo is not nil
        if (error) *error = [NSError errorWithDomain:JDBErrorDomain code:-1 userInfo:nil];
    }
}

- (id)JSONObjectWithData:(NSData *)data error:(NSError **)error {
    @try {
        return [NSJSONSerialization JSONObjectWithData:data options:self.nsJsonReadingOptions error:error];
    }
    @catch (NSException *exception) {
        // TODO: we got strange autorelease related crash if userInfo is not nil
        if (error) *error = [NSError errorWithDomain:JDBErrorDomain code:-1 userInfo:nil];
    }
}

- (void)readInDatabase:(void (^)(FMDatabase *db))block {
    if (self.readDatabasePool) [self.readDatabasePool inDatabase:block];
    else [self.writeDatabaseQueue inDatabase:block];
}

- (void)readInTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block {
    if (self.readDatabasePool) [self.readDatabasePool inTransaction:block];
    else [self.writeDatabaseQueue inTransaction:block];
}

- (void)writeInDatabase:(void (^)(FMDatabase *db))block {
    [self.writeDatabaseQueue inDatabase:block];
}

- (void)writeInTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block {
    [self.writeDatabaseQueue inTransaction:block];
}

- (void)cache:(NSCache *)cache willEvictObject:(id)obj {
    NSLog(@"cache:%@ willEvictObject:%@", cache, obj);
}

- (void)databasePool:(FMDatabasePool*)pool didAddDatabase:(FMDatabase*)db {
    NSLog(@"databasePool:%@ didAddDatabase:%@", pool, db);
    db.logsErrors = YES;
    if (self.verbose > 1) db.traceExecution = YES;
}

@end
