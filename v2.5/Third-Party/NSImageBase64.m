//
//  NSImageBase64.m
//  Genetic Crossing
//
//  Created by khammond on Mon Oct 29 2001.
//  Copyright (c) 2001 Kyle Hammond. All rights reserved.
//

#import "NSImageBase64.h"
#import "GSNSDataExtensions.h"

@implementation NSImage (NSImageBase64)

NSString *kXML_Base64ReferenceAttribute = @"xlink:href=\"data:;base64,";

+ (NSImage *)imageWithBase64EncodedString:(NSString *)inBase64String
{
    NSImage	*result = nil;

    result = [ [ NSImage alloc ] initWithBase64EncodedString:inBase64String ];

    return [ result autorelease ];
}

- (id)initWithBase64EncodedString:(NSString *)inBase64String
{
    if ( inBase64String )
    {
        NSSize		tempSize = { 100, 100 };
        NSData		*data = nil;
        NSImageRep	*imageRep = nil;

        self = [ self initWithSize:tempSize ];

        if ( self )
        {
            // Now, interpret the inBase64String.
            data = [ NSData dataWithBase64EncodedString:inBase64String ];

            if ( data )
                // Create an image representation from the data.
                imageRep = [ NSBitmapImageRep imageRepWithData:data ];

            if ( imageRep )
            {
                // Set the real size of the image and add the representation.
                [ self setSize:[ imageRep size ] ];

                [ self addRepresentation:imageRep ];
            }
        }

        return self;
    } else
        return nil;
}

- (NSString *)base64EncodingWithFileType:(NSBitmapImageFileType)inFileType {
    NSString			*result = nil;
    NSBitmapImageRep	*imageRep = nil;
    NSData				*pngData = nil;
    NSEnumerator		*enumerator;
    id					object;
    NSMutableDictionary	*dict;

    // Look for an existing representation in the NSBitmapImageRep class.
    enumerator = [ [ self representations ] objectEnumerator ];
    while ( imageRep == nil && ( object = [ enumerator nextObject ] ) != nil )
    {
        if ( [ object isKindOfClass:[ NSBitmapImageRep class ] ] )
            imageRep = object;
    }

    if ( imageRep == nil )
    {
        // Need to make a NSBitmapImageRep for PNG representation.
        imageRep = [ NSBitmapImageRep imageRepWithData:[ self TIFFRepresentation ] ];
        if ( imageRep )
            [ self addRepresentation:imageRep ];
    }

    if ( imageRep != nil )
    {
        // Get the image data as a PNG.
        dict = [ NSMutableDictionary dictionaryWithCapacity:1 ];
        [ dict setObject:[ NSNumber numberWithBool:NO ] forKey:NSImageInterlaced ];
        pngData = [ imageRep representationUsingType:inFileType properties:dict ];
    }

    if ( pngData != nil )
        // Now, convert the pngData into Base64 encoding.
        result = [ pngData base64EncodingWithLineLength:78 ];

    return result;
}

@end
