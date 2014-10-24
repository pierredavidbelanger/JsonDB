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

SpecBegin(DatabaseCreation)

describe(@"database creation", ^{
    
    sharedExamplesFor(@"factory with path and options", ^(NSDictionary *params) {
        
        NSString *path = params[@"path"];
        NSDictionary *options = params[@"options"];
        
        JDBDatabase *database = path ? [JDBDatabase databaseAtPath:path withOptions:options] : [JDBDatabase databaseInMemoryWithOptions:options];
        
        it(@"should allocate a database object", ^{
            expect(database).toNot.beNil;
        });
        
        if (path) {
            it(@"should create a database file", ^{
                expect([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:nil]).to.beTruthy;
            });
        }
    });
    
    describe(@"in memory", ^{
        
        itShouldBehaveLike(@"factory with path and options", @{});
        
    });

    describe(@"in file", ^{
        
        NSString *dbPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"/JsonDB_DatabaseCreation_db.sqlite"];
    
        itShouldBehaveLike(@"factory with path and options", @{@"path": dbPath});
        
    });
    
});

SpecEnd
