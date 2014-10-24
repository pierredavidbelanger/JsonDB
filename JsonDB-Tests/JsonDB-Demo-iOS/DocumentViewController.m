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

#import "DocumentViewController.h"

#import "JSONTextBehavior.h"

#import "JsonDB.h"

@interface DocumentViewController ()

@property (weak, nonatomic) IBOutlet UITextView *documentField;

@end

@implementation DocumentViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationItem.title = self.query[@"collectionName"];
    [[JSONTextBehavior instance] setTextView:self.documentField JSONObject:self.document];
}

- (IBAction)save:(id)sender {
    
    NSError *error = nil;
    
    NSDictionary *document = [NSJSONSerialization JSONObjectWithData:[self.documentField.attributedText.string dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
    if (error || ![document isKindOfClass:[NSDictionary class]]) {
        [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Document must be a valid JSON object" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
        return;
    }
    
    [[self.database collection:self.query[@"collectionName"]] save:document];
    
    [self.navigationController popViewControllerAnimated:YES];
    
}

@end
