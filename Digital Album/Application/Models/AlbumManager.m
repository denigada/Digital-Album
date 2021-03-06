//
//  ImageManager.m
//  Digital Album
//
//  Created by Ernesto Carrion on 2/17/14.
//  Copyright (c) 2014 Salarion. All rights reserved.
//

#import <AssetsLibrary/AssetsLibrary.h>
#import "AlbumManager.h"

#define ALBUMS_OBJ_PATH @"albums.array"

@interface AlbumManager ()

@property (nonatomic, strong) ALAssetsLibrary * lib;
@end

@implementation AlbumManager

+(AlbumManager *)manager {
    
    static AlbumManager * manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[AlbumManager alloc] init];
    });
    
    return manager;
}

- (id)init {
    
    self = [super init];
    if (self) {
        
        NSArray * paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString * basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
        _documentsDirectoryPath = basePath;
    }
    return self;
}

#pragma mark - Get

//Get Albums from phone
-(void)phoneAlbumsWithBlock:(void (^)(NSArray *, NSError *))block {
    
    if (!self.lib) {
        self.lib = [[ALAssetsLibrary alloc] init];
    }
    __block NSMutableArray * albumsArray = [NSMutableArray array];
    
    [self.lib enumerateGroupsWithTypes:ALAssetsGroupAll usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
        
        if (group) {
        
            DAPhoneAlbum * album = [DAPhoneAlbum AlbumWithGroup:group];
            NSMutableArray * imagesArray = [NSMutableArray array];
            [group enumerateAssetsUsingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
                
                if (result) {
                    
                    NSString *assetType = [result valueForProperty:ALAssetPropertyType];
                    if ([assetType isEqualToString:ALAssetTypePhoto]) {
                        
                        DAImage * image = [DAImage imageWithLocalAsset:result];
                        [imagesArray addObject:image];
                    }
                }
            }];
            
            
            if (imagesArray.count > 0) {
                album.images = [imagesArray copy];
                [albumsArray addObject:album];
            }
            imagesArray = nil;
            
        } else {
            
            //Group nil
            //Iteration ended
            if (block) {
                block([albumsArray copy], nil);
                albumsArray = nil;
            }
        }
     
    } failureBlock:^(NSError *error) {
        
        if (block)
            block(nil, error);
    }];
}

//Get Digital Albums from disk
-(NSArray *)savedAlbums {
    
    NSString * savedAlbumsPath = [self.documentsDirectoryPath stringByAppendingPathComponent:ALBUMS_OBJ_PATH];
    NSArray * savedAlbums = [NSKeyedUnarchiver unarchiveObjectWithFile:savedAlbumsPath];
    if (!savedAlbums)
        savedAlbums = [NSArray array];
    
    return savedAlbums;
}


#pragma mark - Save

//iterate trought all DAImages and save its content to disk, then saves
//the album aray to disk
-(void)saveAlbum:(DAAlbum *)album onCompletion:(void(^)(BOOL success))block {
    
    __block BOOL success = YES;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        for (DAPage * page in album.pages) {
            for (DAImage * image in page.images) {
                
                BOOL result = [self saveImage:image inPage:page inAlbum:album];
                if (success)
                    success = result;
            }
        }
        
        if (success) {
            
            NSMutableArray * savedAlbums = [self savedAlbums].mutableCopy;
            NSUInteger index = [savedAlbums indexOfObject:album];
            if (index != NSNotFound) {
                savedAlbums[index] = album;
            } else {
                [savedAlbums addObject:album];
            }
            
            success = [self saveAlbumsToDisk:savedAlbums.copy];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
           
            if (block) {
                block(success);
            }
            
        });
    });
}

//Save the album array to disk
-(BOOL)saveAlbumsToDisk:(NSArray *)albums {
    
    NSString * savedAlbumsPath = [self.documentsDirectoryPath stringByAppendingPathComponent:ALBUMS_OBJ_PATH];
    return [NSKeyedArchiver archiveRootObject:albums toFile:savedAlbumsPath];
}

//Saves UIImage from DAImage to disk for an Album
-(BOOL)saveImage:(DAImage *)image inPage:(DAPage *)page inAlbum:(DAAlbum *)album {
    
    BOOL result = NO;
    if ([self createFolderForAlbum:album andPage:page]) {
        
        
        @autoreleasepool {
            
            NSString * imagePath = [self pathForImage:image inPage:page inAlbum:album];
            result = [self saveImage:image atPath:imagePath];
        }
    }
    
    return result;
}

//Saves UIImage from DAImage to disk at a specifieldPath
-(BOOL)saveImage:(DAImage *)image atPath:(NSString *)imagePath {
    
    if (![image hasSomethingToSave]) {
        return YES;
    }
    
    if (imagePath.length <= 0) {
        return NO;
    }
    
    NSData * imageData = nil;
    if (image.modifiedImage) {
        imageData = UIImageJPEGRepresentation(image.modifiedImage, 1.0);
    }
    else if (image.localAsset) {
        imageData = UIImageJPEGRepresentation([image localImage], 1.0);
    }
    
    BOOL result = [imageData writeToFile:imagePath atomically:YES];
    imageData = nil;
    
    if (result) {
        
        image.modifiedImage = nil;
        image.localAsset = nil;
        image.imagePath = [imagePath stringByReplacingOccurrencesOfString:self.documentsDirectoryPath withString:@""];
        
    }
    
    return result;
}



#pragma mark - Delete

//Delete album from disk if it exists
-(BOOL)deleteAlbum:(DAAlbum *)album {
    
    NSString * albumPath = [self pathForAlbum:album];
    BOOL success = YES;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:albumPath isDirectory:nil]) {
        success = [[NSFileManager defaultManager] removeItemAtPath:albumPath error:nil];
    }
    
    if (success) {
        
        NSMutableArray * savedAlbums = [self savedAlbums].mutableCopy;
        [savedAlbums removeObject:album];
        success = [self saveAlbumsToDisk:savedAlbums.copy];
    }
    
    return success;
}

-(BOOL)deleteDiskDataOfPage:(DAPage *)page inAlbum:(DAAlbum *)album {
    
    NSString * pagePath = [self pathForAlbum:album andPage:page];
    BOOL success = YES;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:pagePath isDirectory:nil]) {
        success = [[NSFileManager defaultManager] removeItemAtPath:pagePath error:nil];
    }
    
    return success;
}

-(BOOL)deleteDiskDataOfImage:(DAImage *)image {
    
    BOOL success = YES;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:image.imagePath isDirectory:nil]) {
        success = [[NSFileManager defaultManager] removeItemAtPath:image.imagePath error:nil];
    }
    
    return success;
}


#pragma mark - Utilities

-(NSString *)pathForAlbum:(DAAlbum *)album {
    
    return [self.documentsDirectoryPath stringByAppendingPathComponent:album.name];
}

-(NSString *)pathForAlbum:(DAAlbum *)album andPage:(DAPage *)page {
    
    if (!page.name) {
        page.name = [NSString stringWithFormat:@"page-%f", [NSDate timeIntervalSinceReferenceDate]];
    }
    
    return [[self pathForAlbum:album] stringByAppendingPathComponent:page.name];
}

-(NSString *)pathForImage:(DAImage *)image inPage:(DAPage *)page inAlbum:(DAAlbum *)album {
    
    if (image.imagePath) {
        return image.imagePath;
    }
    
    NSString * albumPagePath = [self pathForAlbum:album andPage:page];
    NSString * imagePath = [albumPagePath stringByAppendingPathComponent:[NSString stringWithFormat:@"image-%f.jpg", [NSDate timeIntervalSinceReferenceDate]]];
    
    return imagePath;
}

-(BOOL)createFolderForAlbum:(DAAlbum *)album andPage:(DAPage *)page {
    
    NSString * albumPageSubPath = [self pathForAlbum:album andPage:page];
    NSFileManager * fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:albumPageSubPath isDirectory:nil]) {
        return [fileManager createDirectoryAtPath:albumPageSubPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    return YES;
}


@end
