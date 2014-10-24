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

@interface JDBQuery ()

@property (strong) JDBView *view;

@property (strong) NSString *where;
@property (strong) NSString *orderBy;
@property (strong) NSDictionary *parameters;

@end

@implementation JDBQuery

#pragma mark - public

// TODO: JSONPatch

- (NSUInteger)count {
    return [[self executeCount] unsignedIntegerValue];
}

- (NSArray *)all {
    return [self allAndProject:nil];
}

- (NSArray *)allAndProject:(JDBProjectionBlock)block {
    return [self executeInRange:NSMakeRange(0, NSUIntegerMax) andProject:block];;
}

- (NSArray *)allAndModify:(JDBModificationBlock)block {
    return [self executeInRange:NSMakeRange(0, NSUIntegerMax) andModify:block];
}

- (NSArray *)allInRange:(NSRange)range {
    return [self allInRange:range andProject:nil];
}

- (NSArray *)allInRange:(NSRange)range andProject:(JDBProjectionBlock)block {
    return [self executeInRange:range andProject:block];
}

- (NSArray *)allInRange:(NSRange)range andModify:(JDBModificationBlock)block {
    return [self executeInRange:range andModify:block];
}

- (id)first {
    return [self firstAndProject:nil];
}

- (id)firstAndProject:(JDBProjectionBlock)block {
    return [[self executeInRange:NSMakeRange(0, 1) andProject:block] firstObject];
}

- (id)firstAndModify:(JDBModificationBlock)block {
    return [[self executeInRange:NSMakeRange(0, 1) andModify:block] firstObject];
}

- (NSUInteger)removeAll {
    __block NSUInteger count = 0;
    [self allAndModify:^JDBModifyOperation(NSMutableDictionary *document) {
        count++;
        return JDBModifyOperationRemove;
    }];
    return count;
}

- (NSUInteger)removeAllInRange:(NSRange)range {
    __block NSUInteger count = 0;
    [self allInRange:range andModify:^JDBModifyOperation(NSMutableDictionary *document) {
        count++;
        return JDBModifyOperationRemove;
    }];
    return count;
}

- (NSUInteger)removeFirst {
    __block NSUInteger count = 0;
    [self firstAndModify:^JDBModifyOperation(NSMutableDictionary *document) {
        count++;
        return JDBModifyOperationRemove;
    }];
    return count;
}

#pragma mark - private

- (void)buildQuery:(NSMutableString *)query count:(BOOL)count forRange:(NSRange)range {
    NSString *projection = count ? @"COUNT(DISTINCT _jdb_doc_id)" : @"DISTINCT _jdb_doc_id, _jdb_document";
    [query appendFormat:@"SELECT %@ FROM %@", projection, JDBEscape(self.view.table)];
    if (self.where && ![self.where isEqualToString:@""]) [query appendFormat:@" WHERE %@", self.where];
    if (!count) [query appendString:@" GROUP BY _jdb_doc_id"];
    if (!count && self.orderBy && ![self.orderBy isEqualToString:@""]) [query appendFormat:@" ORDER BY %@", self.orderBy];
    if (range.length != NSUIntegerMax) {
        [query appendFormat:@" LIMIT %lu", (unsigned long)range.length];
        if (range.location > 0) [query appendFormat:@" OFFSET %lu", (unsigned long)range.location];
    }
}

- (NSNumber *)executeCount {
    NSTimeInterval t = [[NSDate date] timeIntervalSinceReferenceDate];
    __block NSError *error = nil;
    __block NSNumber *result = nil;
    NSMutableString *query = [NSMutableString string];
    [self buildQuery:query count:YES forRange:NSMakeRange(0, NSUIntegerMax)];
    [self.view.collection.database readInDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:query withParameterDictionary:self.parameters];
        if (!rs) {
            [self.view.collection.database database:db lastError:&error];
            return;
        }
        if ([rs next]) result = @([rs longForColumnIndex:0]);
        [rs close];
    }];
    if (error) return [self.view.collection.database handleError:error];
    if (self.view.collection.database.verbose > 0)
        NSLog(@"%@ (%ldms)", query, (long)(1000 * ([[NSDate date] timeIntervalSinceReferenceDate] - t)));
    return result;
}

- (NSArray *)executeInRange:(NSRange)range andProject:(JDBProjectionBlock)block {
    NSTimeInterval t = [[NSDate date] timeIntervalSinceReferenceDate];
    __block NSError *error = nil;
    NSMutableArray *results = [NSMutableArray array];
    NSMutableString *query = [NSMutableString string];
    [self buildQuery:query count:NO forRange:range];
    [self.view.collection.database readInDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:query withParameterDictionary:self.parameters];
        if (!rs) {
            [self.view.collection.database database:db lastError:&error];
            return;
        }
        while ([rs next]) {
            NSData *documentData = [rs dataForColumn:@"_jdb_document"];
            // todo: check for db error
            if (error) break;
            NSDictionary *document = [self.view.collection.database JSONObjectWithData:documentData error:&error];
            if (error) break;
            id result;
            if (block) {
                @try {
                    result = block(document);
                }
                @catch (NSException *exception) {
                    error = [NSError errorWithDomain:JDBErrorDomain code:-1 userInfo:nil]; // TODO: fill user info
                    break;
                }
            } else {
                result = document;
            }
            [results addObject:result];
        }
        [rs close];
    }];
    if (error) return [self.view.collection.database handleError:error];
    if (self.view.collection.database.verbose > 0)
        NSLog(@"%@ (%ldms)", query, (long)(1000 * ([[NSDate date] timeIntervalSinceReferenceDate] - t)));
    return results;
}

- (NSArray *)executeInRange:(NSRange)range andModify:(JDBModificationBlock)block {
    NSTimeInterval t = [[NSDate date] timeIntervalSinceReferenceDate];
    __block NSError *error = nil;
    NSMutableArray *results = [NSMutableArray array];
    NSMutableString *query = [NSMutableString string];
    [self buildQuery:query count:NO forRange:range];
    [self.view.collection.database writeInTransaction:^(FMDatabase *db, BOOL *rollback) {
        FMResultSet *rs = [db executeQuery:query withParameterDictionary:self.parameters];
        if (!rs) {
            [self.view.collection.database database:db lastError:&error];
            return;
        }
        while ([rs next]) {
            id docId = [rs objectForColumnName:@"_jdb_doc_id"];
            JDBLazyDocument *lazyDocument = [[JDBLazyDocument alloc] initWithQuery:self andResultSet:rs];
            JDBModifyOperation operations = JDBModifyOperationNoop;
            if (block) {
                @try {
                    operations = block((NSMutableDictionary *)lazyDocument);
                }
                @catch (NSException *exception) {
                    error = [NSError errorWithDomain:JDBErrorDomain code:-1 userInfo:nil]; // TODO: fill user info
                    *rollback = YES;
                    break;
                }
            }
            if (lazyDocument.error) {
                error = lazyDocument.error;
                *rollback = YES;
                break;
            }
            if (operations & JDBModifyOperationRollback) {
                *rollback = YES;
            } else {
                if (operations & JDBModifyOperationReturnOld) {
                    [lazyDocument loadOriginalDocument];
                    if (lazyDocument.error) {
                        error = lazyDocument.error;
                        *rollback = YES;
                        break;
                    }
                }
                if (operations & JDBModifyOperationUpdate) {
                    if (lazyDocument.mutableDocument) {
                        [self.view.collection updateDocument:lazyDocument.mutableDocument withId:docId inDatabase:db error:&error];
                        if (error) {
                            *rollback = YES;
                            break;
                        }
                    }
                } else if (operations & JDBModifyOperationRemove) {
                    [self.view.collection removeDocumentWithId:docId inDatabase:db error:&error];
                    if (error) {
                        *rollback = YES;
                        break;
                    }
                }
                if (operations & JDBModifyOperationReturnOld) {
                    [results addObject:lazyDocument.originalDocument];
                } else if (operations & JDBModifyOperationReturnNew) {
                    if (lazyDocument.mutableDocument) {
                        [results addObject:lazyDocument.mutableDocument];
                    } else {
                        [lazyDocument loadOriginalDocument];
                        [results addObject:lazyDocument.originalDocument];
                    }
                }
            }
            if (operations & (JDBModifyOperationStop | JDBModifyOperationRollback)) {
                break;
            }
        }
        [rs close];
    }];
    if (error) return [self.view.collection.database handleError:error];
    if (self.view.collection.database.verbose > 0)
        NSLog(@"%@ (%ldms)", query, (long)(1000 * ([[NSDate date] timeIntervalSinceReferenceDate] - t)));
    return results;
}

- (instancetype)initWithView:(JDBView *)view where:(NSString *)where orderBy:(NSString *)orderBy andParameters:(NSDictionary *)parameters {
    // TODO: trim white space from all string params ?
    if (self = [super init]) {
        self.view = view;
        self.where = where;
        self.orderBy = orderBy;
        self.parameters = parameters;
    }
    return self;
}

@end
