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

#import "QueryViewController.h"

#import "DocumentsViewController.h"

#import "JSONTextBehavior.h"

#import "JsonDB.h"

@interface QueryViewController ()

@property (weak, nonatomic) IBOutlet UITextField *nameField;
@property (weak, nonatomic) IBOutlet UITextView *criteriaField;
@property (weak, nonatomic) IBOutlet UITextView *sortField;
@property (weak, nonatomic) IBOutlet UITextView *projectionField;

@end

@implementation QueryViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    NSString *name = self.query[@"name"];
    if (!name) {
        name = @"";
        self.navigationItem.title = self.query[@"collectionName"];
    } else {
        self.navigationItem.title = name;
    }
    
    NSDictionary *criteria = self.query[@"criteria"];
    if (!criteria) criteria = @{};
    
    NSArray *sort = self.query[@"sort"];
    if (!sort) sort = @[];
    
    NSArray *projection = self.query[@"projection"];
    if (!projection) projection = @[];
    
    self.nameField.text = name;
    
    [[JSONTextBehavior instance] setTextView:self.criteriaField JSONObject:criteria];
    
    [[JSONTextBehavior instance] setTextView:self.sortField JSONObject:sort];
    
    [[JSONTextBehavior instance] setTextView:self.projectionField JSONObject:projection];
}

- (NSMutableDictionary *)editedQuery {
    NSError *error = nil;
    
    NSString *name = self.nameField.text;
    
    NSDictionary *criteria = [NSJSONSerialization JSONObjectWithData:[self.criteriaField.attributedText.string dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
    if (error || ![criteria isKindOfClass:[NSDictionary class]]) {
        [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Criteria field must be a valid JSON object" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
        return nil;
    }
    
    NSArray *sort = [NSJSONSerialization JSONObjectWithData:[self.sortField.attributedText.string dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
    if (error || ![sort isKindOfClass:[NSArray class]]) {
        [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Sort field must be a valid JSON array" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
        return nil;
    }
    
    NSArray *projection = [NSJSONSerialization JSONObjectWithData:[self.projectionField.attributedText.string dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
    if (error || ![sort isKindOfClass:[NSArray class]]) {
        [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Projection field must be a valid JSON array" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
        return nil;
    }
    
    NSMutableDictionary *mutableQuery = [self.query mutableCopy];
    mutableQuery[@"name"] = name;
    mutableQuery[@"criteria"] = criteria;
    mutableQuery[@"sort"] = sort;
    mutableQuery[@"projection"] = projection;
    self.query = mutableQuery;
    
    return mutableQuery;
}

- (IBAction)save:(id)sender {
    
    NSMutableDictionary *mutableQuery = [self editedQuery];
    if (!mutableQuery) return;
    
    [[self.database collection:@"_col_query"] save:mutableQuery];
    
    [self.navigationController popViewControllerAnimated:YES];
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    if ([identifier isEqualToString:@"showDocuments"]) {
        NSMutableDictionary *mutableQuery = [self editedQuery];
        return mutableQuery != nil;
    }
    return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"showDocuments"]) {
        NSMutableDictionary *mutableQuery = [self editedQuery];
        [(DocumentsViewController *)segue.destinationViewController setDatabase:self.database];
        [(DocumentsViewController *)segue.destinationViewController setQuery:mutableQuery];
    }
}

@end
