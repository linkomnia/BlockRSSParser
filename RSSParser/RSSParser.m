//
//  RSSParser.m
//  RSSParser
//
//  Created by Thibaut LE LEVIER on 1/31/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RSSParser.h"

static dispatch_queue_t rssparser_success_callback_queue() {
    static dispatch_queue_t parser_success_callback_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        parser_success_callback_queue = dispatch_queue_create("rssparser.success_callback.processing", DISPATCH_QUEUE_CONCURRENT);
    });

    return parser_success_callback_queue;
}

@implementation RSSParser

#pragma mark lifecycle
- (id)init {
    self = [super init];
    if (self) {
        items = [[NSMutableArray alloc] init];
    }
    return self;
}

#pragma mark -

#pragma mark parser

+ (void)parseRSSFeedForRequest:(NSURLRequest *)urlRequest
                       success:(void (^)(NSArray *feedItems))success
                       failure:(void (^)(NSError *error))failure
{
    RSSParser *parser = [[RSSParser alloc] init];
    [parser parseRSSFeedForRequest:urlRequest success:success failure:failure];
}


- (void)parseRSSFeedForRequest:(NSURLRequest *)urlRequest
                                          success:(void (^)(NSArray *feedItems))success
                                          failure:(void (^)(NSError *error))failure
{
    
    block = [success copy];
    
    AFXMLRequestOperation *operation = [RSSParser XMLParserRequestOperationWithRequest:urlRequest success:^(NSURLRequest *request, NSHTTPURLResponse *response, NSXMLParser *XMLParser) {
        [XMLParser setDelegate:self];
        [XMLParser parse];
        

    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, NSXMLParser *XMLParse) {
        failure(error);
    }];

    [operation setSuccessCallbackQueue:rssparser_success_callback_queue()];

    [operation start];
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
        currentItem = [[RSSItem alloc] init];
    }
    
    if ([elementName isEqualToString:@"enclosure"] && currentItem) {
        NSString *url = attributeDict[@"url"];
        NSString *type = attributeDict[@"type"];
        if (url && [type hasPrefix:@"image/"]) {
            [currentItem addImageFromEnclosure:url];
        }
    }

    if ([elementName isEqualToString:@"media:content"]) {
        NSString *url = attributeDict[@"url"];
        NSString *type = attributeDict[@"type"];
        if (url && [type hasPrefix:@"image/"]) {
            [currentItem addImageFromEnclosure:url];
        }
    }

    tmpString = [[NSMutableString alloc] init];
    
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{    
    if ([elementName isEqualToString:@"item"] || [elementName isEqualToString:@"entry"]) {
        [items addObject:currentItem];
    }
    if (currentItem != nil && tmpString != nil) {
        
        if ([elementName isEqualToString:@"title"] && [currentItem.title length] == 0) {
            [currentItem setTitle:tmpString];
        }
        
        if ([elementName isEqualToString:@"description"]) {
            [currentItem setItemDescription:tmpString];
        }
        
        if ([elementName isEqualToString:@"content:encoded"] || [elementName isEqualToString:@"content"]) {
            [currentItem setContent:tmpString];
        }
        
        if ([elementName isEqualToString:@"link"] && [tmpString length] > 0) {
            [currentItem setLink:[NSURL URLWithString:tmpString]];
        }
        
        if ([elementName isEqualToString:@"comments"] && [tmpString length] > 0) {
            [currentItem setCommentsLink:[NSURL URLWithString:tmpString]];
        }
        
        if ([elementName isEqualToString:@"wfw:commentRss"] && [tmpString length] > 0) {
            [currentItem setCommentsFeed:[NSURL URLWithString:tmpString]];
        }
        
        if ([elementName isEqualToString:@"slash:comments"]) {
            [currentItem setCommentsCount:[NSNumber numberWithInt:[tmpString intValue]]];
        }
        
        if ([elementName isEqualToString:@"pubDate"] || [elementName isEqualToString:@"published"]) {
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];

            NSLocale *local = [[NSLocale alloc] initWithLocaleIdentifier:@"en_EN"];
            [formatter setLocale:local];

            [formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss Z"];
            NSDate *date = [formatter dateFromString:tmpString];
            if (date == nil) {
                [formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss z"];
                date = [formatter dateFromString:tmpString];
            }
            if (date == nil) {
                [formatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'sszzz"];
                date = [formatter dateFromString:tmpString];
            }
            [currentItem setPubDate:date];
        }

        if ([elementName isEqualToString:@"dc:creator"]) {
            [currentItem setAuthor:tmpString];
        }
        
        if ([elementName isEqualToString:@"guid"]) {
            [currentItem setGuid:tmpString];
        }
    }
    
    if ([elementName isEqualToString:@"rss"] || [elementName isEqualToString:@"feed"]) {
        block(items);
    }
    
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    [tmpString appendString:string];
    
}

#pragma mark -

@end
