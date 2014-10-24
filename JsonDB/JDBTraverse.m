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

void JDBTraverse(id root, JDBTraverseType types, JDBTraverseCallback callback) {
    
    NSMutableArray *keys = [NSMutableArray arrayWithCapacity:10];
    
    JDBTraverseElement(nil, root, keys, nil, 0, types, callback);
}

void JDBTraverseElement(id parentId, id element, NSMutableArray *keys, NSString *key, NSUInteger index, JDBTraverseType types, JDBTraverseCallback callback) {
    
    if ([element isKindOfClass:[NSDictionary class]]) {
        
        JDBTraverseObject(parentId, element, keys, key, index, types, callback);
    } else if ([element isKindOfClass:[NSArray class]]) {
        
        JDBTraverseArray(parentId, element, keys, key, index, types, callback);
    } else {
        
        if (types & JDBTraverseTypeValue) {
            
            JDBTraverseType type = JDBTraverseTypeValueString;
            
            if ([element isKindOfClass:[NSNull class]]) {
                
                type = JDBTraverseTypeValueNull;
                
            } else if ([element isKindOfClass:[NSNumber class]]) {

                if (strcmp([element objCType], @encode(BOOL)) == 0) {
                    type = JDBTraverseTypeValueBoolean;
                } else {
                    type = JDBTraverseTypeValueNumber;
                }
                
            } else if ([element isKindOfClass:[NSString class]]) {
                
                type = JDBTraverseTypeValueString;
                
            } else {
                
                type = JDBTraverseTypeValueString;
                element = [element description];
                
            }
            
            callback(parentId, type, keys, key, index, element);
        }
    }
}

void JDBTraverseObject(id parentId, NSDictionary *object, NSMutableArray *keys, NSString *key, NSUInteger index, JDBTraverseType types, JDBTraverseCallback callback) {
    
    id containerId = nil;
    if (types & JDBTraverseTypeObjectBegin) containerId = callback(parentId, JDBTraverseTypeObjectBegin, keys, key, index, object);
    
    [[[object allKeys] sortedArrayUsingSelector:@selector(compare:)] enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop) {
        
        id obj = object[key];
        
        if (types & JDBTraverseTypeElementBegin) callback(containerId, JDBTraverseTypeElementBegin, keys, key, idx, obj);
        
        [keys addObject:key];
        JDBTraverseElement(containerId, obj, keys, key, idx, types, callback);
        [keys removeLastObject];
        
        if (types & JDBTraverseTypeElementEnd) callback(containerId, JDBTraverseTypeElementEnd, keys, key, idx, obj);
        
    }];
    
    if (types & JDBTraverseTypeObjectEnd) callback(parentId, JDBTraverseTypeObjectEnd, keys, key, index, object);
}

void JDBTraverseArray(id parentId, NSArray *array, NSMutableArray *keys, NSString *key, NSUInteger index, JDBTraverseType types, JDBTraverseCallback callback) {
    
    id containerId = nil;
    if (types & JDBTraverseTypeArrayBegin) containerId = callback(parentId, JDBTraverseTypeArrayBegin, keys, key, index, array);
    
    [array enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        
        if (types & JDBTraverseTypeElementBegin) callback(containerId, JDBTraverseTypeElementBegin, keys, key, idx, obj);
        
        JDBTraverseElement(containerId, obj, keys, nil, idx, types, callback);
        
        if (types & JDBTraverseTypeElementEnd) callback(containerId, JDBTraverseTypeElementEnd, keys, key, idx, obj);
        
    }];
    
    if (types & JDBTraverseTypeArrayEnd) callback(parentId, JDBTraverseTypeArrayEnd, keys, key, index, array);
}
