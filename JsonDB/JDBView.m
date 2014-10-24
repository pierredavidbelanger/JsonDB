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

@interface JDBView ()

@property (strong) JDBCollection *collection;

@property (strong) NSString *table;
@property (strong) NSOrderedSet *paths;

@end

@implementation JDBView

#pragma mark - public

- (JDBQuery *)find:(NSDictionary *)criteria {
    return [self find:criteria sort:nil];
}

- (JDBQuery *)find:(NSDictionary *)criteria sort:(NSArray *)sort {
    NSError *error = nil;
    NSMutableSet *paths = [NSMutableSet setWithCapacity:self.paths.count]; // TODO: should check that paths is a subset of self.paths
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:self.paths.count];
    NSMutableString *where = [NSMutableString string];
    JDBTransformCriteriaToQuery(criteria, paths, where, parameters, &error);
    if (error) [self.collection.database handleError:error];
    NSMutableString *orderBy = [NSMutableString string];
    JDBTransformSortToOrderBy(sort, paths, orderBy, &error);
    if (error) [self.collection.database handleError:error];
    return [[JDBQuery alloc] initWithView:self where:where orderBy:orderBy andParameters:parameters];
}

#pragma mark - private

+ (instancetype)viewForCollection:(JDBCollection *)collection withPaths:(NSArray *)paths error:(NSError **)error {
    
    // TODO: Handle simple cases here: like empty or single entry paths, id only
    
    NSOrderedSet *orderedUniquePaths =
        [NSOrderedSet orderedSetWithArray:[[[NSSet setWithArray:paths] allObjects] sortedArrayUsingSelector:@selector(compare:)]];
    
    __block NSUInteger hash = [self hashOfPaths:orderedUniquePaths];
    NSString *viewName = [NSString stringWithFormat:@"%@_jdb_view_%lu", collection.tableNamePrefix, (unsigned long)hash];
    
    __block JDBView *view = [collection.database.viewCache objectForKey:viewName];
    if (view) return view;
    
    NSString *superSetViewName = [self findViewNameForCollection:collection withPathsSuperSetOf:orderedUniquePaths];
    if (superSetViewName) {
        view = [collection.database.viewCache objectForKey:superSetViewName];
        if (view) {
            [collection.database.viewCache setObject:view forKey:viewName];
            return view;
        }
        viewName = superSetViewName;
    }
    
    [collection.database writeInTransaction:^(FMDatabase *db, BOOL *rollback) {
        
        FMResultSet *rs = [db executeQuery:@"SELECT name FROM sqlite_master WHERE type = 'view' AND name = ?", viewName];
        BOOL viewExists = [rs next];
        [rs close];

        if (!viewExists) {
            NSString *select = [self selectForPaths:orderedUniquePaths inCollection:collection];
            BOOL ok = [db executeUpdate:[NSString stringWithFormat:@"CREATE VIEW IF NOT EXISTS %@ AS %@", JDBEscape(viewName), select]];
            if (!ok) {
                [collection.database database:db lastError:error];
                *rollback = YES;
                return;
            }
        }
        
        view = [[JDBView alloc] initWithCollection:collection tableName:viewName andPaths:orderedUniquePaths];
        [collection.database.viewCache setObject:view forKey:viewName];
    }];
    
    return view;
}

+ (NSString *)findViewNameForCollection:(JDBCollection *)collection withPathsSuperSetOf:(NSOrderedSet *)paths {
    __block NSString *foundViewName = nil;
    NSString *viewNamePrefix = [NSString stringWithFormat:@"%@_jdb_view_", collection.tableNamePrefix];
    [collection.database readInDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db getSchema];
        while ([rs next]) {
            if ([rs[@"type"] isEqualToString:@"view"]) {
                NSString *viewName = rs[@"name"];
                if ([viewName rangeOfString:viewNamePrefix].location == 0) {
                    NSMutableSet *viewPaths = [NSMutableSet set];
                    FMResultSet *rs2 = [db getTableSchema:viewName];
                    while ([rs2 next]) {
                        NSString *columnName = rs2[@"name"];
                        if ([columnName rangeOfString:@"_jdb_"].location != 0) {
                            [viewPaths addObject:columnName];
                        }
                    }
                    [rs2 close];
                    if ([paths isSubsetOfSet:viewPaths]) {
                        foundViewName = viewName;
                        break;
                    }
                }
            }
        }
        [rs close];
    }];
    return foundViewName;
}

+ (NSUInteger)hashOfPaths:(NSOrderedSet *)paths {
    __block NSUInteger hash = 1;
    [paths enumerateObjectsUsingBlock:^(NSString *path, NSUInteger idx, BOOL *stop) {
        hash = hash * 31 + [path hash];
    }];
    return hash;
}

+ (NSString *)selectForPaths:(NSOrderedSet *)paths inCollection:(JDBCollection *)collection {
    NSMutableString *select = [NSMutableString string];
    [select appendString:@"SELECT d.id AS _jdb_doc_id, d.document_id AS _jdb_document_id, d.document AS _jdb_document"];
    [paths enumerateObjectsUsingBlock:^(NSString *path, NSUInteger idx, BOOL *stop) {
        [select appendFormat:@", p%lu.value AS %@", (unsigned long)idx, JDBEscape(path)];
    }];
    [select appendFormat:@" FROM %@ AS d", JDBEscape(collection.docTableName)];
    [paths enumerateObjectsUsingBlock:^(NSString *path, NSUInteger idx, BOOL *stop) {
        [select appendFormat:@" LEFT JOIN %@ AS p%lu ON p%lu.doc_id = d.id AND p%lu.super_type = 'v' AND p%lu.path = %@",
         JDBEscape(collection.flatTableName), (unsigned long)idx, (unsigned long)idx, (unsigned long)idx, (unsigned long)idx, JDBEscapeData(path)];
    }];
    return select;
}

- (instancetype)initWithCollection:(JDBCollection *)collection tableName:(NSString *)table andPaths:(NSOrderedSet *)paths {
    if (self = [super init]) {
        self.collection = collection;
        self.table = table;
        self.paths = paths;
    }
    return self;
}

@end
