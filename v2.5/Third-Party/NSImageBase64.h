/*!
    @header NSImageBase64.h
    @discussion	This contains an extension to the NSImage class that handles Base 64 encoding of image data.
                This functionality may be useful for web work or, more generally, for embedding bitmap data in
                XML documents.

    Created by khammond on Mon Oct 29 2001.
    Copyright (c) 2001 Kyle Hammond. All rights reserved.
*/
#import <Cocoa/Cocoa.h>

@interface NSImage (NSImageBase64)

extern NSString *kXML_Base64ReferenceAttribute;

/*!	@function	+dataWithBase64EncodedString:
    @discussion	This method returns an autoreleased NSImage object.  The NSImage object is initialized with the
                contents of the Base 64 encoded string.  This is a convenience function for
                -initWithBase64EncodedString:.
    @param	inBase64String	An NSString object that contains only Base 64 encoded data representation of an image.
    @result	The NSImage object.
*/
+ (NSImage *)imageWithBase64EncodedString:(NSString *)inBase64String;

/*!	@function	-initWithBase64EncodedString:
    @discussion	The NSImage object is initialized with the contents of the Base 64 encoded string.
                This method returns self as a convenience.
    @param	inBase64String	An NSString object that contains only Base 64 encoded image data.
    @result	This method returns self.
*/
- (id)initWithBase64EncodedString:(NSString *)inBase64String;

/*!	@function	-base64EncodingWithFileType:
    @discussion	This method returns a Base 64 encoded string representation of the NSImage object.
    @param	inFileType	The image is first converted to this file type, then encoded in Base 64.
    @result	The base 64 encoded image data string.
*/
- (NSString *)base64EncodingWithFileType:(NSBitmapImageFileType)inFileType;

@end
