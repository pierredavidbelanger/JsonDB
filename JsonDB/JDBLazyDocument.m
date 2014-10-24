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

@interface JDBLazyDocument ()

@property (strong) NSError *error;

@property (strong) JDBQuery *query;
@property (strong) FMResultSet *rs;

@property (strong) NSData *originalDocumentData;
@property (strong) NSDictionary *originalDocument;
@property (strong) NSMutableDictionary *mutableDocument;

@end

@implementation JDBLazyDocument

- (instancetype)initWithQuery:(JDBQuery *)query andResultSet:(FMResultSet *)rs {
    self.error = nil;
    self.query = query;
    self.rs = rs;
    self.originalDocument = nil;
    self.mutableDocument = nil;
    return self;
}

- (void)loadOriginalDocument {
    if (!self.originalDocument) {
        NSError *error = nil;
        self.originalDocumentData = [self.rs dataForColumn:@"_jdb_document"];
        // todo: check for db error
        if (error) {
            self.error = error;
            return;
        }
        self.originalDocument = [self.query.view.collection.database JSONObjectWithData:self.originalDocumentData error:&error];
    }
}

- (void)loadMutableDocument {
    if (!self.mutableDocument) {
        [self loadOriginalDocument];
        if (self.originalDocument) {
            NSError *error = nil;
            self.mutableDocument = [self.query.view.collection.database JSONMutableObjectWithData:self.originalDocumentData error:&error];
            if (error) self.error = error;
        }
    }
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    return [NSMutableDictionary instanceMethodSignatureForSelector:sel];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    if (!self.mutableDocument) [self loadMutableDocument];
    [invocation invokeWithTarget:self.mutableDocument];
}

@end
