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

NSString *JDBEscape(NSString *string) {
    return [NSString stringWithFormat:@"\"%@\"", [string stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""]];
}

NSString *JDBEscapeData(NSString *string) {
    return [NSString stringWithFormat:@"'%@'", [string stringByReplacingOccurrencesOfString:@"'" withString:@"''"]];
}

/*
 Here Be Dragons!
 Those are naive implementations to transform JSON criteria/sort into SQL query where/orderby where clause
 It employ a recursive traversal of the criteria and a basic state machine with a context stack
 */

void JDBTransformCriteriaToQuery(NSDictionary *criteria, NSMutableSet *paths, NSMutableString *query, NSMutableDictionary *parameters, NSError **error) {
    
    if (!criteria || criteria.count == 0) return;
    
    NSPredicate *filterOutCommand = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return [evaluatedObject rangeOfString:@"$"].location != 0;
    }];
    
    NSMutableArray *ctxs = [NSMutableArray arrayWithCapacity:10];
    [ctxs addObject:@"$and"];
    
    JDBTraverseType types = JDBTraverseTypeContainer | JDBTraverseTypeElementBegin | JDBTraverseTypeValue;
    
    JDBTraverse(criteria, types, ^id(id parentId, JDBTraverseType type, NSMutableArray *keys, NSString *key, NSUInteger index, id value) {
        
        //NSLog(@"%@ (%@:%@) (%@)", [keys componentsJoinedByString:@"."], key, [value class], [ctxs componentsJoinedByString:@"/"]);
        
        NSString *ctx = [ctxs lastObject];
        
        if (type & JDBTraverseTypeContainerBegin) {
            
            if (key && ([key isEqualToString:@"$and"] || [key isEqualToString:@"$or"] || [key isEqualToString:@"$in"])) [ctxs addObject:key];
            else [ctxs addObject:ctx];
            
            if ([key isEqualToString:@"$not"]) [query appendString:@"NOT "];
            
            if (key && [value count] > 1 && ([key isEqualToString:@"$and"] || [key isEqualToString:@"$or"] ||  [key isEqualToString:@"$not"])) [query appendString:@"("];
            
            if (key && [key isEqualToString:@"$in"]) {
                
                NSString *path = [[keys filteredArrayUsingPredicate:filterOutCommand] componentsJoinedByString:@"."];
                [paths addObject:path];
                
                [query appendFormat:@"%@ IN (", JDBEscape(path)];
                
            }
            
        } else if (type & JDBTraverseTypeContainerEnd) {
            
            [ctxs removeLastObject];
            
            if (key && [value count] > 1 && ([key isEqualToString:@"$and"] || [key isEqualToString:@"$or"] ||  [key isEqualToString:@"$not"])) [query appendString:@")"];
            else if (key && [key isEqualToString:@"$in"]) [query appendString:@")"];
            
        } else if (type & JDBTraverseTypeElementBegin) {
        
            if (index > 0) {
                if ([ctx isEqualToString:@"$and"]) [query appendString:@" AND "];
                else if ([ctx isEqualToString:@"$or"]) [query appendString:@" OR "];
                else if ([ctx isEqualToString:@"$in"]) [query appendString:@", "];
            }
            
        } else if (type & JDBTraverseTypeValueNull) {
            
            NSString *path = [[keys filteredArrayUsingPredicate:filterOutCommand] componentsJoinedByString:@"."];
            [paths addObject:path];
            
            NSString *not = @"";
            if (key && [key isEqualToString:@"$ne"]) not = @"NOT ";
            
            [query appendFormat:@"%@ IS %@NULL", JDBEscape(path), not];
            
        } else if (type & JDBTraverseTypeValue) {
            
            NSString *parameter = [NSString stringWithFormat:@"p%lu", (unsigned long)parameters.count];
            [parameters setObject:value forKey:parameter];
            
            if ([ctx isEqualToString:@"$in"]) {
            
                [query appendFormat:@":%@", parameter];
                
            } else {
                
                NSString *path = [[keys filteredArrayUsingPredicate:filterOutCommand] componentsJoinedByString:@"."];
                [paths addObject:path];
                
                NSString *op = @"=";
                if ([key isEqualToString:@"$eq"]) op = @"=";
                else if ([key isEqualToString:@"$ne"]) op = @"!=";
                else if ([key isEqualToString:@"$gt"]) op = @">";
                else if ([key isEqualToString:@"$gte"]) op = @">=";
                else if ([key isEqualToString:@"$lt"]) op = @"<";
                else if ([key isEqualToString:@"$lte"]) op = @"<=";
                else if ([key isEqualToString:@"$like"]) op = @"LIKE";
                
                [query appendFormat:@"%@ %@ :%@", JDBEscape(path), op, parameter];

            }
            
        }
        
        //NSLog(@"query: %@", query);
        return parentId;
        
    });
}

void JDBTransformSortToOrderBy(NSArray *sort, NSMutableSet *paths, NSMutableString *orderBy, NSError **error) {
    
    if (!sort || sort.count == 0) return;
    
    NSPredicate *filterOutCommand = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return [evaluatedObject rangeOfString:@"$"].location != 0;
    }];

    JDBTraverseType types = JDBTraverseTypeElementBegin | JDBTraverseTypeValue;
    
    JDBTraverse(sort, types, ^id(id parentId, JDBTraverseType type, NSMutableArray *keys, NSString *key, NSUInteger index, id value) {
        
        if (type & JDBTraverseTypeElementBegin) {
            
            if (index > 0) [orderBy appendString:@", "];
            
        } else if (type & JDBTraverseTypeValue) {
            
            NSString *path = nil;
            NSString *dir = @"";
            
            if (keys.count > 0) {
                
                path = [[keys filteredArrayUsingPredicate:filterOutCommand] componentsJoinedByString:@"."];
                
                if (type & (JDBTraverseTypeValueNumber | JDBTraverseTypeValueBoolean)) {
                    dir = [value boolValue] ? @"ASC" : @"DESC";
                } else if (type & JDBTraverseTypeValueString) {
                    if ([value rangeOfString:@"asc" options:NSCaseInsensitiveSearch].location == 0) dir = @"ASC";
                    else if ([value rangeOfString:@"desc" options:NSCaseInsensitiveSearch].location == 0) dir = @"DESC";
                }
                
            } else {
                
                path = [value description];
                
            }
            
            [paths addObject:path];
            
            
            [orderBy appendFormat:@"%@ %@", JDBEscape(path), dir];
            
        }
        
        return parentId;

    });
}
