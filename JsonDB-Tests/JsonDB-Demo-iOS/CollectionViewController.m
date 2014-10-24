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

#import "CollectionViewController.h"

#import "JsonDB.h"

@interface CollectionViewController ()

@property (weak, nonatomic) IBOutlet UITextField *nameField;
@property (weak, nonatomic) IBOutlet UITextField *importURLField;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

@end

@implementation CollectionViewController

- (IBAction)save:(UIBarButtonItem *)sender {
    
    NSString *collectionName = self.nameField.text;
    if (!collectionName || [collectionName isEqualToString:@""]) return;
    
    NSURL *importURL = nil;
    if (self.importURLField.text && ![self.importURLField.text isEqualToString:@""]) {
        importURL = [NSURL URLWithString:self.importURLField.text];
    }
    
    sender.enabled = NO;
    self.nameField.enabled = NO;
    self.importURLField.enabled = NO;
    self.navigationItem.hidesBackButton = YES;
    [self.activityIndicator startAnimating];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        
        JDBCollection *collection = [self.database collection:collectionName];
        
        NSError *error = nil;
        
        if (importURL) {
            NSData *jsonData = [NSData dataWithContentsOfURL:importURL options:NSDataReadingUncached error:&error];
            if (!error) {
                id json = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
                if (!error) {
                    if ([json isKindOfClass:[NSDictionary class]]) {
                        [collection save:json];
                    } else if ([json isKindOfClass:[NSArray class]]) {
                        [json enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                            if ([obj isKindOfClass:[NSDictionary class]]) {
                                [collection save:obj];
                            }
                        }];
                    }
                }
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            sender.enabled = YES;
            self.nameField.enabled = YES;
            self.importURLField.enabled = YES;
            self.navigationItem.hidesBackButton = NO;
            [self.activityIndicator stopAnimating];
            
            if (error) {
                [[[UIAlertView alloc] initWithTitle:@"Error" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
            } else {
                [self.navigationController popViewControllerAnimated:YES];
            }
            
        });
    });
}

@end
