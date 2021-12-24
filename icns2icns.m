/*
    icns2icns - Mac command line program to process an Apple icns file

    Copyright (c) 2021, Joe van Tunen <joevt@shaw.ca>
    All rights reserved.

    Redistribution and use in source and binary forms, with or without modification,
    are permitted provided that the following conditions are met:

    1. Redistributions of source code must retain the above copyright notice, this
    list of conditions and the following disclaimer.

    2. Redistributions in binary form must reproduce the above copyright notice, this
    list of conditions and the following disclaimer in the documentation and/or other
    materials provided with the distribution.

    3. Neither the name of the copyright holder nor the names of its contributors may
    be used to endorse or promote products derived from this software without specific
    prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
    ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
    WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
    IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
    INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
    NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
    PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
    WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
    ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
*/

#import <Cocoa/Cocoa.h>
#import "CLI.h"
#import "IconFamily.h"

static const char optstring[] = "vht:r:";

static struct option long_options[] = {
    {"version",     no_argument,        0,  'v'},
    {"help",        no_argument,        0,  'h'},
    {0,             0,                  0,    0}
};

static NSUInteger ImageTypeForSuffix(NSString *suffix);
static void PrintHelp(void);
static int saveImage(NSBitmapImageRep *brep, OSType elementType, NSString *suffix, NSString *destPath, int ndx);


int main(int argc, const char * argv[]) { @autoreleasepool {

    int optch;
    int long_index = 0;

    // parse getopt
    while ((optch = getopt_long(argc, (char *const *)argv, optstring, long_options, &long_index)) != -1) {
        switch (optch) {

            // image format
            // print version
            case 'v':
                PrintProgramVersion();
                break;

            // print help
            case 'h':
            default:
            {
                PrintHelp();
                exit(EXIT_SUCCESS);
            }
                break;
        }
    }

    NSMutableArray *args = ReadRemainingArgs(argc, argv);
    if ([args count] < 2) {
        PrintHelp();
        exit(EX_USAGE);
    }

    NSString *srcPath = [args[0] stringByExpandingTildeInPath];
    NSString *destPath = [args[1] stringByExpandingTildeInPath];

    // make sure source file exists
    if (![[NSFileManager defaultManager] fileExistsAtPath:srcPath]) {
        NSPrintErr(@"File '%@' does not exist", srcPath);
        exit(EXIT_FAILURE);
    }

    // make sure destination path is writable
    if ([[NSFileManager defaultManager] fileExistsAtPath:destPath] &&
        ![[NSFileManager defaultManager] isWritableFileAtPath:destPath]) {
        NSPrintErr(@"Cannot write to path '%@'", destPath);
        exit(EX_CANTCREAT);
    }

    // read icon from source file
    IconFamily *icon = [IconFamily iconFamilyWithContentsOfFile:srcPath];
    NSImage *img = [icon imageWithAllReps];
    NSArray *reps = [img representations];
    if (img == nil || [reps count] == 0) {
        NSPrintErr(@"Error reading icon from file");
        exit(EXIT_FAILURE);
    }

    // create icon
    IconFamily *iconFam = [[IconFamily alloc] init];
    if (iconFam == nil)  {
        NSPrintErr(@"Error creating icon");
        return EXIT_FAILURE;
    }

    int ndx = 0;
    for (NSImageRep *rep in reps) {
        //NSPrintErr(@"%d)", ndx);

        if (![rep isKindOfClass:[NSBitmapImageRep class]]) {
            continue;
        }
        NSBitmapImageRep *brep = (NSBitmapImageRep *)rep;
        //if ([brep pixelsWide] == [brep size].width)
        {
            if (![iconFam setIconFamilyElement:brep])
                NSPrintErr(@"Could not add rep to icon");
        }

        /*
        OSType elementType = [iconFam getImageElementType:brep];
        saveImage(brep, elementType, @"tiff", destPath, ndx);
        saveImage(brep, elementType, @"png", destPath, ndx);

        NSPrintErr(@"type:%@ rep:%@ class:%@", NSFileTypeForHFSTypeCode(elementType), rep, [rep class]);

        NSString *destPath2 = [NSString stringWithFormat:@"%@_%d_%@_%dx%d.icns", destPath, ndx, NSFileTypeForHFSTypeCode(elementType), (int)[brep pixelsWide], (int)[brep pixelsHigh] ];
        BOOL res = [iconFam writeToFile:destPath2];
         */

        ndx++;
    }

    BOOL res = [iconFam writeToFile:destPath];

    // make sure we were successful
    if (res == NO || ![[NSFileManager defaultManager] fileExistsAtPath:destPath]) {
        NSPrintErr(@"Failed to create icns file at path '%@'", destPath);
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}}

static NSUInteger ImageTypeForSuffix(NSString *suffix) {

    NSDictionary *map = @{  @"jpg" : @(NSJPEGFileType),
                            @"jpeg": @(NSJPEGFileType),
                            @"png":  @(NSPNGFileType),
                            @"gif":  @(NSGIFFileType),
                            @"tiff": @(NSTIFFFileType),
                            @"bmp":  @(NSBMPFileType)   };

    NSString *s = [suffix lowercaseString];
    NSNumber *imgTypeNum = map[s];
    if (!imgTypeNum) {
        return -1;
    }

    return [imgTypeNum unsignedIntegerValue];
}

static void PrintHelp(void) {
    NSPrintErr(@"usage: icns2icns src dest");
}

static int saveImage(NSBitmapImageRep *brep, OSType elementType, NSString *suffix, NSString *destPath, int ndx)
{
    NSInteger imgType = ImageTypeForSuffix(suffix);
    if (imgType == -1) {
        NSPrintErr(@"Unable to determine image type from suffix '%@'", suffix);
        return(1);
    }

    NSDictionary *prop = @{ NSImageCompressionFactor : @(1.0f) };

    // convert to TIFF first (converting to png first causes a problem)
    NSData *data0 = [brep representationUsingType:NSTIFFFileType properties:prop];
    if (data0 == nil) {
        NSPrintErr(@"Error creating image data for type %d", NSTIFFFileType);
        return(EX_DATAERR);
    }

    // convert to wanted type
    NSBitmapImageRep *brep2 = [[NSBitmapImageRep alloc] initWithData: data0];
    NSData *data = [brep2 representationUsingType:imgType properties:prop];
    if (data == nil) {
        NSPrintErr(@"Error creating image data for type %d", imgType);
        return(EX_DATAERR);
    }

    NSString *destPath2 = [NSString stringWithFormat:@"%@_%d_%@_%dx%d.%@", destPath, ndx, NSFileTypeForHFSTypeCode(elementType), (int)[brep pixelsWide], (int)[brep pixelsHigh], suffix ];
    if ([data writeToFile:destPath2 atomically:YES] == NO) {
        NSPrintErr(@"Error writing image to destination");
        return(EX_IOERR);
    }

    return(EX_OK);
}
