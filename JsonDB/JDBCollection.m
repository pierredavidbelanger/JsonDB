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

@interface JDBCollection ()

@property (strong) JDBDatabase *database;

@property (strong) NSString *tableNamePrefix;
@property (strong) NSString *docTableName;
@property (strong) NSString *flatTableName;

@end

@implementation JDBCollection

#pragma mark - public

- (id)save:(NSDictionary *)document {
    __block NSError *error = nil;
    id documentId = nil;
    BOOL hasEmbededDocumentId = NO;
    if (self.database.manageIdentifier) {
        documentId = document[self.database.identifierPath]; // todo: handle dot path here!
        if (documentId) hasEmbededDocumentId = YES;
    }
    if (!documentId) documentId = self.database.identifierFactory(self.database, document);
    if (self.database.manageIdentifier && !hasEmbededDocumentId) {
        NSMutableDictionary *mutableDocument = [document mutableCopy];
        mutableDocument[self.database.identifierPath] = documentId; // todo: handle dot path here!
        document = mutableDocument;
    }
    NSData *documentData = [self.database dataWithJSONObject:document error:&error];
    if (error) return [self.database handleError:error];
    [self.database writeInTransaction:^(FMDatabase *db, BOOL *rollback) {
        id docId = nil;
        if (hasEmbededDocumentId) {
            docId = @([db longForQuery:[NSString stringWithFormat:@"SELECT id FROM %@ WHERE document_id = ?", JDBEscape(self.docTableName)], documentId]);
            [self.database database:db lastError:&error];
            if (error) {
                *rollback = YES;
                return;
            }
        }
        if (docId && [docId longValue] > 0) {
            [self updateDocument:document withIdentifier:documentId andData:documentData andDocId:docId inDatabase:db error:&error];
        } else {
            [self insertDocument:document withIdentifier:documentId andData:documentData inDatabase:db error:&error];
        }
        if (error) {
            *rollback = YES;
            return;
        }
    }];
    if (error) return [self.database handleError:error];
    return documentId;
}

- (JDBView *)viewForPaths:(NSArray *)paths {
    NSError *error = nil;
    JDBView *view = [JDBView viewForCollection:self withPaths:paths error:&error];
    if (error) return [self.database handleError:error];
    return view;
}

- (JDBQuery *)find:(NSDictionary *)criteria {
    return [self find:criteria sort:nil];
}

- (JDBQuery *)find:(NSDictionary *)criteria sort:(NSArray *)sort {
    NSError *error = nil;
    NSMutableSet *paths = [NSMutableSet set];
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    NSMutableString *where = [NSMutableString string];
    JDBTransformCriteriaToQuery(criteria, paths, where, parameters, &error);
    if (error) return [self.database handleError:error];
    NSMutableString *orderBy = [NSMutableString string];
    JDBTransformSortToOrderBy(sort, paths, orderBy, &error);
    if (error) return [self.database handleError:error];
    JDBView *view = [JDBView viewForCollection:self withPaths:[paths allObjects] error:&error];
    if (error) return [self.database handleError:error];
    return [[JDBQuery alloc] initWithView:view where:where orderBy:orderBy andParameters:parameters];
}

#pragma mark - private

- (NSData *)selectDocumentDataWithId:(id)docId inDatabase:(FMDatabase *)db error:(NSError **)error {
    NSData *data = [db dataForQuery:[NSString stringWithFormat:@"SELECT document FROM %@ WHERE id = ?", JDBEscape(self.docTableName)], docId];
    if (!data) [self.database database:db lastError:error];
    return data;
}

- (BOOL)updateDocument:(NSDictionary *)document withId:(id)docId inDatabase:(FMDatabase *)db error:(NSError **)error {
    NSData *documentData = [self.database dataWithJSONObject:document error:error];
    if (*error) return NO;
    return [self updateDocument:document withIdentifier:nil andData:documentData andDocId:docId inDatabase:db error:error];
}

- (BOOL)removeDocumentWithId:(id)docId inDatabase:(FMDatabase *)db error:(NSError **)error {
    [self removeFromFlatWithDocId:docId inDatabase:db error:error];
    if (*error) return NO;
    return [self removeFromDocWithDocId:docId inDatabase:db error:error];
}

- (id)insertDocument:(NSDictionary *)document withIdentifier:(id)documentId andData:(NSData *)documentData inDatabase:(FMDatabase *)db error:(NSError **)error {
    id docId = [self insertIntoDocWithDocument:document withIdentifier:documentId andData:documentData inDatabase:db error:error];
    if (*error) return nil;
    [self insertIntoFlatWithDocument:document withDocId:docId inDatabase:db error:error];
    if (*error) return nil;
    return docId;
}

- (BOOL)updateDocument:(NSDictionary *)document withIdentifier:(id)documentId andData:(NSData *)documentData andDocId:(id)docId inDatabase:(FMDatabase *)db error:(NSError **)error {
    [self updateDocWithDocument:document withIdentifier:documentId andData:documentData andDocId:docId inDatabase:db error:error];
    if (*error) return NO;
    [self removeFromFlatWithDocId:docId inDatabase:db error:error];
    if (*error) return NO;
    return [self insertIntoFlatWithDocument:document withDocId:docId inDatabase:db error:error];
}

- (id)insertIntoDocWithDocument:(NSDictionary *)document withIdentifier:(id)documentId andData:(NSData *)documentData inDatabase:(FMDatabase *)db error:(NSError **)error {
    BOOL ok = [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO %@ (document_id, document) VALUES (?, ?)", JDBEscape(self.docTableName)], documentId, documentData];
    if (!ok) [self.database database:db lastError:error];
    return @([db lastInsertRowId]);
}

- (BOOL)updateDocWithDocument:(NSDictionary *)document withIdentifier:(id)documentId andData:(NSData *)documentData andDocId:(id)docId inDatabase:(FMDatabase *)db error:(NSError **)error {
    BOOL ok = NO;
    if (documentId) ok = [db executeUpdate:[NSString stringWithFormat:@"UPDATE %@ SET document_id = ?, document = ? WHERE id = ?", JDBEscape(self.docTableName)], documentId, documentData, docId];
    else ok = [db executeUpdate:[NSString stringWithFormat:@"UPDATE %@ SET document = ? WHERE id = ?", JDBEscape(self.docTableName)], documentData, docId];
    if (!ok) [self.database database:db lastError:error];
    return ok;
}

- (BOOL)removeFromDocWithDocId:(id)docId inDatabase:(FMDatabase *)db error:(NSError **)error {
    BOOL ok = [db executeUpdate:[NSString stringWithFormat:@"DELETE FROM %@ WHERE id = ?", JDBEscape(self.docTableName)], docId];
    if (!ok) [self.database database:db lastError:error];
    return ok;
}

- (BOOL)removeFromFlatWithDocId:(id)docId inDatabase:(FMDatabase *)db error:(NSError **)error {
    BOOL ok = [db executeUpdate:[NSString stringWithFormat:@"DELETE FROM %@ WHERE doc_id = ?", JDBEscape(self.flatTableName)], docId];
    if (!ok) [self.database database:db lastError:error];
    return ok;
}

- (BOOL)insertIntoFlatWithDocument:(NSDictionary *)document withDocId:(id)docId inDatabase:(FMDatabase *)db error:(NSError **)error {
    JDBTraverseType types = JDBTraverseTypeContainerBegin | JDBTraverseTypeValue;
    JDBTraverse(document, types, ^id(id parentId, JDBTraverseType type, NSMutableArray *keys, NSString *key, NSUInteger index, id value) {
        NSString *superTypeString = @"";
        if (type & JDBTraverseTypeContainer) superTypeString = @"(";
        else if (type & JDBTraverseTypeElement) superTypeString = @",";
        else if (type & JDBTraverseTypeValue) superTypeString = @"v";
        NSString *typeString = @"";
        if (type & JDBTraverseTypeObjectBegin) typeString = @"{";
        else if (type & JDBTraverseTypeObjectEnd) typeString = @"}";
        else if (type & JDBTraverseTypeArrayBegin) typeString = @"[";
        else if (type & JDBTraverseTypeArrayEnd) typeString = @"]";
        else if (type & JDBTraverseTypeValueNull) typeString = @"0";
        else if (type & JDBTraverseTypeValueBoolean) typeString = @"b";
        else if (type & JDBTraverseTypeValueNumber) typeString = @"n";
        else if (type & JDBTraverseTypeValueString) typeString = @"s";
        if (0 == (type & JDBTraverseTypeValue)) value = nil;
        BOOL ok = [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO %@ (doc_id, parent_id, super_type, type, path, idx, value) VALUES (?, ?, ?, ?, ?, ?, ?)", JDBEscape(self.flatTableName)], docId, parentId, superTypeString, typeString, [keys componentsJoinedByString:@"."], @(index), value];
        if (!ok) [self.database database:db lastError:error];
        return @([db lastInsertRowId]);
    });
    return error && *error ? NO : YES;
}

- (instancetype)initWithDatabase:(JDBDatabase *)database andName:(NSString *)name error:(NSError **)error {
    // TODO: cache SQLs
    if (self = [super init]) {
        self.database = database;
        self.tableNamePrefix = [NSString stringWithFormat:@"_jdb_col_%@", name];
        self.docTableName = [NSString stringWithFormat:@"%@_doc", self.tableNamePrefix];
        self.flatTableName = [NSString stringWithFormat:@"%@_flat", self.tableNamePrefix];
        [self.database writeInTransaction:^(FMDatabase *db, BOOL *rollback) {
            BOOL ok = [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (id INTEGER, document_id, document BLOB, PRIMARY KEY (id), UNIQUE (document_id))", JDBEscape(self.docTableName)]];
            if (!ok) {
                [self.database database:db lastError:error];
                *rollback = YES;
            }
            ok = [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (id INTEGER, doc_id INTEGER, parent_id INTEGER, super_type CHARACTER(1), type CHARACTER(1), path TEXT, idx INTEGER, value, PRIMARY KEY (id), FOREIGN KEY (doc_id) REFERENCES %@ (id), FOREIGN KEY (parent_id) REFERENCES %@ (id))", JDBEscape(self.flatTableName), JDBEscape(self.docTableName), JDBEscape(self.flatTableName)]];
            if (!ok) {
                [self.database database:db lastError:error];
                *rollback = YES;
            }
        }];
        if (*error) return nil;
    }
    return self;
}

@end
