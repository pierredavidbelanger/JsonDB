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

#import "AppDelegate.h"

#import "CollectionsViewController.h"

@interface AppDelegate ()

@property (strong, nonatomic) JDBDatabase *database;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    NSString *dbPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"/main.jsondb"];
    NSLog(@"dbPath:%@", dbPath);
    NSMutableDictionary *options = [NSMutableDictionary dictionary];
#if DEBUG
    options[JDBDatabaseOptionVerboseKey] = @1;
#endif
    self.database = [JDBDatabase databaseAtPath:dbPath withOptions:options];
    
    [self demoData];
    
    UINavigationController *navigationController = (UINavigationController *)self.window.rootViewController;
    CollectionsViewController *collectionsViewController = (CollectionsViewController *)navigationController.topViewController;
    collectionsViewController.database = self.database;
    
    return YES;
}

- (void)demoData {
    
    JDBCollection *userCollection = [self.database collection:@"user"];
    if (![[userCollection find:nil] count]) {
        NSData *usersData = [NSData dataWithContentsOfURL:[[NSBundle bundleForClass:[self class]] URLForResource:@"users" withExtension:@"json"]];
        NSArray *users = [NSJSONSerialization JSONObjectWithData:usersData options:0 error:nil];
        [users enumerateObjectsUsingBlock:^(NSDictionary *user, NSUInteger idx, BOOL *stop) {
            [userCollection save:user];
        }];
    }
    
    JDBCollection *colQueryCollection = [self.database collection:@"_col_query"];
    if (![[colQueryCollection find:@{@"collectionName": @"user"}] count]) {
        [colQueryCollection save:@{@"name": @"Find all sorted by name", @"collectionName": @"user", @"sort": @[@"name"], @"projection": @[@"name"]}];
        [colQueryCollection save:@{@"name": @"Find active sorted by index", @"collectionName": @"user", @"criteria": @{@"isActive": @YES}, @"sort": @[@"index"]}];
        [colQueryCollection save:@{@"name": @"Find female sorted by company desc", @"collectionName": @"user", @"criteria": @{@"gender": @"female"}, @"sort": @[@{@"company": @NO}]}];
    }
}

@end
