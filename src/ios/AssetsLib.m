//
//  AssetsLib.m
//
//  Created by glowmar on 12/27/13.
//
//

#import "AssetsLib.h"
#import "AssetsLibrary/ALAssetsLibrary.h"
#import "AssetsLibrary/ALAssetsFilter.h"
#import "AssetsLibrary/ALAssetsGroup.h"
#import "AssetsLibrary/ALAsset.h"
#import "AssetsLibrary/ALAssetRepresentation.h"


@interface AssetsLib ()

@property (nonatomic, strong) ALAssetsLibrary *assetsLibrary;
@property (nonatomic, strong) NSMutableArray *groups;
@property (nonatomic, strong) NSMutableArray *assets;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) NSMutableArray *assetsAlbumName;

@property int assetsCount;

@end


@implementation AssetsLib


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// getAllPhotoThumbnails

- (void)getAllPhotos:(CDVInvokedUrlCommand*)command
{
    NSLog(@"getAllPhotos");
    if (self.assetsLibrary == nil) {
        _assetsLibrary = [[ALAssetsLibrary alloc] init];
    }
    if (self.groups == nil) {
        _groups = [[NSMutableArray alloc] init];
    } else {
        [self.groups removeAllObjects];
    }
    if (!self.assets) {
        _assets = [[NSMutableArray alloc] init];
    } else {
        [self.assets removeAllObjects];
    }
    if (!self.assetsAlbumName) {
        _assetsAlbumName = [[NSMutableArray alloc] init];
    } else {
        [self.assetsAlbumName removeAllObjects];
    }
    
    self.assetsCount = 0;
    
    ALAssetsGroupEnumerationResultsBlock assetsEnumerationBlock = ^(ALAsset *result, NSUInteger index, BOOL *stop) {
        if (result) {
            [self.assets addObject:result];
            if ([self.assets count] == self.assetsCount)
            {
                NSLog(@"Got all %d photos",self.assetsCount);
                [self getAllPhotosComplete:command with:nil];
            }
        }
    };
    
    // setup our failure view controller in case enumerateGroupsWithTypes fails
    ALAssetsLibraryAccessFailureBlock failureBlock = ^(NSError *error) {
        
        NSString* errorMessage = nil;
        switch ([error code]) {
            case ALAssetsLibraryAccessUserDeniedError:
            case ALAssetsLibraryAccessGloballyDeniedError:
                errorMessage = @"The user has declined access to it.";
                break;
            default:
                errorMessage = @"Reason unknown.";
                break;
        }
        NSLog(@"Problem reading assets library %@",errorMessage);
        [self getAllPhotosComplete:command with:errorMessage];
    };
    
    ALAssetsLibraryGroupsEnumerationResultsBlock listGroupBlock = ^(ALAssetsGroup *group, BOOL *stop) {
        ALAssetsFilter *onlyPhotosFilter = [ALAssetsFilter allPhotos];
        [group setAssetsFilter:onlyPhotosFilter];
        // NSLog(@"AssetsLib::getAllPhotos::listGroupBlock > %@ (%d)   type: %@    url: %@",[group valueForProperty:ALAssetsGroupPropertyName],[group numberOfAssets],[group valueForProperty:ALAssetsGroupPropertyType],[group valueForProperty:ALAssetsGroupPropertyURL]);
        if ([group numberOfAssets] > 0)
        {
            int groupAssetNum = [group numberOfAssets];
            NSString *groupName = [group valueForProperty:ALAssetsGroupPropertyName];
            NSLog(@"Got asset group \"%@\" with %ld photos",groupName,(long)groupAssetNum);
            
            //Save Album names to given image
            for (int i=0; i<groupAssetNum; i++) {
                [self.assetsAlbumName addObject:groupName];
            }
            
            [self.groups addObject:group];
            self.assetsCount += [group numberOfAssets];
        }
        else
        {
            NSLog(@"Got all %lu asset groups with total %d assets",(unsigned long)[self.groups count],self.assetsCount);
            for (group in self.groups)
            {   // Enumarate each asset group
                ALAssetsFilter *onlyPhotosFilter = [ALAssetsFilter allPhotos];
                NSLog(@"in AssetLib, group is %@", group);
                [group setAssetsFilter:onlyPhotosFilter];
                [group enumerateAssetsUsingBlock:assetsEnumerationBlock];
            }
        }
    };
    
    // enumerate only photos
    NSUInteger groupTypes = ALAssetsGroupAll; // ALAssetsGroupAlbum | ALAssetsGroupEvent | ALAssetsGroupFaces | ALAssetsGroupSavedPhotos | ALAssetsGroupPhotoStream;
    [self.assetsLibrary enumerateGroupsWithTypes:groupTypes usingBlock:listGroupBlock failureBlock:failureBlock];
}

- (void)getAllPhotosComplete:(CDVInvokedUrlCommand*)command with:(NSString*)error
{
    CDVPluginResult* pluginResult = nil;
    
    if (error != nil && [error length] > 0)
    {   // Call error
        NSLog(@"Error occured for command.callbackId:%@, error:%@", command.callbackId, error);
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error];
    }
    else
    {   // Call was successful
        NSMutableDictionary* photos = [NSMutableDictionary dictionaryWithDictionary:@{}];
        for (int i=0; i<[self.assets count]; i++)
        {
            ALAsset* asset = self.assets[i];
            NSString* url = [[asset valueForProperty:ALAssetPropertyAssetURL] absoluteString];
            NSString* albumName =  self.assetsAlbumName[i];
            //            NSLog(@"in getAllPhotosComplete: url is %@", url);
            //            NSLog(@"in getAllPhotosComplete: albumName is %@", albumName);
            
            
            NSDictionary* photo = @{
                                    @"url": url,
                                    @"albumName": albumName
                                    };
            [photos setObject:photo forKey:photo[@"url"]];
            [photos setObject:photo forKey:photo[@"albumName"]];
            
            
        }
        NSArray* photoMsg = [photos allValues];
        NSLog(@"Sending to phonegap application message with %lu photos",(unsigned long)[photoMsg count]);
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:photoMsg];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// getThumbnails

- (void)getPhotoMetadata:(CDVInvokedUrlCommand*)command
{
    NSLog(@"getPhotoMetadata");
    
    ALAssetsLibraryProcessBlock processMetadataBlock = ^(ALAsset *asset) {
        if (self.dateFormatter == nil) {
            _dateFormatter = [[NSDateFormatter alloc] init];
            _dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
        }
        NSString* url = [[asset valueForProperty:ALAssetPropertyAssetURL] absoluteString];
        NSString* date = [self.dateFormatter stringFromDate:[asset valueForProperty:ALAssetPropertyDate]];
        
        NSDictionary* photo = @{
                                @"url": url,
                                @"date": date
                                };
        NSMutableDictionary* photometa = [self getImageMeta:asset];
        [photometa addEntriesFromDictionary:photo];
        return photometa;
    };
    
    [self getPhotos:command processBlock:processMetadataBlock];
}

- (void)getFullScreenPhotos:(CDVInvokedUrlCommand*)command
{
    NSLog(@"getFullScreenPhotos");
    
    ALAssetsLibraryProcessBlock processFullScreenPhotoBlock = ^(ALAsset *asset) {
        ALAssetRepresentation* representation = [asset defaultRepresentation];
        CGImageRef imageRef = [representation fullScreenImage];
        UIImage* img = [UIImage imageWithCGImage:imageRef];
        NSString* base64src = [UIImagePNGRepresentation(img) base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
        NSDictionary* base64dict = @{@"base64encoded": base64src};
        return base64dict;
        
    };
    
    [self getPhotos:command processBlock:processFullScreenPhotoBlock];
    
}


- (void)getThumbnails:(CDVInvokedUrlCommand*)command
{
    NSLog(@"getThumbnails");
    
    ALAssetsLibraryProcessBlock processThumbnailsBlock = ^(ALAsset *asset) {
        NSString* url = [[asset valueForProperty:ALAssetPropertyAssetURL] absoluteString];
        CGImageRef thumbnailImageRef = [asset thumbnail];
        UIImage* thumbnail = [UIImage imageWithCGImage:thumbnailImageRef];
        
        NSString* base64encoded = [UIImagePNGRepresentation(thumbnail) base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
//        NSLog(@"thumbnail.image.height is %f", thumbnail.size.height);
//        NSLog(@"in Assetslib, base64encoded is %@", base64encoded);
        NSDictionary* photo = @{
                                @"url": url,
                                @"base64encoded": base64encoded
                                };
        return photo;
    };
    
    [self.commandDelegate runInBackground:^{
        [self getPhotos:command processBlock:processThumbnailsBlock];
    }];

}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Gets asset representation meta data
- (NSMutableDictionary* ) getImageMeta:(ALAsset*)asset
{
    ALAssetRepresentation* representation = [asset defaultRepresentation];
    struct CGSize size = [representation dimensions];
    NSDictionary* metadata = [representation metadata];
    
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    [dict setValue:[representation filename] forKey:@"filename"];
    [dict setValue:@(size.width) forKey:@"width"];
    [dict setValue:@(size.height) forKey:@"height"];
    
    //@"{GPS}"
    NSDictionary* gps = [metadata objectForKey:@"{GPS}"];
    if (gps != nil){
        NSNumber* Latitude     = [gps objectForKey:@"Latitude"];
        NSNumber* Longitude    = [gps objectForKey:@"Longitude"];
        NSString* LatitudeRef  = [gps objectForKey:@"LatitudeRef"];
        NSString* LongitudeRef = [gps objectForKey:@"LongitudeRef"];
        [dict setValue:Latitude forKey:@"gps_Latitude"];
        [dict setValue:Longitude forKey:@"gps_Longitude"];
        [dict setValue:LatitudeRef forKey:@"gps_LatitudeRef"];
        [dict setValue:LongitudeRef forKey:@"gps_LongitudeRef"];

        
        
    }
    //@"{Exif}"
    NSDictionary* exif = [metadata objectForKey:@"{Exif}"];
    if (exif != nil){
        NSString* DateTimeOriginal  = [exif objectForKey:@"DateTimeOriginal"];
        NSString* DateTimeDigitized = [exif objectForKey:@"DateTimeDigitized"];
        [dict setValue:DateTimeOriginal forKey:@"exif_DateTimeOriginal"];
        [dict setValue:DateTimeDigitized forKey:@"exif_DateTimeDigitized"];
    }
    //@"{IPTC}"
    NSDictionary* iptc = [metadata objectForKey:@"{IPTC}"];
    if (iptc != nil){
        NSArray* Keywords = [iptc objectForKey:@"Keywords"];
        [dict setValue:Keywords forKey:@"iptc_Keywords"];
    }
    //[AssetsLib logDict:dict];
    return dict;
}

+ (void) logDict:(NSDictionary*)dict
{
    for (id key in dict)
    {
        NSLog(@"key: %@, value: %@ ", key, [dict objectForKey:key]);
    }
}




///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Common method which gets assets for one or more url's and processes them given processBlock

// This block is executed for each asset
typedef NSDictionary* (^ALAssetsLibraryProcessBlock)(ALAsset *asset);

- (void)getPhotos:(CDVInvokedUrlCommand*)command processBlock:(ALAssetsLibraryProcessBlock)process
{
    NSArray* urlList = [command.arguments objectAtIndex:0];
    if (urlList != nil && [urlList count] > 0)
    {
        if (self.assetsLibrary == nil) {
            _assetsLibrary = [[ALAssetsLibrary alloc] init];
        }
        
        NSMutableDictionary* photos = [NSMutableDictionary dictionaryWithDictionary:@{}];
        
        for (int i=0; i<[urlList count]; i++)
        {
            NSString* urlString = [urlList objectAtIndex:i];
            NSURL *url = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
            //NSLog(@"Asset url: %@", url);
            [self.assetsLibrary assetForURL:url
                                resultBlock: ^(ALAsset *asset){
                                    NSDictionary* photo = process(asset);
//                                    NSLog(@"Done %d: %@", i, photo[@"url"]);
                                    [photos setObject:photo forKey:photo[@"url"]];
                                    
                                    int urlListCount = [urlList count];
                                    int photosCount = [photos count];
//                                    NSLog(@"in assetslib: urlList is %i", urlListCount);
//                                    NSLog(@"in assetslib: photocount is %i", photosCount);
                                    
                                    if ([urlList count] == [photos count])
                                    {
                                        
                                        NSArray* photoMsg = [photos allValues];
                                        NSLog(@"Sending to phonegap application message with %lu photos",(unsigned long)[photoMsg count]);
                                        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:photoMsg];
                                        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                                    }
                                }
                               failureBlock: ^(NSError *error)
             {
                 NSLog(@"Failed to process asset(s)");
                 [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR] callbackId:command.callbackId];
             }
             ];
        }
    }
    else
    {
        NSLog(@"Missing parameter urlList");
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR] callbackId:command.callbackId];
    }
}

@end
