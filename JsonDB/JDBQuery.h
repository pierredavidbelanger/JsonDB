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

typedef NS_OPTIONS(NSUInteger, JDBModifyOperation) {
    JDBModifyOperationNoop = (1UL << 0),
    JDBModifyOperationStop = (1UL << 1),
    JDBModifyOperationRollback = (1UL << 2),
    JDBModifyOperationReturnOld = (1UL << 3),
    JDBModifyOperationReturnNew = (1UL << 4),
    JDBModifyOperationUpdate = (1UL << 5),
    JDBModifyOperationRemove = (1UL << 6)
};

typedef id (^JDBProjectionBlock)(NSDictionary *document);
typedef JDBModifyOperation (^JDBModificationBlock)(NSMutableDictionary *document);

@class JDBView;

@interface JDBQuery : NSObject

@property (strong, readonly) JDBView *view;

- (NSUInteger)count;

- (NSArray *)all;
- (NSArray *)allAndProject:(JDBProjectionBlock)block;
- (NSArray *)allAndProjectKeyPaths:(NSArray *)keyPaths;
- (NSArray *)allAndModify:(JDBModificationBlock)block;

- (NSArray *)allInRange:(NSRange)range;
- (NSArray *)allInRange:(NSRange)range andProject:(JDBProjectionBlock)block;
- (NSArray *)allInRange:(NSRange)range andProjectKeyPaths:(NSArray *)keyPaths;
- (NSArray *)allInRange:(NSRange)range andModify:(JDBModificationBlock)block;

- (id)first;
- (id)firstAndProject:(JDBProjectionBlock)block;
- (id)firstAndProjectKeyPaths:(NSArray *)keyPaths;
- (id)firstAndModify:(JDBModificationBlock)block;

- (NSUInteger)removeAll;
- (NSUInteger)removeAllInRange:(NSRange)range;
- (NSUInteger)removeFirst;

@end
