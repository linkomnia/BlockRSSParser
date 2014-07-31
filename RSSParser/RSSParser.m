//
//  RSSParser.m
//  RSSParser
//
//  Created by Thibaut LE LEVIER on 1/31/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RSSParser.h"
#import <AFHTTPClient.h>

static dispatch_queue_t rssparser_success_callback_queue() {
    static dispatch_queue_t parser_success_callback_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        parser_success_callback_queue = dispatch_queue_create("rssparser.success_callback.processing", DISPATCH_QUEUE_SERIAL);
    });

    return parser_success_callback_queue;
}

@implementation RSSParser {
    RSSItem *_currentItem;
    NSMutableArray *_items;
    NSMutableString *_tmpString;
    void (^_block)(NSString *feedTitle, NSString *feedIconURL, NSArray *feedItems);

    NSString *_feedTitle;
    NSString *_feedIconURL;
}

+ (AFHTTPClient *)sharedClient
{
    static AFHTTPClient *client = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        client = [[AFHTTPClient alloc] initWithBaseURL:[NSURL URLWithString:@"http://www.apple.com"]];
    });
    return client;
}

#pragma mark lifecycle

- (id)init
{
    self = [super init];
    if (self) {
        _items = [[NSMutableArray alloc] init];
    }
    return self;
}

#pragma mark -

#pragma mark parser

+ (void)parseRSSFeedForRequest:(NSURLRequest *)urlRequest
                       success:(void (^)(NSString *feedTitle, NSString *feedIconURL, NSArray *feedItems))success
                       failure:(void (^)(NSError *error))failure
{
    RSSParser *parser = [[RSSParser alloc] init];
    [parser parseRSSFeedForRequest:urlRequest success:success failure:failure];
}


- (void)parseRSSFeedForRequest:(NSURLRequest *)urlRequest
                                          success:(void (^)(NSString *feedTitle, NSString *feedIconURL, NSArray *feedItems))success
                                          failure:(void (^)(NSError *error))failure
{
    
    _block = [success copy];
    
    AFXMLRequestOperation *operation = [RSSParser XMLParserRequestOperationWithRequest:urlRequest success:^(NSURLRequest *request, NSHTTPURLResponse *response, NSXMLParser *XMLParser) {
        [XMLParser setDelegate:self];
        [XMLParser parse];
        NSError *error = [XMLParser parserError];
        if (error) {
            NSLog(@"RSS parse error: %@", error);
        }
        _block(_feedTitle, _feedIconURL, _items);
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, NSXMLParser *XMLParse) {
        failure(error);
    }];

    [operation setSuccessCallbackQueue:rssparser_success_callback_queue()];
    [[[self class] sharedClient] enqueueHTTPRequestOperation:operation];
}

#pragma mark -

#pragma mark AFNetworking AFXMLRequestOperation acceptable Content-Type overwriting

+ (NSSet *)defaultAcceptableContentTypes {
    return [NSSet setWithObjects:@"application/xml", @"text/xml",@"application/rss+xml", @"application/atom+xml", nil];
}
+ (NSSet *)acceptableContentTypes {
    return [self defaultAcceptableContentTypes];
}
#pragma mark -

#pragma mark NSXMLParser delegate

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict
{
    if ([elementName isEqualToString:@"item"] || [elementName isEqualToString:@"entry"]) {
        _currentItem = [[RSSItem alloc] init];
    }

    if ([elementName isEqualToString:@"enclosure"] && _currentItem) {
        NSString *url = attributeDict[@"url"];
        NSString *type = attributeDict[@"type"];
        if (url && [type hasPrefix:@"image/"]) {
            [_currentItem addImageFromEnclosure:url];
        }
    }

    if ([elementName isEqualToString:@"media:content"]) {
        NSString *url = attributeDict[@"url"];
        NSString *medium = attributeDict[@"medium"];
        if (url && [medium isEqualToString:@"image"]) {
            [_currentItem addImageFromEnclosure:url];
        }
    }

    if ([elementName isEqualToString:@"link"]) {
        NSString *href = attributeDict[@"href"];
        if (href) {
            [_currentItem setLink:[NSURL URLWithString:href]];
        }
    }

    _tmpString = [[NSMutableString alloc] init];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    if ([elementName isEqualToString:@"item"] || [elementName isEqualToString:@"entry"]) {
        [_items addObject:_currentItem];
        _currentItem = nil;
    }
    if (_tmpString != nil) {
        if (_currentItem != nil) {
            if ([elementName isEqualToString:@"title"] && [_currentItem.title length] == 0) {
                [_currentItem setTitle:_tmpString];
            }

            if ([elementName isEqualToString:@"description"]) {
                [_currentItem setItemDescription:_tmpString];
            }

            if ([elementName isEqualToString:@"content:encoded"] || [elementName isEqualToString:@"content"]) {
                [_currentItem setContent:_tmpString];
            }

            if ([elementName isEqualToString:@"link"] && [_tmpString length] > 0) {
                [_currentItem setLink:[NSURL URLWithString:_tmpString]];
            }

            if ([elementName isEqualToString:@"comments"] && [_tmpString length] > 0) {
                [_currentItem setCommentsLink:[NSURL URLWithString:_tmpString]];
            }

            if ([elementName isEqualToString:@"wfw:commentRss"] && [_tmpString length] > 0) {
                [_currentItem setCommentsFeed:[NSURL URLWithString:_tmpString]];
            }

            if ([elementName isEqualToString:@"slash:comments"]) {
                [_currentItem setCommentsCount:[NSNumber numberWithInt:[_tmpString intValue]]];
            }

            if ([elementName isEqualToString:@"pubDate"] || [elementName isEqualToString:@"published"] || [elementName isEqualToString:@"dc:date"]) {
                NSDateFormatter *formatter = [[NSDateFormatter alloc] init];

                NSLocale *local = [[NSLocale alloc] initWithLocaleIdentifier:@"en_EN"];
                [formatter setLocale:local];

                [formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss Z"];
                NSDate *date = [formatter dateFromString:_tmpString];
                if (date == nil) {
                    [formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss z"];
                    date = [formatter dateFromString:_tmpString];
                }
                if (date == nil) {
                    [formatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'sszzz"];
                    date = [formatter dateFromString:_tmpString];
                }
                [_currentItem setPubDate:date];
            }

            if ([elementName isEqualToString:@"dc:creator"]) {
                [_currentItem setAuthor:_tmpString];
            }

            if ([elementName isEqualToString:@"guid"]) {
                [_currentItem setGuid:_tmpString];
            }
        } else {
            if ([elementName isEqualToString:@"title"] && [_feedTitle length] == 0) {
                _feedTitle = [_tmpString copy];
            }
            if ([elementName isEqualToString:@"icon"] && [_feedIconURL length] == 0) {
                _feedIconURL = [_tmpString copy];
            }
        }
    }

    if ([elementName isEqualToString:@"rss"] || [elementName isEqualToString:@"feed"] || [elementName isEqualToString:@"rdf:RDF"]) {
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    [_tmpString appendString:string];
}

#pragma mark -
#pragma mark Cancel

+ (void)cancelAllOperations
{
    [[self sharedClient].operationQueue cancelAllOperations];
}

- (void)cancelAllOperations
{
    [[[self class] sharedClient].operationQueue cancelAllOperations];
}

@end
