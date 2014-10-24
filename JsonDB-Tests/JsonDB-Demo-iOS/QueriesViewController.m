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

#import "QueriesViewController.h"

#import "QueryViewController.h"
#import "DocumentsViewController.h"

#import "JsonDB.h"

@interface QueriesViewController ()

@property (strong) NSArray *objects;

@end

@implementation QueriesViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationItem.title = self.collectionName;
    self.objects = [[[self.database collection:@"_col_query"] find:@{@"collectionName": self.collectionName} sort:@[@"name"]] all];
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.objects.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"default"];
    NSDictionary *object = self.objects[indexPath.row];
    cell.textLabel.text = object[@"name"];
    cell.detailTextLabel.text = @"...";
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSUInteger count = [[[self.database collection:object[@"collectionName"]] find:object[@"criteria"] sort:object[@"sort"]] count];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([tableView.visibleCells containsObject:cell]) {
                cell.detailTextLabel.text = [@(count) description];
            }
        });
    });
    return cell;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"addQuery"]) {
        [(QueryViewController *)segue.destinationViewController setDatabase:self.database];
        [(QueryViewController *)segue.destinationViewController setQuery:@{@"collectionName": self.collectionName}];
    } else if ([segue.identifier isEqualToString:@"showQuery"]) {
        NSDictionary *object = self.objects[[self.tableView indexPathForCell:sender].row];
        [(QueryViewController *)segue.destinationViewController setDatabase:self.database];
        [(QueryViewController *)segue.destinationViewController setQuery:object];
    } else if ([segue.identifier isEqualToString:@"showDocuments"]) {
        NSDictionary *object = self.objects[[self.tableView indexPathForCell:sender].row];
        [(DocumentsViewController *)segue.destinationViewController setDatabase:self.database];
        [(DocumentsViewController *)segue.destinationViewController setQuery:object];
    }
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSDictionary *object = self.objects[indexPath.row];
        if ([[[self.database collection:@"_col_query"] find:@{@"id": object[@"id"]}] removeFirst]) {
            NSMutableArray *mutableObjects = [self.objects mutableCopy];
            [mutableObjects removeObjectAtIndex:indexPath.row];
            self.objects = mutableObjects;
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }
}

@end
