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

#import <JsonDB+Unsafe.h>

SpecBegin(CornerCase)

describe(@"jdb corner case", ^{
    
    __block JDBDatabase *database;
    
    beforeAll(^{
        NSNumber *verbose = @NO;
        NSDictionary *options = @{JDBDatabaseOptionVerboseKey: verbose};
        database = [JDBDatabase databaseInMemoryWithOptions:options];
    });
    
    it(@"should allow space in collection name", ^{
        JDBCollection *test = [database collection:@"te st"];
        expect(test).toNot.beNil;

        NSDictionary *doc = @{};
        id docId = [test save:doc];
        expect(docId).toNot.beNil;
        
        NSArray *results = [[test find:nil] all];
        expect(results).toNot.beNil;
        expect(results).to.haveCountOf(1);
        NSLog(@"results: %@", @(results.count));
    });
    
    it(@"should allow double quote in collection name", ^{
        JDBCollection *test = [database collection:@"te\"s\\\"t''"];
        expect(test).toNot.beNil;
        
        NSDictionary *doc = @{};
        id docId = [test save:doc];
        expect(docId).toNot.beNil;
        
        NSArray *results = [[test find:nil] all];
        expect(results).toNot.beNil;
        expect(results).to.haveCountOf(1);
        NSLog(@"results: %@", @(results.count));
    });
    
    it(@"should allow space in json key", ^{
        JDBCollection *test = [database collection:@"test"];
        
        NSDictionary *doc = @{@" _": @"space before",
                              @"_ ": @"space after",
                              @"_ _": @"space inside",
                              @"_ _ _": @{@"_ _": @"sub space inside"}};
        [test save:doc];

        NSArray *results = [[test find:@{@" _": @{@"$ne": [NSNull null]}, @"_ ": @{@"$ne": [NSNull null]}, @"_ _": @{@"$ne": [NSNull null]}, @"_ _ _._ _": @{@"$ne": [NSNull null]}, @"does Not Exists": [NSNull null]}] all];
        expect(results).toNot.beNil;
        expect(results).to.haveCountOf(1);
        NSLog(@"results: %@", @(results.count));
    });
    
    it(@"should allow single quote in json key", ^{
        JDBCollection *test = [database collection:@"test"];
        
        NSDictionary *doc = @{@"'_": @"quote before",
                              @"_'": @"quote after",
                              @"_'_": @"quote inside",
                              @"_'_'_": @{@"_'_": @"sub quote inside"}};
        [test save:doc];
        
        NSArray *results = [[test find:@{@"'_": @{@"$ne": [NSNull null]}, @"_'": @{@"$ne": [NSNull null]}, @"_'_": @{@"$ne": [NSNull null]}, @"_'_'_._'_": @{@"$ne": [NSNull null]}, @"does'Not'Exists": [NSNull null]}] all];
        expect(results).toNot.beNil;
        expect(results).to.haveCountOf(1);
        NSLog(@"results: %@", @(results.count));
    });
    
    it(@"should allow custom (unsafe) SQL query if needed", ^{
        JDBCollection *test = [database collection:@"test_product"];
        
        [test save:@{@"label": @"No price product"}];
        [test save:@{@"label": @"Costly product", @"price": @"$16.99"}];
        [test save:@{@"label": @"Cheap product", @"price": @"$6.99"}];
        
        NSArray *results = [[[test viewForPaths:@[@"label", @"price"]] where:@"\"label\" LIKE :label AND NOT \"price\" IS NULL" parameters:@{@"label": @"% product"} orderBy:@"CAST(SUBSTR(\"price\", 2) AS DECIMAL)"] all];
        expect(results).toNot.beNil;
        expect(results).to.haveCountOf(2);
        expect(results[0][@"price"]).to.equal(@"$6.99");
    });
    
    it(@"should support join", ^{
        
        // work in progress
        
    });
    
});

SpecEnd
