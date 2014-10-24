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

typedef NS_OPTIONS(NSUInteger, JDBTraverseType) {
    JDBTraverseTypeObjectBegin = (1UL << 1),
    JDBTraverseTypeObjectEnd = (1UL << 2),
    JDBTraverseTypeArrayBegin = (1UL << 3),
    JDBTraverseTypeArrayEnd = (1UL << 4),
    JDBTraverseTypeElementBegin = (1UL << 5),
    JDBTraverseTypeElementEnd = (1UL << 6),
    JDBTraverseTypeValueNull = (1UL << 7),
    JDBTraverseTypeValueBoolean = (1UL << 8),
    JDBTraverseTypeValueNumber = (1UL << 9),
    JDBTraverseTypeValueString = (1UL << 10),
    JDBTraverseTypeObject = (JDBTraverseTypeObjectBegin | JDBTraverseTypeObjectEnd),
    JDBTraverseTypeArray = (JDBTraverseTypeArrayBegin | JDBTraverseTypeArrayEnd),
    JDBTraverseTypeContainerBegin = (JDBTraverseTypeObjectBegin | JDBTraverseTypeArrayBegin),
    JDBTraverseTypeContainerEnd = (JDBTraverseTypeObjectEnd | JDBTraverseTypeArrayEnd),
    JDBTraverseTypeContainer = (JDBTraverseTypeObject | JDBTraverseTypeArray),
    JDBTraverseTypeElement = (JDBTraverseTypeElementBegin | JDBTraverseTypeElementEnd),
    JDBTraverseTypeValue = (JDBTraverseTypeValueNull | JDBTraverseTypeValueBoolean | JDBTraverseTypeValueNumber | JDBTraverseTypeValueString),
    JDBTraverseTypeAll = (JDBTraverseTypeContainer | JDBTraverseTypeElement | JDBTraverseTypeValue)
};

typedef id (^JDBTraverseCallback)(id parentId, JDBTraverseType type, NSMutableArray *keys, NSString *key, NSUInteger index, id value);

void JDBTraverse(id root, JDBTraverseType types, JDBTraverseCallback callback);

void JDBTraverseObject(id parentId, NSDictionary *object, NSMutableArray *keys, NSString *key, NSUInteger index, JDBTraverseType types, JDBTraverseCallback callback);

void JDBTraverseArray(id parentId, NSArray *array, NSMutableArray *keys, NSString *key, NSUInteger index, JDBTraverseType types, JDBTraverseCallback callback);

void JDBTraverseElement(id parentId, id element, NSMutableArray *keys, NSString *key, NSUInteger index, JDBTraverseType types, JDBTraverseCallback callback);
