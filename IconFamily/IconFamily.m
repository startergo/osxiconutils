// IconFamily.m
// IconFamily class implementation
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

#import "IconFamily.h"
#import "NSString+CarbonFSRefCreation.h"
#import <Accelerate/Accelerate.h>

// Necessary on 10.5 for Preview's "New with Clipboard" menu item to see the IconFamily data.
#define ICONFAMILY_UTI @"com.apple.icns"

// Determined by using Pasteboard Manager to put com.apple.icns data on the clipboard. Alternatively, you can determine this by copying an application to the clipboard using the Finder (select an application and press cmd-C).
#define ICONFAMILY_PBOARD_TYPE @"'icns' (CorePasteboardFlavorType 0x69636E73)"

@interface IconFamily (Internals)

- (BOOL) sortElements;

- (BOOL) updateTOC;

- (BOOL) setIconFamilyDataRaw:(OSType)elementType data:(NSData*)data;

+ (NSImage*) resampleImage:(NSImage*)originalImage toIconWidth:(int)width usingImageInterpolation:(NSImageInterpolation)imageInterpolation;

- (BOOL) setIconFamilyElementPng:(NSBitmapImageRep*)bitmapImageRep elementType:(OSType)elementType requiredPixelSize:(int)requiredPixelSize;

+ (Handle) get32BitDataFromBitmapImageRep:(NSBitmapImageRep*)bitmapImageRep requiredPixelSize:(int)requiredPixelSize;

+ (Handle) get8BitDataFromBitmapImageRep:(NSBitmapImageRep*)bitmapImageRep requiredPixelSize:(int)requiredPixelSize;

+ (Handle) get8BitMaskFromBitmapImageRep:(NSBitmapImageRep*)bitmapImageRep requiredPixelSize:(int)requiredPixelSize;

+ (Handle) get1BitMaskFromBitmapImageRep:(NSBitmapImageRep*)bitmapImageRep requiredPixelSize:(int)requiredPixelSize;

- (BOOL) addResourceType:(OSType)type asResID:(int)resID;

@end

@implementation IconFamily

+ (IconFamily*) iconFamily
{
#if !__has_feature(objc_arc)
    return [[IconFamily alloc] init] autorelease];
#endif
    return [[IconFamily alloc] init];
}

+ (IconFamily*) iconFamilyWithContentsOfFile:(NSString*)path
{
#if !__has_feature(objc_arc)
    return [[[IconFamily alloc] initWithContentsOfFile:path] autorelease];
#endif
    return [[IconFamily alloc] initWithContentsOfFile:path];
}

+ (IconFamily*) iconFamilyWithIconOfFile:(NSString*)path
{
#if !__has_feature(objc_arc)
    return [[[IconFamily alloc] initWithIconOfFile:path] autorelease];
#endif
    return [[IconFamily alloc] initWithIconOfFile:path];
}

+ (IconFamily*) iconFamilyWithIconFamilyHandle:(IconFamilyHandle)hNewIconFamily
{
#if !__has_feature(objc_arc)
    return [[[IconFamily alloc] initWithIconFamilyHandle:hNewIconFamily] autorelease];
#endif
    return [[IconFamily alloc] initWithIconFamilyHandle:hNewIconFamily];
}

+ (IconFamily*) iconFamilyWithSystemIcon:(int)fourByteCode
{
#if !__has_feature(objc_arc)
    return [[[IconFamily alloc] initWithSystemIcon:fourByteCode] autorelease];
#endif
    return [[IconFamily alloc] initWithSystemIcon:fourByteCode];
}

+ (IconFamily*) iconFamilyWithThumbnailsOfImage:(NSImage*)image
{
#if !__has_feature(objc_arc)
    return [[[IconFamily alloc] initWithThumbnailsOfImage:image] autorelease];
#endif
    return [[IconFamily alloc] initWithThumbnailsOfImage:image];
}

+ (IconFamily*) iconFamilyWithThumbnailsOfImage:(NSImage*)image usingImageInterpolation:(NSImageInterpolation)imageInterpolation
{
#if !__has_feature(objc_arc)
    return [[[IconFamily alloc] initWithThumbnailsOfImage:image usingImageInterpolation:imageInterpolation] autorelease];
#endif
    return [[IconFamily alloc] initWithThumbnailsOfImage:image usingImageInterpolation:imageInterpolation];
}

// This is IconFamily's designated initializer.  It creates a new IconFamily that initially has no elements.
//
// The proper way to do this is to simply allocate a zero-sized handle (not to be confused with an empty handle) and assign it to hIconFamily.  This technique works on Mac OS X 10.2 as well as on 10.0.x and 10.1.x.  Our previous technique of allocating an IconFamily struct with a resourceSize of 0 no longer works as of Mac OS X 10.2.
- init
{
    self = [super init];
    if (self) {
        hIconFamily = (IconFamilyHandle) NewHandle( 0 );
        if (hIconFamily == NULL) {
#if !__has_feature(objc_arc)
            [self autorelease];
#endif
            return nil;
        }
    }
    return self;
}

- initWithData:(NSData*)data
{
    self = [self init];
    if (self) {
        Handle storageMem = NULL;

        OSStatus err = PtrToHand([data bytes], &storageMem, (long)[data length]);
        if( err != noErr )
        {
#if !__has_feature(objc_arc)
            [self release];
#endif
            return nil;
        }

        hIconFamily = (IconFamilyHandle)storageMem;
    }
    return self;
}

- initWithContentsOfFile:(NSString*)path
{
    FSRef ref;
    OSStatus result;

    self = [self init];
    if (self) {
        if (hIconFamily) {
            DisposeHandle( (Handle)hIconFamily );
            hIconFamily = NULL;
        }
        if (![path getFSRef:&ref createFileIfNecessary:NO]) {
#if !__has_feature(objc_arc)
            [self autorelease];
#endif
            return nil;
        }
        result = ReadIconFromFSRef( &ref, &hIconFamily );
        if (result != noErr) {
#if !__has_feature(objc_arc)
            [self autorelease];
#endif
            return nil;
        }
    }
    return self;
}

- initWithIconFamilyHandle:(IconFamilyHandle)hNewIconFamily
{
    self = [self init];
    if (self) {
        if (hIconFamily) {
            DisposeHandle( (Handle)hIconFamily );
            hIconFamily = NULL;
        }
        hIconFamily = hNewIconFamily;
    }
    return self;
}

- initWithIconOfFile:(NSString*)path
{
    IconRef iconRef;
    OSStatus    result;
    SInt16  label;
    FSRef   ref;

    self = [self init];
    if (self)
    {
        if (hIconFamily)
        {
            DisposeHandle( (Handle)hIconFamily );
            hIconFamily = NULL;
        }

        if( ![path getFSRef:&ref createFileIfNecessary:NO] )
        {
#if !__has_feature(objc_arc)
            [self autorelease];
#endif
            return nil;
        }

        result = GetIconRefFromFileInfo(
                                        &ref,
                                        /*inFileNameLength*/ 0,
                                        /*inFileName*/ NULL,
                                        kFSCatInfoNone,
                                        /*inCatalogInfo*/ NULL,
                                        kIconServicesNormalUsageFlag,
                                        &iconRef,
                                        &label );

        if (result != noErr)
        {
#if !__has_feature(objc_arc)
            [self autorelease];
#endif
            return nil;
        }

        result = IconRefToIconFamily(
                                     iconRef,
                                     kSelectorAllAvailableData,
                                     &hIconFamily );

        ReleaseIconRef( iconRef );

        if (result != noErr || !hIconFamily)
        {
#if !__has_feature(objc_arc)
            [self autorelease];
#endif
            return nil;
        }
    }
    return self;
}

- initWithSystemIcon:(int)fourByteCode
{
    IconRef iconRef;
    OSErr   result;

    self = [self init];
    if (self)
    {
        if (hIconFamily)
        {
            DisposeHandle( (Handle)hIconFamily );
            hIconFamily = NULL;
        }

        result = GetIconRef(kOnSystemDisk, kSystemIconsCreator, fourByteCode, &iconRef);

        if (result != noErr)
        {
#if !__has_feature(objc_arc)
            [self autorelease];
#endif
            return nil;
        }

        result = IconRefToIconFamily(
                                     iconRef,
                                     kSelectorAllAvailableData,
                                     &hIconFamily );

        if (result != noErr || !hIconFamily)
        {
#if !__has_feature(objc_arc)
            [self autorelease];
#endif
            return nil;
        }

        ReleaseIconRef( iconRef );
    }
    return self;
}

- initWithThumbnailsOfImage:(NSImage*)image
{
    // The default is to use a high degree of antialiasing, producing a smooth image.
    return [self initWithThumbnailsOfImage:image usingImageInterpolation:NSImageInterpolationHigh];
}

// This table relates icon types and their size
OneIconElementType IconElementTypeDB[] = {
//  { 1024, kIconServices1024PixelDataARGB , 0                                   , 0                   , 0                  , 0                 , 0                }, // 'ic10'
#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_5
    {  512, kIconServices512PixelDataARGB  , kIconServices512RetinaPixelDataARGB , 0                   , 0                  , 0                 , 0                }, // 'ic09'           'ic10'
#endif
    {  256, kIconServices256PixelDataARGB  , kIconServices256RetinaPixelDataARGB , 0                   , 0                  , 0                 , 0                }, // 'ic08'           'ic14'
    {  128, kIconServices128PixelDataARGB  , kIconServices128RetinaPixelDataARGB , kThumbnail32BitData , kThumbnail8BitMask , 0                 , 0                }, // 'ic07' (virtual) 'ic13' 'it32' 't8mk'
    {   48, kIconServices48PixelDataARGB   , 0                                   , kHuge32BitData      , kHuge8BitMask      , kHuge8BitData     , kHuge1BitMask    }, // 'ic06' (virtual)        'ih32' 'h8mk' 'ich8' 'ich#'
    {   36, kIconServices36PixelDataARGB   , 0                                   , 0                   , 0                  , 0                 , 0                }, // 'icsd'
    {   32, kIconServices32PixelDataARGB   , kIconServices32RetinaPixelDataARGB  , kLarge32BitData     , kLarge8BitMask     , kLarge8BitData    , kLarge1BitMask   }, // 'ic05' (virtual) 'ic12' 'il32' 'l8mk' 'icl8' 'ICN#'
    {   18, kIconServices18PixelDataARGB   , kIconServices18RetinaPixelDataARGB  , 0                   , 0                  , 0                 , 0                }, // 'icsb'           'icsB'
    {   16, kIconServices16PixelDataARGB   , kIconServices16RetinaPixelDataARGB  , kSmall32BitData     , kSmall8BitMask     , kSmall8BitData    , kSmall1BitMask   }, // 'ic04' (virtual) 'ic11' 'is32' 's8mk' 'ics8' 'ics#'
//  {   12, ???                            , 0                                   , 0                   , 0                  , kMini8BitData     , kMini1BitMask    }, //                                       'icm8' 'icm#' // requires changes for non-square icons and other changes
    {    0, 0                              , 0                                   , 0                   , 0                  , 0                 , 0                },
};

const OSType ThumbnailTypes[] = {
//  kIconServices512RetinaPixelDataARGB, // 'ic10' // Don't include Retina icons since we don't know how to create them properly and 1024x1024 is overkill.
    kIconServices512PixelDataARGB,       // 'ic09'
    kIconServices256PixelDataARGB,       // 'ic08'
    kIconServices128PixelDataARGB,       //        'it32' 't8mk'
    kIconServices48PixelDataARGB,        //        'ih32' 'h8mk'
    kIconServices32PixelDataARGB,        //        'il32' 'l8mk'
    kIconServices16PixelDataARGB,        //        'is32' 's8mk'
    0
};

- initWithThumbnailsOfImage:(NSImage*)image usingImageInterpolation:(NSImageInterpolation)imageInterpolation
{
    NSImage* iconImage;
    NSBitmapImageRep* iconBitmap;
    NSImage* bitmappedIconImage;
    int elementSize;

    // Start with a new, empty IconFamily.
    self = [self init];
    if (self == nil)
        return nil;

    // Resample the given image for each icon size to create a 32-bit RGBA
    // version, and use that as our "thumbnail" icon and mask.
    //
    // Our +resampleImage:toIconWidth:... method, in its present form,
    // returns an NSImage that contains an NSCacheImageRep, rather than
    // an NSBitmapImageRep.  We convert to an NSBitmapImageRep, so that
    // our methods can scan the image data, using initWithFocusedViewRect:.

    for (const OSType *oneThumbnailType = ThumbnailTypes; *oneThumbnailType != 0; oneThumbnailType++) {
        for (OneIconElementType *iconElementType = IconElementTypeDB; iconElementType->iSize; iconElementType++) {
            elementSize = 0;
            if (iconElementType->iElementType == *oneThumbnailType) {
                elementSize = iconElementType->iSize;
            }
        	else if (iconElementType->iRetina == *oneThumbnailType) {
                elementSize = iconElementType->iSize * 2; // TO DO: Fix this.
            }
            if (!elementSize) {
                continue;
            }

            iconImage = [IconFamily resampleImage:image toIconWidth:elementSize usingImageInterpolation:imageInterpolation];

            if (iconImage) {
                [iconImage lockFocus];
                iconBitmap = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0, 0, iconElementType->iSize, iconElementType->iSize)];
                #if !__has_feature(objc_arc)
                    [iconBitmap autorelease];
                #endif
                [iconImage unlockFocus];
                if (iconBitmap) {
                    bitmappedIconImage = [[NSImage alloc] initWithSize:NSMakeSize(iconElementType->iSize, iconElementType->iSize)];
                    [bitmappedIconImage addRepresentation:iconBitmap];
                    [self setIconFamilyElement:*oneThumbnailType fromBitmapImageRep:iconBitmap];
                }
            }
        }
    }

    // Return the new icon family!
    return self;
}

- (void) dealloc
{
    DisposeHandle( (Handle)hIconFamily );
}

- (NSBitmapImageRep*) bitmapImageRepWithAlphaForIconFamilyElement:(OSType)elementType
{
    NSBitmapImageRep* bitmapImageRep;
    NSInteger pixelsWide = 0;
    Handle hRawBitmapData;
    Handle hRawMaskData = NULL;
    OSType maskElementType = 0;
    NSBitmapFormat bitmapFormat = NSAlphaFirstBitmapFormat;
    OSErr result;
    UInt32* pRawBitmapData;
    UInt32* pRawBitmapDataEnd;
    unsigned char* pRawMaskData;
    unsigned char* pBitmapImageRepBitmapData;

    // Make sure elementType is a valid type that we know how to handle, and
    // figure out the dimensions and bit depth of the bitmap for that type.
    if (elementType) {
        for (OneIconElementType *iconElementType = IconElementTypeDB; iconElementType->iSize; iconElementType++) {
            if  (elementType == iconElementType->iRetina) {
                pixelsWide = iconElementType->iSize * 2; break;
            } else if (elementType == iconElementType->iElementType) {
                pixelsWide = iconElementType->iSize; break;
            } else if (elementType == iconElementType->i32BitData) {
                pixelsWide = iconElementType->iSize;
                maskElementType = iconElementType->i8BitMask;
                break;
            }
        }
    }

    if (!pixelsWide) {
        return nil;
    }

    // Get the raw, uncompressed bitmap data for the requested element.
    hRawBitmapData = NewHandle( pixelsWide * pixelsWide * 4 );
    result = GetIconFamilyData( hIconFamily, elementType, hRawBitmapData );
    if (result != noErr) {
        DisposeHandle( hRawBitmapData );
        return nil;
    }

    if (maskElementType) {
        // Get the corresponding raw, uncompressed 8-bit mask data.
        hRawMaskData = NewHandle( pixelsWide * pixelsWide );
        result = GetIconFamilyData( hIconFamily, maskElementType, hRawMaskData );
        if (result != noErr) {
            DisposeHandle( hRawMaskData );
            hRawMaskData = NULL;
        }
    }

    // The retrieved raw bitmap data is stored in memory as 32 bit per pixel, 8 bit per sample xRGB data. (The sample order provided by IconServices is the same, regardless of whether we're running on a big-endian (PPC) or little-endian (Intel) architecture.)

    pRawBitmapData = (UInt32*) *hRawBitmapData;
    pRawBitmapDataEnd = pRawBitmapData + pixelsWide * pixelsWide;
    if (hRawMaskData) {

        pRawMaskData = (UInt8*) *hRawMaskData;
        while (pRawBitmapData < pRawBitmapDataEnd) {

            *pRawBitmapData = CFSwapInt32BigToHost((*pRawMaskData++ << 24) | CFSwapInt32HostToBig(*pRawBitmapData));
            ++pRawBitmapData;

        }

    } else {
        if(maskElementType) {
            // We SHOULD have a mask, but apparently not. Fake it with alpha=1.
            while (pRawBitmapData < pRawBitmapDataEnd) {
                *(unsigned char *)pRawBitmapData = 0xff;
                ++pRawBitmapData;
            }
        }
    }

    // Create a new NSBitmapImageRep with the given bitmap data. Note that
    // when creating the NSBitmapImageRep we pass in NULL for the "planes"
    // parameter. This causes the new NSBitmapImageRep to allocate its own
    // buffer for the bitmap data (which it will own and release when the
    // NSBitmapImageRep is released), rather than referencing the bitmap
    // data we pass in (which will soon disappear when we call
    // DisposeHandle() below!).  (See the NSBitmapImageRep documentation for
    // the -initWithBitmapDataPlanes:... method, where this is explained.)
    //
    // Once we have the new NSBitmapImageRep, we get a pointer to its
    // bitmapData and copy our bitmap data in.
    bitmapImageRep = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL
                      pixelsWide:pixelsWide
                      pixelsHigh:pixelsWide
                   bitsPerSample:8
                 samplesPerPixel:4
                        hasAlpha:YES
                        isPlanar:NO
                  colorSpaceName:NSDeviceRGBColorSpace // NOTE: is this right?
                    bitmapFormat:bitmapFormat
                     bytesPerRow:0
                    bitsPerPixel:0];

#if !__has_feature(objc_arc)
    [bitmapImageRep autorelease];
#endif

    pBitmapImageRepBitmapData = [bitmapImageRep bitmapData];
    if (pBitmapImageRepBitmapData) {
        memcpy( pBitmapImageRepBitmapData, *hRawBitmapData,
                pixelsWide * pixelsWide * 4 );
    }
//  HUnlock( hRawBitmapData ); // Handle-based memory isn't compacted anymore, so calling HLock()/HUnlock() is unnecessary.

    // Free the retrieved raw data.
    DisposeHandle( hRawBitmapData );
    if (hRawMaskData)
        DisposeHandle( hRawMaskData );

    // Return nil if the NSBitmapImageRep didn't give us a buffer to copy into.
    if (pBitmapImageRepBitmapData == NULL)
        return nil;

    // Return the new NSBitmapImageRep.
    return bitmapImageRep;
}

- (NSImage*) imageWithAllReps
{
    NSImage* image = NULL;
    image = [[NSImage alloc] initWithData:[NSData dataWithBytes:*hIconFamily length:GetHandleSize((Handle)hIconFamily)]];
#if !__has_feature(objc_arc)
    [image autorelease];
#endif
    return image;
}

- (BOOL) setIconFamilyElement:(OSType)elementType fromBitmapImageRep:(NSBitmapImageRep*)bitmapImageRep
{
    if (!bitmapImageRep)
        return NO;

    Handle hRawData = NULL;
    OSErr result;

    if (elementType) {
        for (OneIconElementType *iconElementType = IconElementTypeDB; iconElementType->iSize; iconElementType++) {
            if  (elementType == iconElementType->iRetina) {
                return [self setIconFamilyElementPng:bitmapImageRep elementType:elementType requiredPixelSize:iconElementType->iSize * 2];
            } else if (elementType == iconElementType->iElementType || elementType == iconElementType->i32BitData) {
                hRawData = [IconFamily get32BitDataFromBitmapImageRep:bitmapImageRep requiredPixelSize:iconElementType->iSize]; break;
            } else if (elementType == iconElementType->i8BitMask) {
                hRawData = [IconFamily get8BitMaskFromBitmapImageRep:bitmapImageRep requiredPixelSize:iconElementType->iSize]; break;
            } else if (elementType == iconElementType->i8BitData) {
                hRawData = [IconFamily get8BitDataFromBitmapImageRep:bitmapImageRep requiredPixelSize:iconElementType->iSize]; break;
            } else if (elementType == iconElementType->i1BitMask) {
                hRawData = [IconFamily get1BitMaskFromBitmapImageRep:bitmapImageRep requiredPixelSize:iconElementType->iSize]; break;
            }
        }
    }

    //NSLog(@"setIconFamilyElement:%@ fromBitmapImageRep:%@ generated handle %p of size %d", NSFileTypeForHFSTypeCode(elementType), bitmapImageRep, hRawData, GetHandleSize(hRawData));

    if (hRawData == NULL)
    {
        NSLog(@"Null data returned to setIconFamilyElement:fromBitmapImageRep:");
        return NO;
    }

    result = SetIconFamilyData( hIconFamily, elementType, hRawData );
    DisposeHandle( hRawData );

    if (result != noErr)
    {
        NSLog(@"SetIconFamilyData() returned error %d", result);
        return NO;
    }

    return YES;
}

- (BOOL) setIconFamilyElement:(NSBitmapImageRep*)bitmapImageRep
{
    if (!bitmapImageRep)
        return NO;

    OSType elementType = [self getImageElementType:bitmapImageRep];

    if (elementType) {
        return [self setIconFamilyElement:elementType fromBitmapImageRep:bitmapImageRep];
    }

    return NO;
}

- (OSType) getImageElementType:(NSBitmapImageRep*)bitmapImageRep
{
    if (!bitmapImageRep)
        return 0;
    return [self getImageElementType:[bitmapImageRep size].width pixels:[bitmapImageRep pixelsWide]];
}

- (OSType) getImageElementType:(int)size pixels:(int)pixels
{
    for (OneIconElementType *iconElementType = IconElementTypeDB; iconElementType->iSize; iconElementType++) {
        if (size == iconElementType->iSize && pixels == iconElementType->iSize)
            return iconElementType->iElementType;
        if (size == iconElementType->iSize && pixels == iconElementType->iSize * 2)
            return iconElementType->iRetina;
    }
    return 0;
}

- (BOOL) setAsCustomIconForFile:(NSString*)path
{
    return( [self setAsCustomIconForFile:path withCompatibility:NO error:NULL] );
}

- (BOOL) setAsCustomIconForFile:(NSString*)path withCompatibility:(BOOL)compat
{
    return( [self setAsCustomIconForFile:path withCompatibility:NO error:NULL] );
}

- (BOOL) setAsCustomIconForFile:(NSString*)path withCompatibility:(BOOL)compat error:(NSError **)error
{
    FSRef targetFileFSRef;
    FSRef parentDirectoryFSRef;
    SInt16 file;
    OSStatus result;
    struct FSCatalogInfo catInfo;
    struct FileInfo *finderInfo = (struct FileInfo *)&catInfo.finderInfo;
    Handle hExistingCustomIcon;
    Handle hIconFamilyCopy;
    NSString *parentDirectory;

    // Before we do anything, get the original modification time for the target file.
    NSDate* modificationDate = [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:error] objectForKey:NSFileModificationDate];

    if ([path isAbsolutePath])
        parentDirectory = [path stringByDeletingLastPathComponent];
    else
        parentDirectory = [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:[path stringByDeletingLastPathComponent]];

    // Get an FSRef for the target file's parent directory that we can use in
    // the FSCreateResFile() and FNNotify() calls below.
    if (![parentDirectory getFSRef:&parentDirectoryFSRef createFileIfNecessary:NO])
        return NO;

    // Get the name of the file, for FSCreateResFile.
    struct HFSUniStr255 filename;
    NSString *filenameString = [path lastPathComponent];
    filename.length = [filenameString length];
    [filenameString getCharacters:filename.unicode];

    // Make sure the file has a resource fork that we can open.  (Although
    // this sounds like it would clobber an existing resource fork, the Carbon
    // Resource Manager docs for this function say that's not the case.  If
    // the file already has a resource fork, we receive a result code of
    // dupFNErr, which is not really an error per se, but just a notification
    // to us that creating a new resource fork for the file was not necessary.)
    FSCreateResFile(
                    &parentDirectoryFSRef,
                    filename.length,
                    filename.unicode,
                    kFSCatInfoNone,
                    /*catalogInfo/*/ NULL,
                    &targetFileFSRef,
                    /*newSpec*/ NULL);
    result = ResError();
    if (result == dupFNErr) {
        // If the call to FSCreateResFile() returned dupFNErr, targetFileFSRef will not have been set, so create it from the path.
        if (![path getFSRef:&targetFileFSRef createFileIfNecessary:NO])
            return NO;
    } else if (result != noErr) {
        return NO;
    }

    // Open the file's resource fork.
    file = FSOpenResFile( &targetFileFSRef, fsRdWrPerm );
    if (file == -1)
        return NO;

    // Make a copy of the icon family data to pass to AddResource().
    // (AddResource() takes ownership of the handle we pass in; after the
    // CloseResFile() call its master pointer will be set to 0xffffffff.
    // We want to keep the icon family data, so we make a copy.)
    // HandToHand() returns the handle of the copy in hIconFamily.
    hIconFamilyCopy = (Handle) hIconFamily;
    result = HandToHand( &hIconFamilyCopy );
    if (result != noErr) {
        CloseResFile( file );
        return NO;
    }

    // Remove the file's existing kCustomIconResource of type kIconFamilyType
    // (if any).
    hExistingCustomIcon = GetResource( kIconFamilyType, kCustomIconResource );
    if( hExistingCustomIcon )
        RemoveResource( hExistingCustomIcon );

    // Now add our icon family as the file's new custom icon.
    AddResource( (Handle)hIconFamilyCopy, kIconFamilyType,
                 kCustomIconResource, "\p");
    if (ResError() != noErr) {
        CloseResFile( file );
        return NO;
    }

    if( compat )
    {
        [self addResourceType:kLarge8BitData asResID:kCustomIconResource];
        [self addResourceType:kLarge1BitMask asResID:kCustomIconResource];
        [self addResourceType:kSmall8BitData asResID:kCustomIconResource];
        [self addResourceType:kSmall1BitMask asResID:kCustomIconResource];
    }

    // Close the file's resource fork, flushing the resource map and new icon
    // data out to disk.
    CloseResFile( file );
    if (ResError() != noErr)
        return NO;

    // Prepare to get the Finder info.

    // Now we need to set the file's Finder info so the Finder will know that
    // it has a custom icon. Start by getting the file's current finder info:
    result = FSGetCatalogInfo(
                              &targetFileFSRef,
                              kFSCatInfoFinderInfo,
                              &catInfo,
                              /*outName*/ NULL,
                              /*fsSpec*/ NULL,
                              /*parentRef*/ NULL);
    if (result != noErr)
        return NO;

    // Set the kHasCustomIcon flag, and clear the kHasBeenInited flag.
    //
    // From Apple's "CustomIcon" code sample:
    //     "set bit 10 (has custom icon) and unset the inited flag
    //      kHasBeenInited is 0x0100 so the mask will be 0xFEFF:"
    //    finderInfo.fdFlags = 0xFEFF & (finderInfo.fdFlags | kHasCustomIcon ) ;
    finderInfo->finderFlags = (finderInfo->finderFlags | kHasCustomIcon ) & ~kHasBeenInited;

    // Now write the Finder info back.
    result = FSSetCatalogInfo( &targetFileFSRef, kFSCatInfoFinderInfo, &catInfo );
    if (result != noErr)
        return NO;

    // Now set the modification time back to when the file was actually last modified.
    NSDictionary* attributes = [NSDictionary dictionaryWithObjectsAndKeys:modificationDate, NSFileModificationDate, nil];
    [[NSFileManager defaultManager] setAttributes:attributes ofItemAtPath:path error:nil];

    // Notify the system that the directory containing the file has changed, to
    // give Finder the chance to find out about the file's new custom icon.
    result = FNNotify( &parentDirectoryFSRef, kFNDirectoryModifiedMessage, kNilOptions );
    if (result != noErr)
        return NO;

    return YES;
}

+ (BOOL) removeCustomIconFromFile:(NSString*)path
{
    FSRef targetFileFSRef;
    FSRef parentDirectoryFSRef;
    SInt16 file;
    OSStatus result;
    struct FSCatalogInfo catInfo;
    struct FileInfo *finderInfo = (struct FileInfo *)&catInfo.finderInfo;
    Handle hExistingCustomIcon;

    // Get an FSRef for the target file.
    if (![path getFSRef:&targetFileFSRef createFileIfNecessary:NO])
        return NO;

    // Open the file's resource fork, if it has one.
    file = FSOpenResFile( &targetFileFSRef, fsRdWrPerm );
    if (file == -1)
        return NO;

    // Remove the file's existing kCustomIconResource of type kIconFamilyType
    // (if any).
    hExistingCustomIcon = GetResource( kIconFamilyType, kCustomIconResource );
    if( hExistingCustomIcon )
        RemoveResource( hExistingCustomIcon );

    // Close the file's resource fork, flushing the resource map out to disk.
    CloseResFile( file );
    if (ResError() != noErr)
        return NO;

    // Now we need to set the file's Finder info so the Finder will know that
    // it has no custom icon. Start by getting the file's current Finder info.
    // Also get an FSRef for its parent directory, that we can use in the
    // FNNotify() call below.
    result = FSGetCatalogInfo(
                              &targetFileFSRef,
                              kFSCatInfoFinderInfo,
                              &catInfo,
                              /*outName*/ NULL,
                              /*fsSpec*/ NULL,
                              &parentDirectoryFSRef );
    if (result != noErr)
        return NO;

    // Clear the kHasCustomIcon flag and the kHasBeenInited flag.
    finderInfo->finderFlags = finderInfo->finderFlags & ~(kHasCustomIcon | kHasBeenInited);

    // Now write the Finder info back.
    result = FSSetCatalogInfo( &targetFileFSRef, kFSCatInfoFinderInfo, &catInfo );
    if (result != noErr)
        return NO;

    // Notify the system that the directory containing the file has changed, to give Finder the chance to find out about the file's new custom icon.
    result = FNNotify( &parentDirectoryFSRef, kFNDirectoryModifiedMessage, kNilOptions );
    if (result != noErr)
        return NO;

    return YES;
}

- (BOOL) setAsCustomIconForDirectory:(NSString*)path
{
    return [self setAsCustomIconForDirectory:path withCompatibility:NO error:NULL];
}

- (BOOL) setAsCustomIconForDirectory:(NSString*)path withCompatibility:(BOOL)compat
{
    return [self setAsCustomIconForDirectory:path withCompatibility:NO error:NULL];
}

- (BOOL) setAsCustomIconForDirectory:(NSString*)path withCompatibility:(BOOL)compat error:(NSError **)error
{
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir;
    BOOL exists;
    NSString *iconrPath;
    FSRef targetFolderFSRef, iconrFSRef;
    SInt16 file;
    OSErr result;
    struct HFSUniStr255 filename;
    struct FSCatalogInfo catInfo;
    Handle hExistingCustomIcon;
    Handle hIconFamilyCopy;

    // Confirm that "path" exists and specifies a directory.
    exists = [fm fileExistsAtPath:path isDirectory:&isDir];
    if( !isDir || !exists )
        return NO;

    // Get an FSRef for the folder.
    if( ![path getFSRef:&targetFolderFSRef createFileIfNecessary:NO] )
        return NO;

    // Remove and re-create any existing "Icon\r" file in the directory, and get an FSRef for it.
    iconrPath = [path stringByAppendingPathComponent:@"Icon\r"];
    if( [fm fileExistsAtPath:iconrPath] )
    {
        if( ![fm removeItemAtPath:iconrPath error:error] )
            return NO;
    }
    if( ![iconrPath getFSRef:&iconrFSRef createFileIfNecessary:YES] )
        return NO;

    // Get type and creator information for the Icon file.
    result = FSGetCatalogInfo(
                              &iconrFSRef,
                              kFSCatInfoFinderInfo,
                              &catInfo,
                              /*outName*/ NULL,
                              /*fsSpec*/ NULL,
                              /*parentRef*/ NULL );
    // This shouldn't fail because we just created the file above.
    if( result != noErr )
        return NO;
    else {
        // The file doesn't exist. Prepare to create it.
        struct FileInfo *finderInfo = (struct FileInfo *)catInfo.finderInfo;

        // These are the file type and creator given to Icon files created by
        // the Finder.
        finderInfo->fileType = 'icon';
        finderInfo->fileCreator = 'MACS';

        // Icon files should be invisible.
        finderInfo->finderFlags = kIsInvisible;

        // Because the inited flag is not set in finderFlags above, the Finder
        // will ignore the location, unless it's in the 'magic rectangle' of
        // { -24,000, -24,000, -16,000, -16,000 } (technote TB42).
        // So we need to make sure to set this to zero anyway, so that the
        // Finder will position it automatically. If the user makes the Icon
        // file visible for any reason, we don't want it to be positioned in an
        // exotic corner of the window.
        finderInfo->location.h = finderInfo->location.v = 0;

        // Standard reserved-field practice.
        finderInfo->reservedField = 0;

        // Update the catalog info:
        result = FSSetCatalogInfo(&iconrFSRef, kFSCatInfoFinderInfo, &catInfo);

        if (result != noErr)
            return NO;
    }

    // Get the filename, to be applied to the Icon file.
    filename.length = [@"Icon\r" length];
    [@"Icon\r" getCharacters:filename.unicode];

    // Make sure the file has a resource fork that we can open.  (Although
    // this sounds like it would clobber an existing resource fork, the Carbon
    // Resource Manager docs for this function say that's not the case.)
    FSCreateResFile(
                    &targetFolderFSRef,
                    filename.length,
                    filename.unicode,
                    kFSCatInfoFinderInfo,
                    &catInfo,
                    &iconrFSRef,
                    /*newSpec*/ NULL);
    result = ResError();
    if (!(result == noErr || result == dupFNErr))
        return NO;

    // Open the file's resource fork.
    file = FSOpenResFile( &iconrFSRef, fsRdWrPerm );
    if (file == -1)
        return NO;

    // Make a copy of the icon family data to pass to AddResource().
    // (AddResource() takes ownership of the handle we pass in; after the
    // CloseResFile() call its master pointer will be set to 0xffffffff.
    // We want to keep the icon family data, so we make a copy.)
    // HandToHand() returns the handle of the copy in hIconFamily.
    hIconFamilyCopy = (Handle) hIconFamily;
    result = HandToHand( &hIconFamilyCopy );
    if (result != noErr) {
        CloseResFile( file );
        return NO;
    }

    // Remove the file's existing kCustomIconResource of type kIconFamilyType
    // (if any).
    hExistingCustomIcon = GetResource( kIconFamilyType, kCustomIconResource );
    if( hExistingCustomIcon )
        RemoveResource( hExistingCustomIcon );

    // Now add our icon family as the file's new custom icon.
    AddResource( (Handle)hIconFamilyCopy, kIconFamilyType,
                 kCustomIconResource, "\p");

    if (ResError() != noErr) {
        CloseResFile( file );
        return NO;
    }

    if( compat )
    {
        [self addResourceType:kLarge8BitData asResID:kCustomIconResource];
        [self addResourceType:kLarge1BitMask asResID:kCustomIconResource];
        [self addResourceType:kSmall8BitData asResID:kCustomIconResource];
        [self addResourceType:kSmall1BitMask asResID:kCustomIconResource];
    }

    // Close the file's resource fork, flushing the resource map and new icon
    // data out to disk.
    CloseResFile( file );
    if (ResError() != noErr)
        return NO;

    result = FSGetCatalogInfo( &targetFolderFSRef,
                               kFSCatInfoFinderInfo,
                               &catInfo,
                               /*outName*/ NULL,
                               /*fsSpec*/ NULL,
                               /*parentRef*/ NULL);
    if( result != noErr )
        return NO;

    // Tell the Finder that the folder now has a custom icon.
    ((struct FolderInfo *)catInfo.finderInfo)->finderFlags = ( ((struct FolderInfo *)catInfo.finderInfo)->finderFlags | kHasCustomIcon ) & ~kHasBeenInited;

    result = FSSetCatalogInfo( &targetFolderFSRef,
                      kFSCatInfoFinderInfo,
                      &catInfo);
    if( result != noErr )
        return NO;

    // Notify the system that the target directory has changed, to give Finder
    // the chance to find out about its new custom icon.
    result = FNNotify( &targetFolderFSRef, kFNDirectoryModifiedMessage, kNilOptions );
    if (result != noErr)
        return NO;

    return YES;
}

+ (BOOL) removeCustomIconFromDirectory:(NSString*)path
{
    return( [self removeCustomIconFromDirectory:path error:NULL] );
}

+ (BOOL) removeCustomIconFromDirectory:(NSString*)path error:(NSError **)error
{
    FSRef targetFolderFSRef;
    if( [path getFSRef:&targetFolderFSRef createFileIfNecessary:NO] ) {
        OSStatus result;
        struct FSCatalogInfo catInfo;
        struct FileInfo *finderInfo = (struct FileInfo *)catInfo.finderInfo;

        result = FSGetCatalogInfo( &targetFolderFSRef,
                                  kFSCatInfoFinderInfo,
                                  &catInfo,
                                  /*outName*/ NULL,
                                  /*fsSpec*/ NULL,
                                  /*parentRef*/ NULL);
        if( result != noErr )
            return NO;

        // Tell the Finder that the folder no longer has a custom icon.
        finderInfo->finderFlags &= ~( kHasCustomIcon | kHasBeenInited );

        result = FSSetCatalogInfo( &targetFolderFSRef,
                          kFSCatInfoFinderInfo,
                          &catInfo);
        if( result != noErr )
            return NO;

        // Notify the system that the target directory has changed, to give Finder
        // the chance to find out about its new custom icon.
        result = FNNotify( &targetFolderFSRef, kFNDirectoryModifiedMessage, kNilOptions );
        if (result != noErr)
            return NO;
    }

    if( ! [[NSFileManager defaultManager] removeItemAtPath:[path stringByAppendingPathComponent:@"Icon\r"] error:error] )
        return NO;

    return YES;
}

- (NSData *) data
{
    return [NSData dataWithBytes:*hIconFamily length:GetHandleSize((Handle)hIconFamily)];
}

- (BOOL) writeToFile:(NSString*)path
{
    [self sortElements]; // sort the elements so the items in the TOC are in the correct order
    [self updateTOC];
    [self sortElements]; // sort the elements so the TOC first in the icns file
    return [[self data] writeToFile:path atomically:NO];
}


#pragma mark - NSPasteboardReading

- (id)initWithPasteboardPropertyList:(id)data ofType:(NSString *)type {
    return [self initWithData:data];
}

+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard {
    return [NSArray arrayWithObjects:ICONFAMILY_UTI, ICONFAMILY_PBOARD_TYPE, nil];
}

+ (NSPasteboardReadingOptions)readingOptionsForType:(NSString *)type pasteboard:(NSPasteboard *)pasteboard {
    return NSPasteboardReadingAsData;
}

+ (BOOL)canInitWithPasteboard:(NSPasteboard *)pasteboard {
    return [pasteboard canReadItemWithDataConformingToTypes:[self.class readableTypesForPasteboard:pasteboard]];
}

#pragma mark - NSPasteboardWriting

- (NSArray *)writableTypesForPasteboard:(NSPasteboard *)pasteboard {
    return [self.class readableTypesForPasteboard:pasteboard];
}

- (id)pasteboardPropertyListForType:(NSString *)type {
    return self.data;
}

@end

#pragma mark - Internals
@implementation IconFamily (Internals)

+ (NSImage*) resampleImage:(NSImage*)originalImage toIconWidth:(int)iconWidth usingImageInterpolation:(NSImageInterpolation)imageInterpolation
{
    NSGraphicsContext* graphicsContext;
    BOOL wasAntialiasing;
    NSImageInterpolation previousImageInterpolation;
    NSImage* newImage;
    NSImage* workingImage;
    NSImageRep* workingImageRep;
    NSSize size, pixelSize, newSize;
    NSRect iconRect;
    NSRect targetRect;

    iconWidth = iconWidth / [[NSScreen mainScreen] backingScaleFactor];

    // Create a working copy of the image and scale its size down to fit in
    // the square area of the icon.
    //
    // It seems like there should be a more memory-efficient alternative to
    // first duplicating the entire original image, but I don't know what it
    // is.  We need to change some properties ("size" and "scalesWhenResized")
    // of the original image, but we shouldn't change the original, so a copy
    // is necessary.
    workingImage = [originalImage copy];
//    [workingImage setScalesWhenResized:YES];
    size = [workingImage size];
    workingImageRep = [workingImage bestRepresentationForRect:NSZeroRect context:nil hints:nil];
    if ([workingImageRep isKindOfClass:[NSBitmapImageRep class]]) {
        pixelSize.width  = [workingImageRep pixelsWide];
        pixelSize.height = [workingImageRep pixelsHigh];
        if (!NSEqualSizes( size, pixelSize )) {
            [workingImage setSize:pixelSize];
            [workingImageRep setSize:pixelSize];
            size = pixelSize;
        }
    }
    if (size.width >= size.height) {
        newSize.width = iconWidth;
        newSize.height = (float)floor( iconWidth * size.height / size.width + 0.5 );
    } else {
        newSize.height = iconWidth;
        newSize.width = (float)floor( iconWidth * size.width / size.height + 0.5 );
    }
    [workingImage setSize:newSize];

    // Create a new image the size of the icon, and clear it to transparent.
    newImage = [[NSImage alloc] initWithSize:NSMakeSize(iconWidth,iconWidth)];
    [newImage lockFocus];
    iconRect.origin.x = iconRect.origin.y = 0;
    iconRect.size.width = iconRect.size.height = iconWidth;
    [[NSColor clearColor] set];
    NSRectFill( iconRect );

    // Set current graphics context to use antialiasing and high-quality
    // image scaling.
    graphicsContext = [NSGraphicsContext currentContext];
    wasAntialiasing = [graphicsContext shouldAntialias];
    previousImageInterpolation = [graphicsContext imageInterpolation];
    [graphicsContext setShouldAntialias:YES];
    [graphicsContext setImageInterpolation:imageInterpolation];

    // Composite the working image into the icon bitmap, centered.
    targetRect.origin.x = ((float)iconWidth - newSize.width ) / 2.0f;
    targetRect.origin.y = ((float)iconWidth - newSize.height) / 2.0f;
    targetRect.size.width = newSize.width;
    targetRect.size.height = newSize.height;
    [workingImageRep drawInRect:targetRect];

    // Restore previous graphics context settings.
    [graphicsContext setShouldAntialias:wasAntialiasing];
    [graphicsContext setImageInterpolation:previousImageInterpolation];

    [newImage unlockFocus];

#if !__has_feature(objc_arc)
    [workingImage release];
    [newImage autorelease];
#endif
    // Return the new image!
    return newImage;
}

- (NSData *) getIconFamilyDataRaw:(OSType)elementType
{
    long oldHandleSize = GetHandleSize((Handle)hIconFamily);
    long oldSize = oldHandleSize < 8 ? 8 : CFSwapInt32BigToHost((*hIconFamily)->resourceSize);
    IconFamilyElement *endElement = (IconFamilyElement *)((void*)(*hIconFamily) + oldSize);
    long elementSize;
    IconFamilyElement *srcElement;
    for (srcElement = (*hIconFamily)->elements; srcElement < endElement; srcElement = (IconFamilyElement *)((void*)srcElement + elementSize)) {
        elementSize = CFSwapInt32BigToHost(srcElement->elementSize);
        if (CFSwapInt32BigToHost(srcElement->elementType) == elementType) {
            return [NSData dataWithBytes:srcElement->elementData length:elementSize-8];
        } // if elementType
    } // for srcElement
    return nil;
}

- (BOOL) setIconFamilyDataRaw:(OSType)elementType data:(NSData*)data
{
    long oldHandleSize = GetHandleSize((Handle)hIconFamily);
    long oldSize = oldHandleSize < 8 ? 8 : CFSwapInt32BigToHost((*hIconFamily)->resourceSize);
    IconFamilyElement *endElement = (IconFamilyElement *)((void*)(*hIconFamily) + oldSize);
    long elementSize = 0;
    IconFamilyElement *srcElement;
    for (srcElement = (*hIconFamily)->elements; srcElement < endElement; srcElement = (IconFamilyElement *)((void*)srcElement + elementSize)) {
        elementSize = CFSwapInt32BigToHost(srcElement->elementSize);
        if (CFSwapInt32BigToHost(srcElement->elementType) == elementType) {
            break;
        } // if elementType
    } // for srcElement

    if (srcElement >= endElement) {
        elementSize = 0;
    }

    long newElementSize = 8 + [data length];
    long newSize = oldSize + newElementSize - elementSize;
    long offset = (void*)srcElement - (void*)(*hIconFamily);

    if (newSize > oldHandleSize) {
        SetHandleSize((Handle)hIconFamily, newSize);
    }

    // recalculate pointer because SetHandleSize might change it
    srcElement = (IconFamilyElement *)((void*)(*hIconFamily) + offset);
    memcpy((void*)srcElement + newElementSize, (void*)srcElement + elementSize, oldSize - (offset + elementSize));

    srcElement->elementType = CFSwapInt32HostToBig(elementType);
    srcElement->elementSize = CFSwapInt32HostToBig((UInt32)newElementSize);
    [data getBytes:srcElement->elementData];

    if (newSize < oldHandleSize) {
        SetHandleSize((Handle)hIconFamily, newSize);
    } if (oldHandleSize < 8) {
        (*hIconFamily)->resourceType = CFSwapInt32HostToBig('icns');
    }
    (*hIconFamily)->resourceSize = CFSwapInt32HostToBig((UInt32)newSize);

    return YES;
}

- (IconFamilyElement*) moveElementDataRaw:(OSType)elementType dstElement:(IconFamilyElement *)dstElement
{
    long oldHandleSize = GetHandleSize((Handle)hIconFamily);
    long oldSize = oldHandleSize < 8 ? 8 : CFSwapInt32BigToHost((*hIconFamily)->resourceSize);
    IconFamilyElement *endElement = (IconFamilyElement *)((void*)(*hIconFamily) + oldSize);
    long elementSize;
    IconFamilyElement *srcElement;
    for (srcElement = (*hIconFamily)->elements; srcElement < endElement; srcElement = (IconFamilyElement *)((void*)srcElement + elementSize)) {
        elementSize = CFSwapInt32BigToHost(srcElement->elementSize);
        if (CFSwapInt32BigToHost(srcElement->elementType) == elementType) {
            if (srcElement != dstElement) {
                //NSLog(@"Sorting %@ ", NSFileTypeForHFSTypeCode(elementType));
                NSData *data = [NSData dataWithBytes:srcElement length:elementSize];
                memcpy((void*)dstElement + elementSize, dstElement, (void*)srcElement - (void*)dstElement);
                [data getBytes:dstElement];
            }
            else {
                //NSLog(@"Sorting %@ (no move)", NSFileTypeForHFSTypeCode(elementType));
            }
            dstElement = (IconFamilyElement *)((void*)dstElement + elementSize);
            break;
        } // if elementType
    } // for srcElement
    return dstElement;
}

- (BOOL) sortElements
{
    // need to sort the icon elements in the handle because is32 cannot be last (Finder and Preview would show 16x16 as blank)

    const OSType sortedElementTypes[] = {
        'TOC ',
        'icnV',
        'name',
        'info',

        kMini8BitData, // 'icm8'
        kMini4BitData, // 'icm4'
        kMini1BitMask, // 'icm#'

        kSmall32BitData, // 'is32'
        kSmall8BitData,  // 'ics8'
        kSmall4BitData,  // 'ics4'
        kSmall1BitMask,  // 'ics#'
        kSmall8BitMask,  // 's8mk'
        kIconServices16PixelDataARGB, // 'ic04' (virtual)

        kIconServices18PixelDataARGB, // 'icsb'

        kLarge32BitData, // 'il32'
        kLarge8BitData,  // 'icl8'
        kLarge4BitData,  // 'icl4'
        kLarge1BitMask,  // 'ICN#'
        kLarge8BitMask,  // 'l8mk'
        kIconServices32PixelDataARGB, // 'ic05' (virtual)

        kIconServices36PixelDataARGB, // 'icsd'

        kHuge32BitData, // 'ih32'
        kHuge8BitData,  // 'ich8'
        kHuge4BitData,  // 'ich4'
        kHuge8BitMask,  // 'h8mk'
        kHuge1BitMask,  // 'ich#'
        kIconServices48PixelDataARGB, // 'ic06' (virtual)

        kThumbnail32BitData, // 'it32'
        kThumbnail8BitMask,  // 't8mk'
        kIconServices128PixelDataARGB, // 'ic07' (virtual)

        kIconServices256PixelDataARGB, // 'ic08'
        kIconServices512PixelDataARGB, // 'ic09'

        kIconServices16RetinaPixelDataARGB,  // 'ic11'
        kIconServices18RetinaPixelDataARGB,  // 'icsB'
        kIconServices32RetinaPixelDataARGB,  // 'ic12'
        kIconServices128RetinaPixelDataARGB, // 'ic13'
        kIconServices256RetinaPixelDataARGB, // 'ic14'
        kIconServices512RetinaPixelDataARGB, // 'ic10' kIconServices1024PixelDataARGB
    };

    IconFamilyElement *dstElement = (*hIconFamily)->elements;
    for (int ndx = 0; ndx < sizeof(sortedElementTypes) / sizeof(sortedElementTypes[0]); ndx++) {
        dstElement = [self moveElementDataRaw:sortedElementTypes[ndx] dstElement:dstElement];
    } // for sortedElementTypes
    return YES;
}

- (BOOL) updateTOC
{
    NSMutableData* data = [NSMutableData dataWithLength:0];

    long oldHandleSize = GetHandleSize((Handle)hIconFamily);
    long oldSize = oldHandleSize < 8 ? 8 : CFSwapInt32BigToHost((*hIconFamily)->resourceSize);
    IconFamilyElement *endElement = (IconFamilyElement *)((void*)(*hIconFamily) + oldSize);
    long elementSize;
    IconFamilyElement *srcElement;
    for (srcElement = (*hIconFamily)->elements; srcElement < endElement; srcElement = (IconFamilyElement *)((void*)srcElement + elementSize)) {
        elementSize = CFSwapInt32BigToHost(srcElement->elementSize);
        OSType elementType = CFSwapInt32BigToHost(srcElement->elementType);
        switch (elementType) {
            case 'TOC ':
            case 'icnV':
            case 'name':
            case 'info':
                break;
            default:
                //NSLog(@"Adding %@ at %p to TOC", NSFileTypeForHFSTypeCode(elementType), srcElement);
                [data appendBytes:srcElement length:8];
        }
    }
    return [self setIconFamilyDataRaw:'TOC ' data:data];
}

- (BOOL) setIconFamilyElementPng:(NSBitmapImageRep*)bitmapImageRep elementType:(OSType)elementType requiredPixelSize:(int)requiredPixelSize
{
    NSDictionary *prop = @{ NSImageCompressionFactor : @(1.0f) };

    // convert to TIFF first because converting directly to PNG has a problem
    NSData *data0 = [bitmapImageRep representationUsingType:NSTIFFFileType properties:prop];
    if (data0 == nil) {
        NSLog(@"Error creating image data for type %d", (int)NSTIFFFileType);
        return NO;
    }

    NSBitmapImageRep *brep2 = [[NSBitmapImageRep alloc] initWithData: data0];
    NSData *data = [brep2 representationUsingType:NSPNGFileType properties:prop];
    if (data == nil) {
        NSLog(@"Error creating image data for type %d", (int)NSPNGFileType);
        return NO;
    }
    return [self setIconFamilyDataRaw:elementType data:data];
}

+ (Handle) get32BitDataFromBitmapImageRep:(NSBitmapImageRep*)bitmapImageRep requiredPixelSize:(int)requiredPixelSize
{
    Handle hRawData;
    unsigned char* pRawData;
    Size rawDataSize;

    // Get information about the bitmapImageRep.
    NSInteger pixelsWide      = [bitmapImageRep pixelsWide];
    NSInteger pixelsHigh      = [bitmapImageRep pixelsHigh];
    NSInteger bitsPerSample   = [bitmapImageRep bitsPerSample];
    NSInteger samplesPerPixel = [bitmapImageRep samplesPerPixel];
    NSInteger bitsPerPixel    = [bitmapImageRep bitsPerPixel];
    BOOL isPlanar             = [bitmapImageRep isPlanar];

    // Make sure bitmap has the required dimensions.
    if (pixelsWide != requiredPixelSize || pixelsHigh != requiredPixelSize)
    {
        NSLog(@"get32BitDataFromBitmapImageRep:requiredPixelSize: returning NULL due to %dx%d != %d", (int)pixelsWide, (int)pixelsHigh, requiredPixelSize);
        return NULL;
    }

    if (isPlanar)
    {
        NSLog(@"get32BitDataFromBitmapImageRep:requiredPixelSize: returning NULL due to isPlanar == YES");
        return NULL;
    }
    if (bitsPerSample != 8)
    {
        NSLog(@"get32BitDataFromBitmapImageRep:requiredPixelSize: returning NULL due to bitsPerSample == %ld", (long)bitsPerSample);
        return NULL;
    }

    if (((samplesPerPixel == 3) && (bitsPerPixel == 24)) || ((samplesPerPixel == 4) && (bitsPerPixel == 32))) {
        rawDataSize = pixelsWide * pixelsHigh * 4;
        hRawData = NewHandle( rawDataSize );
        if (hRawData == NULL)
            return NULL;
        pRawData = (unsigned char*) *hRawData;

        CGImageRef image = bitmapImageRep.CGImage;

        CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(image);

        NSInteger width = CGImageGetWidth(image);
        NSInteger height = CGImageGetHeight(image);


        CGDataProviderRef provider = CGImageGetDataProvider(image);
        CFDataRef data = CGDataProviderCopyData(provider);

        UInt8* bytes = malloc(width * height * 4);
        CFDataGetBytes(data, CFRangeMake(0, CFDataGetLength(data)), bytes);
        CFRelease(data);

        BOOL alphaFirst    = (alphaInfo == kCGImageAlphaFirst || alphaInfo == kCGImageAlphaPremultipliedFirst);
        BOOL premultiplied = (alphaInfo == kCGImageAlphaPremultipliedFirst || alphaInfo == kCGImageAlphaPremultipliedLast);
        CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(image);
        BOOL little        = ((bitmapInfo & kCGImageByteOrderMask) == kCGBitmapByteOrder32Little);

        if (bitsPerPixel == 32) {

            vImage_Buffer src;
            src.data = (void*)bytes;
            src.rowBytes = 4 * width;
            src.width = width;
            src.height = height;

            vImage_Buffer dest;
            dest.data = pRawData;
            dest.rowBytes = 4 * width;
            dest.width = width;
            dest.height = height;

            uint8_t permuteMap[4];
            if (alphaFirst) {
                if (little) {
                    // BGRA to ARGB
                    permuteMap[0] = 3;
                    permuteMap[1] = 2;
                    permuteMap[2] = 1;
                    permuteMap[3] = 0;
                } else {
                    // ARGB to ARGB
                    permuteMap[0] = 0;
                    permuteMap[1] = 1;
                    permuteMap[2] = 2;
                    permuteMap[3] = 3;
                }
            } else {
                if (little) {
                    // ABGR to ARGB
                    permuteMap[0] = 0;
                    permuteMap[1] = 3;
                    permuteMap[2] = 2;
                    permuteMap[3] = 1;
                } else {
                    // RGBA to ARGB
                    permuteMap[0] = 3;
                    permuteMap[1] = 0;
                    permuteMap[2] = 1;
                    permuteMap[3] = 2;
                }
            }

            vImagePermuteChannels_ARGB8888(&src, &dest, permuteMap, 0);

            if (premultiplied) {
                vImageUnpremultiplyData_ARGB8888(&dest, &dest, 0);
            }

        } else if (bitsPerPixel == 24) {

            vImage_Buffer src;
            src.data = (void*)bytes;
            src.rowBytes = 3 * width;
            src.width = width;
            src.height = height;

            vImage_Buffer dest;
            dest.data = pRawData;
            dest.rowBytes = 4 * width;
            dest.width = width;
            dest.height = height;

            vImageConvert_RGB888toARGB8888(&src, NULL, (Pixel_8)0xFFFF, &dest, false, 0);
            // RGB -> ARGB
            // BGR -> ABGR

            uint8_t permuteMap[4];
            if (little) {
                // ABGR to ARGB
                permuteMap[0] = 0;
                permuteMap[1] = 3;
                permuteMap[2] = 2;
                permuteMap[3] = 1;
            } else {
                // ARGB to ARGB
                permuteMap[0] = 0;
                permuteMap[1] = 1;
                permuteMap[2] = 2;
                permuteMap[3] = 3;
            }

            vImagePermuteChannels_ARGB8888(&dest, &dest, permuteMap, 0);

        }

        free(bytes);
    }
    else
    {
        NSLog(@"get32BitDataFromBitmapImageRep:requiredPixelSize: returning NULL due to samplesPerPixel == %ld, bitsPerPixel == %ld",
              (long)samplesPerPixel, (long)bitsPerPixel);
        return NULL;
    }

    return hRawData;
}

+ (Handle) get8BitDataFromBitmapImageRep:(NSBitmapImageRep*)bitmapImageRep requiredPixelSize:(int)requiredPixelSize
{
    Handle hRawData;
    unsigned char* pRawData;
    Size rawDataSize;
    unsigned char* pSrc;
    unsigned char* pDest;
    int x, y;

    // Get information about the bitmapImageRep.
    NSInteger pixelsWide      = [bitmapImageRep pixelsWide];
    NSInteger pixelsHigh      = [bitmapImageRep pixelsHigh];
    NSInteger bitsPerSample   = [bitmapImageRep bitsPerSample];
    NSInteger samplesPerPixel = [bitmapImageRep samplesPerPixel];
    NSInteger bitsPerPixel    = [bitmapImageRep bitsPerPixel];
    BOOL isPlanar             = [bitmapImageRep isPlanar];
    NSInteger bytesPerRow     = [bitmapImageRep bytesPerRow];
    unsigned char* bitmapData = [bitmapImageRep bitmapData];

    // Make sure bitmap has the required dimensions.
    if (pixelsWide != requiredPixelSize || pixelsHigh != requiredPixelSize)
        return NULL;

    // So far, this code only handles non-planar 32-bit RGBA and 24-bit RGB source bitmaps.
    // This could be made more flexible with some additional programming...
    if (isPlanar)
    {
        NSLog(@"get8BitDataFromBitmapImageRep:requiredPixelSize: returning NULL due to isPlanar == YES");
        return NULL;
    }
    if (bitsPerSample != 8)
    {
        NSLog(@"get8BitDataFromBitmapImageRep:requiredPixelSize: returning NULL due to bitsPerSample == %ld",
              (long)bitsPerSample);
        return NULL;
    }

    if (((samplesPerPixel == 3) && (bitsPerPixel == 24)) || ((samplesPerPixel == 4) && (bitsPerPixel == 32)))
    {
        rawDataSize = pixelsWide * pixelsHigh;
        hRawData = NewHandle( rawDataSize );
        if (hRawData == NULL)
            return NULL;
        pRawData = (unsigned char*) *hRawData;

        pDest = pRawData;
        if (bitsPerPixel == 32) {
            for (y = 0; y < pixelsHigh; y++) {
                pSrc = bitmapData + y * bytesPerRow;
                for (x = 0; x < pixelsWide; x++) {
                    unsigned char r = *(pSrc + 1);
                    unsigned char g = *(pSrc + 2);
                    unsigned char b = *(pSrc + 3);

                    *pDest++ = (0 << 24) | (r << 16) | (g << 8) | b;

                    pSrc+=4;
                }
            }
        } else if (bitsPerPixel == 24) {
            for (y = 0; y < pixelsHigh; y++) {
                pSrc = bitmapData + y * bytesPerRow;
                for (x = 0; x < pixelsWide; x++) {
                    unsigned char r = *(pSrc);
                    unsigned char g = *(pSrc + 1);
                    unsigned char b = *(pSrc + 2);

                    *pDest++ = (0 << 24) | (r << 16) | (g << 8) | b;

                    pSrc+=3;
                }
            }
        }

    }
    else
    {
        NSLog(@"get8BitDataFromBitmapImageRep:requiredPixelSize: returning NULL due to samplesPerPixel == %ld, bitsPerPixel == %ld",
              (long)samplesPerPixel, (long)bitsPerPixel);
        return NULL;
    }

    return hRawData;
}

+ (Handle) get8BitMaskFromBitmapImageRep:(NSBitmapImageRep*)bitmapImageRep requiredPixelSize:(int)requiredPixelSize
{
    Handle hRawData;
    unsigned char* pRawData;
    Size rawDataSize;
    unsigned char* pSrc;
    unsigned char* pDest;
    int x, y;

    // Get information about the bitmapImageRep.
    long pixelsWide      = [bitmapImageRep pixelsWide];
    long pixelsHigh      = [bitmapImageRep pixelsHigh];
    long bitsPerSample   = [bitmapImageRep bitsPerSample];
    long samplesPerPixel = [bitmapImageRep samplesPerPixel];
    long bitsPerPixel    = [bitmapImageRep bitsPerPixel];
    BOOL isPlanar       = [bitmapImageRep isPlanar];
    long bytesPerRow     = [bitmapImageRep bytesPerRow];
    unsigned char* bitmapData = [bitmapImageRep bitmapData];

    // Make sure bitmap has the required dimensions.
    if (pixelsWide != requiredPixelSize || pixelsHigh != requiredPixelSize)
        return NULL;

    // So far, this code only handles non-planar 32-bit RGBA, 24-bit RGB and 8-bit grayscale source bitmaps.
    // This could be made more flexible with some additional programming...
    if (isPlanar)
    {
        NSLog(@"get8BitMaskFromBitmapImageRep:requiredPixelSize: returning NULL due to isPlanar == YES");
        return NULL;
    }
    if (bitsPerSample != 8)
    {
        NSLog(@"get8BitMaskFromBitmapImageRep:requiredPixelSize: returning NULL due to bitsPerSample == %ld", bitsPerSample);
        return NULL;
    }

    if (((samplesPerPixel == 1) && (bitsPerPixel == 8)) || ((samplesPerPixel == 3) && (bitsPerPixel == 24)) || ((samplesPerPixel == 4) && (bitsPerPixel == 32)))
    {
        rawDataSize = pixelsWide * pixelsHigh;
        hRawData = NewHandle( rawDataSize );
        if (hRawData == NULL)
            return NULL;
        pRawData = (unsigned char*) *hRawData;

        pSrc = bitmapData;
        pDest = pRawData;

        if (bitsPerPixel == 32) {
            for (y = 0; y < pixelsHigh; y++) {
                pSrc = bitmapData + y * bytesPerRow;
                for (x = 0; x < pixelsWide; x++) {
                    pSrc += 3;
                    *pDest++ = *pSrc++;
                }
            }
        }
        else if (bitsPerPixel == 24) {
            memset( pDest, 255, rawDataSize );
        }
        else if (bitsPerPixel == 8) {
            for (y = 0; y < pixelsHigh; y++) {
                memcpy( pDest, pSrc, pixelsWide );
                pSrc += bytesPerRow;
                pDest += pixelsWide;
            }
        }
    }
    else
    {
        NSLog(@"get8BitMaskFromBitmapImageRep:requiredPixelSize: returning NULL due to samplesPerPixel == %ld, bitsPerPixel == %ld", samplesPerPixel, bitsPerPixel);
        return NULL;
    }

    return hRawData;
}

// NOTE: This method hasn't been fully tested yet.
+ (Handle) get1BitMaskFromBitmapImageRep:(NSBitmapImageRep*)bitmapImageRep requiredPixelSize:(int)requiredPixelSize
{
    Handle hRawData;
    unsigned char* pRawData;
    Size rawDataSize;
    unsigned char* pSrc;
    unsigned char* pDest;
    int x, y;
    unsigned char maskByte;

    // Get information about the bitmapImageRep.
    long pixelsWide      = [bitmapImageRep pixelsWide];
    long pixelsHigh      = [bitmapImageRep pixelsHigh];
    long bitsPerSample   = [bitmapImageRep bitsPerSample];
    long samplesPerPixel = [bitmapImageRep samplesPerPixel];
    long bitsPerPixel    = [bitmapImageRep bitsPerPixel];
    BOOL isPlanar        = [bitmapImageRep isPlanar];
    long bytesPerRow     = [bitmapImageRep bytesPerRow];
    unsigned char* bitmapData = [bitmapImageRep bitmapData];

    // Make sure bitmap has the required dimensions.
    if (pixelsWide != requiredPixelSize || pixelsHigh != requiredPixelSize)
        return NULL;

    // So far, this code only handles non-planar 32-bit RGBA, 24-bit RGB, 8-bit grayscale, and 1-bit source bitmaps.
    // This could be made more flexible with some additional programming...
    if (isPlanar)
    {
        NSLog(@"get1BitMaskFromBitmapImageRep:requiredPixelSize: returning NULL due to isPlanar == YES");
        return NULL;
    }

    if (((bitsPerPixel == 1) && (samplesPerPixel == 1) && (bitsPerSample == 1)) || ((bitsPerPixel == 8) && (samplesPerPixel == 1) && (bitsPerSample == 8)) ||
        ((bitsPerPixel == 24) && (samplesPerPixel == 3) && (bitsPerSample == 8)) || ((bitsPerPixel == 32) && (samplesPerPixel == 4) && (bitsPerSample == 8)))
    {
        rawDataSize = (pixelsWide * pixelsHigh)/4;
        hRawData = NewHandle( rawDataSize );
        if (hRawData == NULL)
            return NULL;
        pRawData = (unsigned char*) *hRawData;

        pSrc = bitmapData;
        pDest = pRawData;

        if (bitsPerPixel == 32) {
            for (y = 0; y < pixelsHigh; y++) {
                pSrc = bitmapData + y * bytesPerRow;
                for (x = 0; x < pixelsWide; x += 8) {
                    maskByte = 0;
                    maskByte |= (*(unsigned*)pSrc & 0xff) ? 0x80 : 0; pSrc += 4;
                    maskByte |= (*(unsigned*)pSrc & 0xff) ? 0x40 : 0; pSrc += 4;
                    maskByte |= (*(unsigned*)pSrc & 0xff) ? 0x20 : 0; pSrc += 4;
                    maskByte |= (*(unsigned*)pSrc & 0xff) ? 0x10 : 0; pSrc += 4;
                    maskByte |= (*(unsigned*)pSrc & 0xff) ? 0x08 : 0; pSrc += 4;
                    maskByte |= (*(unsigned*)pSrc & 0xff) ? 0x04 : 0; pSrc += 4;
                    maskByte |= (*(unsigned*)pSrc & 0xff) ? 0x02 : 0; pSrc += 4;
                    maskByte |= (*(unsigned*)pSrc & 0xff) ? 0x01 : 0; pSrc += 4;
                    *pDest++ = maskByte;
                }
            }
        }
        else if (bitsPerPixel == 24) {
            memset( pDest, 255, rawDataSize );
        }
        else if (bitsPerPixel == 8) {
            for (y = 0; y < pixelsHigh; y++) {
                pSrc = bitmapData + y * bytesPerRow;
                for (x = 0; x < pixelsWide; x += 8) {
                    maskByte = 0;
                    maskByte |= *pSrc++ ? 0x80 : 0;
                    maskByte |= *pSrc++ ? 0x40 : 0;
                    maskByte |= *pSrc++ ? 0x20 : 0;
                    maskByte |= *pSrc++ ? 0x10 : 0;
                    maskByte |= *pSrc++ ? 0x08 : 0;
                    maskByte |= *pSrc++ ? 0x04 : 0;
                    maskByte |= *pSrc++ ? 0x02 : 0;
                    maskByte |= *pSrc++ ? 0x01 : 0;
                    *pDest++ = maskByte;
                }
            }
        }
        else if (bitsPerPixel == 1) {
            for (y = 0; y < pixelsHigh; y++) {
                memcpy( pDest, pSrc, pixelsWide / 8 );
                pDest += pixelsWide / 8;
                pSrc += bytesPerRow;
            }
        }

        memcpy( pRawData+(pixelsWide*pixelsHigh)/8, pRawData, (pixelsWide*pixelsHigh)/8 );
    }
    else
    {
        NSLog(@"get1BitMaskFromBitmapImageRep:requiredPixelSize: returning NULL due to bitsPerPixel == %ld, samplesPerPixel== %ld, bitsPerSample == %ld", bitsPerPixel, samplesPerPixel, bitsPerSample);
        return NULL;
    }

    return hRawData;
}

- (BOOL) addResourceType:(OSType)type asResID:(int)resID
{
    Handle hIconRes = NewHandle(0);
    OSErr err;

    err = GetIconFamilyData( hIconFamily, type, hIconRes );

    if( !GetHandleSize(hIconRes) || err != noErr )
        return NO;

    AddResource( hIconRes, type, resID, "\p" );

    return YES;
}
@end

