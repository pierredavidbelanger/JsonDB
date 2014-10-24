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

#import "JSONTextBehavior.h"

#import "JSONSyntaxHighlight.h"

@interface JSONTextBehavior () <UITextViewDelegate>

@end

@implementation JSONTextBehavior

+ (instancetype)instance {
    static id instance;
    static dispatch_once_t instance_once;
    dispatch_once(&instance_once, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (void)setLabel:(UILabel *)label JSONObject:(id)object {
//    label.text = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:object options:0 error:nil] encoding:NSUTF8StringEncoding];
    JSONSyntaxHighlight *syntaxHighlight = [[JSONSyntaxHighlight alloc] initWithJSON:object];
    label.attributedText = [syntaxHighlight highlightJSONWithPrettyPrint:NO];
}

- (void)setTextView:(UITextView *)textView JSONObject:(id)object {
    JSONSyntaxHighlight *syntaxHighlight = [[JSONSyntaxHighlight alloc] initWithJSON:object];
    textView.attributedText = [syntaxHighlight highlightJSON];
    textView.delegate = self;
}

- (void)textViewDidEndEditing:(UITextView *)textView {
    NSData *json = [textView.attributedText.string dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    id object = [NSJSONSerialization JSONObjectWithData:json options:0 error:&error];
    if (error) textView.backgroundColor = [UIColor colorWithRed:1.0 green:0 blue:0 alpha:0.01];
    else textView.backgroundColor = [UIColor whiteColor];
    textView.delegate = nil;
    [self setTextView:textView JSONObject:object];
}

- (void)textViewDidChange:(UITextView *)textView {
    NSData *json = [textView.attributedText.string dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    [NSJSONSerialization JSONObjectWithData:json options:0 error:&error];
    if (error) textView.backgroundColor = [UIColor colorWithRed:1.0 green:0 blue:0 alpha:0.05];
    else textView.backgroundColor = [UIColor colorWithRed:0 green:1 blue:0 alpha:0.05];
}

@end
