//
//  RSSItem.m
//  RSSParser
//
//  Created by Thibaut LE LEVIER on 2/3/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RSSItem.h"

@interface RSSItem (Private)

-(NSArray *)imagesFromHTMLString:(NSString *)htmlstr;

@end

@implementation RSSItem {
    NSMutableArray *_enclosureImages;
}

-(NSArray *)imagesFromItemDescription
{
    if (self.itemDescription) {
        return [self imagesFromHTMLString:self.itemDescription];
    }
    
    return nil;
}

-(NSArray *)imagesFromContent
{
    if (self.content) {
        return [self imagesFromHTMLString:self.content];
    }
    
    return nil;
}

- (NSArray *)imagesFromEnclosure
{
    return _enclosureImages;
}

#pragma mark - retrieve images from html string using regexp (private methode)

-(NSArray *)imagesFromHTMLString:(NSString *)htmlstr
{
    NSMutableOrderedSet *imagesURLStringArray = [[NSMutableOrderedSet alloc] init];
    NSError *error;

    // first extract <img> tags
    NSRange range = NSMakeRange(0, htmlstr.length);

    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<img\\s[^>]*src=[\"']([^\"']*)"
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:&error];

    [regex enumerateMatchesInString:htmlstr options:0 range:range usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        [imagesURLStringArray addObject:[htmlstr substringWithRange:[result rangeAtIndex:1]]];
    }];

    // then get any URLs that look like links to images
    regex = [NSRegularExpression regularExpressionWithPattern:@"(https?)\\S*(png|jpg|jpeg|gif)"
                                                      options:NSRegularExpressionCaseInsensitive
                                                        error:&error];

    [regex enumerateMatchesInString:htmlstr options:0 range:range usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        [imagesURLStringArray addObject:[htmlstr substringWithRange:result.range]];
    }];

    return [imagesURLStringArray array];
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super init]) {
        _title = [aDecoder decodeObjectForKey:@"title"];
        _itemDescription = [aDecoder decodeObjectForKey:@"itemDescription"];
        _content = [aDecoder decodeObjectForKey:@"content"];
        _link = [aDecoder decodeObjectForKey:@"link"];
        _commentsLink = [aDecoder decodeObjectForKey:@"commentsLink"];
        _commentsFeed = [aDecoder decodeObjectForKey:@"commentsFeed"];
        _commentsCount = [aDecoder decodeObjectForKey:@"commentsCount"];
        _pubDate = [aDecoder decodeObjectForKey:@"pubDate"];
        _author = [aDecoder decodeObjectForKey:@"author"];
        _guid = [aDecoder decodeObjectForKey:@"guid"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.title forKey:@"title"];
    [aCoder encodeObject:self.itemDescription forKey:@"itemDescription"];
    [aCoder encodeObject:self.content forKey:@"content"];
    [aCoder encodeObject:self.link forKey:@"link"];
    [aCoder encodeObject:self.commentsLink forKey:@"commentsLink"];
    [aCoder encodeObject:self.commentsFeed forKey:@"commentsFeed"];
    [aCoder encodeObject:self.commentsCount forKey:@"commentsCount"];
    [aCoder encodeObject:self.pubDate forKey:@"pubDate"];
    [aCoder encodeObject:self.author forKey:@"author"];
    [aCoder encodeObject:self.guid forKey:@"guid"];
}

#pragma mark -

- (BOOL)isEqual:(RSSItem *)object
{
    if (![object isKindOfClass:[self class]]) {
        return NO;
    }
    return [self.link.absoluteString isEqualToString:object.link.absoluteString];
}

- (NSUInteger)hash
{
    return [self.link hash];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %@>", [self class], [self.title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
}

#pragma mark -

- (void)addImageFromEnclosure:(NSString *)imageURL
{
    if (!_enclosureImages) {
        _enclosureImages = [NSMutableArray arrayWithCapacity:1];
    }
    [_enclosureImages addObject:imageURL];
}

@end
