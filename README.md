# JsonDB

[![CI Status](http://img.shields.io/travis/pierredavidbelanger/JsonDB.svg?style=flat)](https://travis-ci.org/pierredavidbelanger/JsonDB)
[![Version](https://img.shields.io/cocoapods/v/JsonDB.svg?style=flat)](http://cocoadocs.org/docsets/JsonDB)
[![License](https://img.shields.io/cocoapods/l/JsonDB.svg?style=flat)](http://cocoadocs.org/docsets/JsonDB)
[![Platform](https://img.shields.io/cocoapods/p/JsonDB.svg?style=flat)](http://cocoadocs.org/docsets/JsonDB)

## Example usage

Create a file path where to open/save the database (here, on iOS, `main.jsondb` in the application's Document directory)

```objc
NSString *dbPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"/main.jsondb"];
```

Create/open a database at the specified path

```objc
JDBDatabase *database = [JDBDatabase databaseAtPath:dbPath];
```

Create/get a collection of document

```objc
JDBCollection *collection = [database collection:@"GameScore"];
```

Insert schema less JSON documents into the collection

```objc
[collection save:@{@"playerName": @"Sean Plott", @"score": @1337, @"cheatMode": @NO}];
[collection save:@{@"playerName": @"John Smith", @"score": @9001, @"cheatMode": @NO}];
[collection save:@{@"playerName": @"John Appleseed", @"score": @1234, @"cheatMode": @YES}];
```

Find who is cheating (this will returns an array of document)

```objc
NSArray *cheaters = [[collection find:@{@"cheatMode": @YES}] all];
expect(cheaters).to.haveCountOf(1);
expect(cheaters[0][@"playerName"]).to.equal(@"John Appleseed");
```

Find the players named John ordered alphabetically

```objc
NSArray *johns = [[collection find:@{@"playerName": @{@"$like": @"John %"}} sort:@[@"playerName"]] all];
expect(johns).to.haveCountOf(2);
expect(cheaters[0][@"playerName"]).to.equal(@"John Appleseed");
```

Find the first one with a score over 9000, flag it as a cheater and return the old document

```objc
NSDictionary *over9000 = [[collection find:@{@"score": @{@"$gt": @9000}}] firstAndModify:^JDBModifyOperation(NSMutableDictionary *document) {
    document[@"cheatMode"] = @YES;
    return JDBModifyOperationUpdate | JDBModifyOperationReturnOld;
}];
expect(over9000[@"cheatMode"]).to.equal(NO);
```

## Demo

To run the demo application, in a terminal simply run:

    $ pod try JsonDB

Or clone the repo, and run `pod install` from the `JsonDB-Tests` directory, and open the generated `JsonDB-Tests.xcworkspace`.

Then run the target named `JsonDB-Demo-iOS`.

## Installation

JsonDB is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

    pod "JsonDB"

## Author

Pierre-David Bélanger, pierredavidbelanger@gmail.com

## License

JsonDB is available under the MIT license. See the LICENSE file for more info.
