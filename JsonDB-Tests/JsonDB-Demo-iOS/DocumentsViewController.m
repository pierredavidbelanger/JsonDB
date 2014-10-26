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

#import "DocumentsViewController.h"

#import "DocumentViewController.h"
#import "JSONTextBehavior.h"

#import "JsonDB.h"

@interface DocumentsViewController ()

@property (strong) JDBQuery *dbQuery;

@property NSRange pageRange;
@property (strong) NSArray *pageObjects;

@end

@implementation DocumentsViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationItem.title = self.query[@"name"] ? self.query[@"name"] : self.query[@"collectionName"];
    self.dbQuery = [[self.database collection:self.query[@"collectionName"]] find:self.query[@"criteria"] sort:self.query[@"sort"]];
    self.pageRange = NSMakeRange(0, 50);
    self.pageObjects = nil;
    [self.tableView reloadData];
}

- (NSIndexPath *)pagedIndexPath:(NSIndexPath *)indexPath {
    if (!self.pageObjects || indexPath.row < self.pageRange.location || indexPath.row >= self.pageRange.location + self.pageRange.length) {
        if (indexPath.row < self.pageRange.location || indexPath.row >= self.pageRange.location + self.pageRange.length) {
            self.pageRange = NSMakeRange((indexPath.row / self.pageRange.length) * self.pageRange.length, self.pageRange.length);
        }
        if (self.query[@"projection"]) {
            NSArray *keyPaths = [[NSOrderedSet orderedSetWithArray:[self.query[@"projection"] arrayByAddingObject:@"id"]] array];
            self.pageObjects = [self.dbQuery allInRange:self.pageRange andProjectKeyPaths:keyPaths];
        } else {
            self.pageObjects = [self.dbQuery allInRange:self.pageRange];
        }
    }
    return [NSIndexPath indexPathForRow:(indexPath.row % self.pageRange.length) inSection:indexPath.section];
}

- (id)pageObjectAtIndexPath:(NSIndexPath *)indexPath {
    NSIndexPath *pageIndexPath = [self pagedIndexPath:indexPath];
    return self.pageObjects[pageIndexPath.row];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.dbQuery count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"default"];
    NSDictionary *object = [self pageObjectAtIndexPath:indexPath];
    [[JSONTextBehavior instance] setLabel:cell.textLabel JSONObject:object];
    return cell;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"addDocument"]) {
        NSDictionary *object = @{};
        [(DocumentViewController *)segue.destinationViewController setDatabase:self.database];
        [(DocumentViewController *)segue.destinationViewController setQuery:self.query];
        [(DocumentViewController *)segue.destinationViewController setDocument:object];
    } else if ([segue.identifier isEqualToString:@"showDocument"]) {
        NSDictionary *object = [self pageObjectAtIndexPath:[self.tableView indexPathForCell:sender]];
        object = [[[self.database collection:self.query[@"collectionName"]] find:@{@"id": object[@"id"]}] first];
        [(DocumentViewController *)segue.destinationViewController setDatabase:self.database];
        [(DocumentViewController *)segue.destinationViewController setQuery:self.query];
        [(DocumentViewController *)segue.destinationViewController setDocument:object];
    }
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSDictionary *object = [self pageObjectAtIndexPath:indexPath];
        if ([[[self.database collection:self.query[@"collectionName"]] find:@{@"id": object[@"id"]}] removeFirst]) {
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }
}

@end
