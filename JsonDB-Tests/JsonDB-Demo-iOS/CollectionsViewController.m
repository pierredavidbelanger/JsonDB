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

#import "CollectionsViewController.h"

#import "CollectionViewController.h"
#import "QueriesViewController.h"
#import "DocumentsViewController.h"

#import "JsonDB.h"
#import "TRZSlideLicenseViewController/TRZSlideLicenseViewController.h"

@interface CollectionsViewController ()

@property NSArray *objects;

@end

@implementation CollectionsViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.objects = [self.database collectionNames];
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.objects.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"default"];
    NSString *object = self.objects[indexPath.row];
    cell.textLabel.text = object;
    cell.detailTextLabel.text = @"...";
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSUInteger count = [[[self.database collection:object] find:nil] count];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([tableView.visibleCells containsObject:cell]) {
                cell.detailTextLabel.text = [@(count) description];
            }
        });
    });
    return cell;
}

- (IBAction)viewLicenses:(id)sender {
    TRZSlideLicenseViewController *controller = [[TRZSlideLicenseViewController alloc] init];
    controller.podsPlistName = @"Pods-JsonDB-Demo-iOS-acknowledgements.plist";
    controller.navigationItem.title = @"Licenses";
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"addCollection"]) {
        [(CollectionViewController *)segue.destinationViewController setDatabase:self.database];
    } else if ([segue.identifier isEqualToString:@"showQueries"]) {
        NSString *object = self.objects[[self.tableView indexPathForCell:sender].row];
        [(QueriesViewController *)segue.destinationViewController setDatabase:self.database];
        [(QueriesViewController *)segue.destinationViewController setCollectionName:object];
    } else if ([segue.identifier isEqualToString:@"showDocuments"]) {
        NSString *object = self.objects[[self.tableView indexPathForCell:sender].row];
        [(DocumentsViewController *)segue.destinationViewController setDatabase:self.database];
        [(DocumentsViewController *)segue.destinationViewController setQuery:@{@"name": @"All", @"collectionName": object}];
    }
}

@end
