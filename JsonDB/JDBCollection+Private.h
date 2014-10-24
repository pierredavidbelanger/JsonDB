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

@class JDBDatabase;

@interface JDBCollection (Private)

@property (strong) JDBDatabase *database;

@property (strong) NSString *tableNamePrefix;
@property (strong) NSString *docTableName;
@property (strong) NSString *flatTableName;

- (instancetype)initWithDatabase:(JDBDatabase *)database andName:(NSString *)name error:(NSError **)error;

- (NSData *)selectDocumentDataWithId:(id)docId inDatabase:(FMDatabase *)db error:(NSError **)error;

- (BOOL)updateDocument:(NSDictionary *)document withId:(id)docId inDatabase:(FMDatabase *)db error:(NSError **)error;

- (BOOL)removeDocumentWithId:(id)docId inDatabase:(FMDatabase *)db error:(NSError **)error;

@end