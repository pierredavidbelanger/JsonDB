# JsonDB

[![CI Status](http://img.shields.io/travis/pierredavidbelanger/JsonDB.svg?style=flat)](https://travis-ci.org/pierredavidbelanger/JsonDB)
[![Version](https://img.shields.io/cocoapods/v/JsonDB.svg?style=flat)](http://cocoadocs.org/docsets/JsonDB)
[![License](https://img.shields.io/cocoapods/l/JsonDB.svg?style=flat)](http://cocoadocs.org/docsets/JsonDB)
[![Platform](https://img.shields.io/cocoapods/p/JsonDB.svg?style=flat)](http://cocoadocs.org/docsets/JsonDB)

JsonDB is a [simple](#architecture) in process database to store, query and manipulate JSON documents in Objective-C for OS X (10.7+) and iOS (5.0+). It's built on top of the excellent [FMDB](https://github.com/ccgus/fmdb) which is an Objective-C wrapper around [SQLite](http://www.sqlite.org/).

This project was born as a little private helper library in a toy OS X project where I needed to cache and query a fair amount of JSON documents. The library somehow evolved into a reusable standalone project.

I want to publish it as open source because I think it can be useful to someone else, but also to teach myself how to create and maintain a [Pod](http://cocoapods.org), use [Travis CI](https://travis-ci.org) and use [Specta](https://github.com/specta/specta) and [Expecta](https://github.com/specta/expecta).

I hope you enjoy this project.

## Stability

You should expect the public API to change until I tag a `1.0.0` version. After that, I will try to follow as much as possible the [Semantic Versioning](http://semver.org/).

JsonDB should be compatible with Swift. I will soon make a test case to confirm this.

## Get Started

Try the [demo app](#demo).

Or [install](#installation) the library and follow the example [usage](#usage).

The [documentation](http://cocoadocs.org/docsets/JsonDB) should be up soon.

## Architecture

TL;DR: see the [usage](#usage) section if you only read code :)

The entry point in JsonDB is the `JDBDatabase`. You create an instance of `JDBDatabase` and specify to persist data on file or only in memory.

With an instance of `JDBDatabase` you then get a named `JDBCollection` which is a collection of documents (You can see `JDBCollection` as an SQL table).

With a `JDBCollection` you can insert and update documents. You can also create a `JDBView`, which is a queryable subset of JSON paths (You can see `JDBView` as an SQL view).

You can also query the `JDBCollection` directly, in which case a `JDBView` will be created on the fly for you, tailored for your query criteria and sort descriptor.

With a `JDBCollection` or a `JDBView`, you can create a `JDBQuery` by specifying a query criteria and sort descriptor.

In either ways, a `JDBQuery` will be created (you can see `JDBQuery` as a kind of SQL prepared statement). With a `JDBQuery` you can fetch the first document only or all the documents with an optional `NSRange` and/or projection. You can also (transactionally) batch remove and modify documents.

Finally, in JsonDB, a document is any objects graph compatible with [NSJSONSerialization](https://developer.apple.com/library/ios/documentation/Foundation/Reference/NSJSONSerialization_Class/) with a `NSDictionary` as the top level object.

## Demo

The demo application is a generic database browser. It allows you to create/list collections, import JSON documents from URL, create/save/list/execute queries, create/save/list documents.

To run the demo application:

### With `pod try`

In a terminal, simply execute:

```bash
$ pod try JsonDB
```

and run the target named `JsonDB-Demo-iOS` in Xcode.

### With `git clone`

Clone the repository and run `pod install` from the `JsonDB-Tests` directory:

```bash
$ git clone https://github.com/pierredavidbelanger/JsonDB.git
$ cd JsonDB/JsonDB-Tests
$ pod install
```

open the workspace:

```bash
$ open JsonDB-Tests.xcworkspace
```

and run the target named `JsonDB-Demo-iOS` in Xcode.

## Installation

### Using CocoaPods

JsonDB is available through [CocoaPods](http://cocoapods.org). To install
the latest version, simply add the following line to your Podfile:

```
pod "JsonDB"
```

### Manually

[Download](https://github.com/pierredavidbelanger/JsonDB/archive/master.zip) and unzip the project. Every file you need is under the `JsonDB` directory. But, you will also need to install the [dependencies](#requirements) manually.

### Import

After adding the pod (or installing the library) to your project, just import it:

```objc
#import "JsonDB.h"
```

and follow the example [usage](#usage).

## Requirements

JsonDB needs OS X (10.7+) or iOS (5.0+).

It also needs [FMDB](https://github.com/ccgus/fmdb) which is automatically installed if you use [CocoaPods](http://cocoapods.org) (you do right ?).

## Usage

Open a database at the specified path (here, on iOS, `main.jsondb` in the application's Document directory will be created if it does not exists)

```objc
NSString *dbPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"/main.jsondb"];
JDBDatabase *database = [JDBDatabase databaseAtPath:dbPath];
```

Get a collection of document (will be created on the fly if it does not exists)

```objc
JDBCollection *collection = [database collection:@"GameScore"];
```

Insert schema less documents into the collection (an id will be auto generated for each document since they do not have one)

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

## Author

Pierre-David Bélanger, pierredavidbelanger@gmail.com

## License

JsonDB is available under the MIT license. See the LICENSE file for more info.
