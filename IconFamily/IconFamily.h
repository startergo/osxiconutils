// IconFamily.h
// IconFamily class interface
// by Troy Stephens, Thomas Schnitzer, David Remahl, Nathan Day, Ben Haller, Sven Janssen, Peter Hosey, Conor Dearden, Elliot Glaysher, Dave MacLachlan, and Sveinbjorn Thordarson
// version 0.9.4
//
// Project Home Page:
//   http://iconfamily.sourceforge.net/
//
// Problems, shortcomings, and uncertainties that I'm aware of are flagged with "NOTE:".  Please address bug reports, bug fixes, suggestions, etc. to the project Forums and bug tracker at https://sourceforge.net/projects/iconfamily/

/*
    Copyright (c) 2001-2010 Troy N. Stephens
    Portions Copyright (c) 2007 Google Inc.

    Use and distribution of this source code is governed by the MIT License, whose terms are as follows.

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

// This class is a Cocoa/Objective-C wrapper for the Mac OS X Carbon API's
// "icon family" data type.  Its main purpose is to enable Cocoa applications
// to easily create custom file icons from NSImage instances, and thus take
// advantage of Mac OS X's new larger RGBA "thumbnail" icon format to provide
// richly detailed thumbnail previews of the files' contents.
//
// Using IconFamily, this becomes as simple as:
//
//      id iconFamily = [IconFamily iconFamilyWithThumbnailsOfImage:anImage];
//      [iconFamily setAsCustomIconForFile:anExistingFile];
//
// You can also write an icon family to an .icns file using the -writeToFile:
// method.

enum {
    kIconServices512RetinaPixelDataARGB = 'ic10', /* non-premultiplied 1024x1024 ARGB bitmap*/
    kIconServices256RetinaPixelDataARGB = 'ic14', /* non-premultiplied 512x512 ARGB bitmap*/
    kIconServices128RetinaPixelDataARGB = 'ic13', /* non-premultiplied 256x256 ARGB bitmap*/
    kIconServices32RetinaPixelDataARGB  = 'ic12', /* non-premultiplied 64x64 ARGB bitmap*/
    kIconServices16RetinaPixelDataARGB  = 'ic11', /* non-premultiplied 32x32 ARGB bitmap*/
    kIconServices18RetinaPixelDataARGB  = 'icsB', /* non-premultiplied 18x18 ARGB bitmap*/
    kIconServices36PixelDataARGB        = 'icsd', /* non-premultiplied 36x36 ARGB bitmap (non-Retina) */
    kIconServices18PixelDataARGB        = 'icsb'  /* non-premultiplied 18x18 ARGB bitmap (non-Retina) */
};

typedef struct OneIconElementType {
    int iSize;
    OSType iElementType;
    OSType iRetina;
    OSType i32BitData;
    OSType i8BitMask;
    OSType i8BitData;
    OSType i1BitMask;
} OneIconElementType;

extern OneIconElementType IconElementTypeDB[];

@interface IconFamily : NSObject <NSPasteboardReading, NSPasteboardWriting>
{
    IconFamilyHandle hIconFamily;
}

// Convenience methods.  These use the corresponding -init... methods to return
// an autoreleased IconFamily instance.

+ (IconFamily*) iconFamily;
+ (IconFamily*) iconFamilyWithContentsOfFile:(NSString*)path;
+ (IconFamily*) iconFamilyWithIconOfFile:(NSString*)path;
+ (IconFamily*) iconFamilyWithIconFamilyHandle:(IconFamilyHandle)hNewIconFamily;
+ (IconFamily*) iconFamilyWithSystemIcon:(int)fourByteCode;
+ (IconFamily*) iconFamilyWithThumbnailsOfImage:(NSImage*)image;
+ (IconFamily*) iconFamilyWithThumbnailsOfImage:(NSImage*)image usingImageInterpolation:(NSImageInterpolation)imageInterpolation;

// Initializes as a new, empty IconFamily.  This is IconFamily's designated
// initializer method.

- init;

// Initializes an IconFamily by loading the contents of an .icns file.

- initWithContentsOfFile:(NSString*)path;

// Initializes an IconFamily from an existing Carbon IconFamilyHandle.

- initWithIconFamilyHandle:(IconFamilyHandle)hNewIconFamily;

// Initializes an IconFamily by loading the Finder icon that's assigned to a
// file.

- initWithIconOfFile:(NSString*)path;

// Initializes an IconFamily by referencing a standard system icon.

- initWithSystemIcon:(int)fourByteCode;

// Initializes an IconFamily by creating its elements from a resampled
// NSImage.  The second form of this method allows you to specify the degree
// of antialiasing to be used in resampling the image, by passing in one of
// the NSImageInterpolation... constants that are defined in
// NSGraphicsContext.h.  The first form of this initializer simply calls the
// second form with imageInterpolation set to NSImageInterpolationHigh, which
// produces highly smoothed thumbnails.

- initWithThumbnailsOfImage:(NSImage*)image;
- initWithThumbnailsOfImage:(NSImage*)image usingImageInterpolation:(NSImageInterpolation)imageInterpolation;

// Writes the icon family to an .icns file.

- (BOOL) writeToFile:(NSString*)path;

// Calculate icon element type from image size

- (OSType) getImageElementType:(NSBitmapImageRep*)bitmapImageRep;
- (OSType) getImageElementType:(int)size pixels:(int)pixels;

// Sets the image data for one of the icon family's elements from an
// NSBitmapImageRep.  The "elementType" parameter must be one of the icon
// family element types listed below, and the format of the "bitmapImageRep"
// must match the corresponding requirements specified below.  Regardless of
// the elementType, the bitmapImageRep must also be non-planar and have 8 bits
// per sample.
//
//  elementType                       dimensions  format
//  -------------------               ----------  ---------------------------------------
//  kIconServices512PixelDataARGB     512 x 512   32-bit RGBA, 32-bit RGB, or 24-bit RGB
//  kIconServices256PixelDataARGB     256 x 256   32-bit RGBA, 32-bit RGB, or 24-bit RGB
//  kThumbnail32BitData               128 x 128   32-bit RGBA, 32-bit RGB, or 24-bit RGB
//  kThumbnail8BitMask                128 x 128   32-bit RGBA or 8-bit intensity
//  kLarge32BitData                   32 x  32    32-bit RGBA, 32-bit RGB, or 24-bit RGB
//  kLarge8BitMask                    32 x  32    32-bit RGBA or 8-bit intensity
//  kLarge1BitMask                    32 x  32    32-bit RGBA, 8-bit intensity, or 1-bit
//  kSmall32BitData                   16 x  16    32-bit RGBA, 32-bit RGB, or 24-bit RGB
//  kSmall8BitMask                    16 x  16    32-bit RGBA or 8-bit intensity
//  kSmall1BitMask                    16 x  16    32-bit RGBA, 8-bit intensity, or 1-bit
//
// When an RGBA image is supplied to set a "Mask" element, the mask data is
// taken from the image's alpha channel.
//
// NOTE: Setting an IconFamily's kLarge1BitMask seems to damage the IconFamily
//       for some as yet unknown reason.  (If you then assign the icon family
//       as a file's custom icon using -setAsCustomIconForFile:, the custom
//       icon doesn't appear for the file in the Finder.)  However, both
//       custom icon display and mouse-click hit-testing in the Finder seem to
//       work fine when we only set the other four elements (thus keeping the
//       existing kLarge1BitMask from the valid icon family from which we
//       initialized the IconFamily via -initWithContentsOfFile:, since
//       IconFamily's -init method is currently broken...), so it seems safe
//       to just leave the kLarge1BitMask alone.

- (BOOL) setIconFamilyElement:(OSType)elementType fromBitmapImageRep:(NSBitmapImageRep*)bitmapImageRep;
- (BOOL) setIconFamilyElement:(NSBitmapImageRep*)bitmapImageRep;

// Gets the image data for one of the icon family's elements as a new, 32-bit
// RGBA NSBitmapImageRep.  The specified elementType should be one of
// kIconServices512PixelDataARGB, kIconServices256PixelDataARGB,
// kThumbnail32BitData, kLarge32BitData, or kSmall32BitData.
//
// The returned NSBitmapImageRep will have the corresponding 8-bit mask data
// in its alpha channel, or a fully opaque alpha channel if the icon family
// has no 8-bit mask data for the specified alpha channel.
//
// Returns nil if the requested element cannot be retrieved (e.g. if the
// icon family has no such 32BitData element).

- (NSBitmapImageRep*) bitmapImageRepWithAlphaForIconFamilyElement:(OSType)elementType;

// Creates and returns an NSImage that contains the icon family's various
// elements as its NSImageReps.

- (NSImage*) imageWithAllReps;

// NOTE: Planned method -- not yet implemented.
//
// Gets the image data for one of the icon family's elements as a new
// NSBitmapImageRep.  The specified elementType should be one of
// kThumbnail32BitData, kThumbnail32BitMask, kLarge32BitData, kLarge8BitMask,
// kLarge1BitMask, kSmall32BitData, kSmall8BitMask, or kSmall1BitMask.

// - (NSBitmapImageRep*) bitmapImageRepForIconFamilyElement:(OSType)elementType;

// Writes the icon family to the resource fork of the specified file as its
// kCustomIconResource, and sets the necessary Finder bits so the icon will
// be displayed for the file in Finder views.

- (BOOL) setAsCustomIconForFile:(NSString*)path;
- (BOOL) setAsCustomIconForFile:(NSString*)path withCompatibility:(BOOL)compat;
- (BOOL) setAsCustomIconForFile:(NSString*)path withCompatibility:(BOOL)compat error:(NSError **)error;

// Same as the -setAsCustomIconForFile:... methods, but for folders (directories).

- (BOOL) setAsCustomIconForDirectory:(NSString*)path;
- (BOOL) setAsCustomIconForDirectory:(NSString*)path withCompatibility:(BOOL)compat;
- (BOOL) setAsCustomIconForDirectory:(NSString*)path withCompatibility:(BOOL)compat error:(NSError **)error;

// Removes the custom icon (if any) from the specified file's resource fork,
// and clears the necessary Finder bits for the file.  (Note that this is a
// class method, so you don't need an instance of IconFamily to invoke it.)

+ (BOOL) removeCustomIconFromFile:(NSString*)path;

//Same as the -removeCustomIconFromFile: method, but for folders (directories).

+ (BOOL) removeCustomIconFromDirectory:(NSString*)path;
+ (BOOL) removeCustomIconFromDirectory:(NSString*)path error:(NSError **)error;

- (NSData *)data;
+ (BOOL)canInitWithPasteboard:(NSPasteboard *)pasteboard;

@end
