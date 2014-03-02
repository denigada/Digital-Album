//
//  AlbumViewController.m
//  Digital Album
//
//  Created by Ernesto Carrion on 2/17/14.
//  Copyright (c) 2014 Salarion. All rights reserved.
//

#import "AlbumViewController.h"
#import "AlbumPageViewController.h"
#import "GalleryViewController.h"

#import "AlbumManager.h"

@interface AlbumViewController () <UIPageViewControllerDataSource, UIPageViewControllerDelegate, AlbumPageDelegate> {
    
    __weak IBOutlet UIView *pageControlerHolder;
    BOOL inEditMode;
}

@property (nonatomic, strong) UIPageViewController * pageViewController;

@end

@implementation AlbumViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    [super viewDidLoad];
    
    self.title = self.album.name;
    
    self.pageViewController = [[UIPageViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStylePageCurl navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal options:nil];
    self.pageViewController.dataSource = self;
    self.pageViewController.view.frame = pageControlerHolder.frame;
    [self removePageTapGestureRecognizer];
    
    [self addChildViewController:self.pageViewController];
    [self.view addSubview:self.pageViewController.view];
    [self.pageViewController didMoveToParentViewController:self];
    [pageControlerHolder removeFromSuperview];
    pageControlerHolder = nil;
    
    NSArray * array = @[[self pageControllerAtIndex:0]];
    [self.pageViewController setViewControllers:array direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];
    
    [self setReadOnlyBarButtonItems];
}

-(void)viewWillAppear:(BOOL)animated {
    
    [super viewWillAppear:animated];
}

-(void)removePageTapGestureRecognizer {
    
    [self.pageViewController.gestureRecognizers enumerateObjectsUsingBlock:^(UIGestureRecognizer * recog, NSUInteger idx, BOOL *stop) {
        if ([recog isKindOfClass:[UITapGestureRecognizer class]]) {
            [(UITapGestureRecognizer *)recog setEnabled:NO];
        }
    }];
}

-(void)setEditionBarButtonItems {
    
    UIBarButtonItem * item = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(donePressed)];
    [self.navigationItem setRightBarButtonItem:item animated:YES];
    
    UIBarButtonItem * item2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelPressed)];
    [self.navigationItem setLeftBarButtonItem:item2 animated:YES];
    
    [self.navigationItem setHidesBackButton:YES animated:YES];
}

-(void)setReadOnlyBarButtonItems {
    
    [self.navigationItem setRightBarButtonItem:nil animated:YES];
    
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    [self.navigationItem setHidesBackButton:NO animated:YES];
}

-(void)saveCurrentPageOnCompletion:(void(^)(BOOL success))block {
    
    AlbumPageViewController * apvc = self.pageViewController.viewControllers[0];
    NSArray * imagesToDelete = [apvc commitChanges];
    
    //Delete Images
    for (DAImage * image in imagesToDelete) {
        [[AlbumManager manager] deleteDiskDataOfImage:image];
    }
    
    //Figure out if we need to show the spinner
    //Only show it if there are images to copy to disk
    BOOL haveSomethingToSave = NO;
    for (DAPage * page in self.album.pages) {
        for (DAImage * image in page.images) {
            if ([image hasSomethingToSave]) {
                haveSomethingToSave = YES;
                break;
            }
        }
        if (haveSomethingToSave) {
            break;
        }
    }
    
    if (haveSomethingToSave)
        [SVProgressHUD showWithStatus:@"Saving..." maskType:SVProgressHUDMaskTypeGradient];
    
    [[AlbumManager manager] saveAlbum:self.album onCompletion:^(BOOL success) {
        [SVProgressHUD dismiss];
        
#ifdef DEBUG
        if (success) {
            puts("Album save");
        } else {
            puts("Album not saved");
        }
#endif
        
        if (block) {
            block(success);
        }
        
    }];
}

-(void)donePressed {
    
    [self setReadOnlyBarButtonItems];
    inEditMode = NO;
    
    AlbumPageViewController * apvc = self.pageViewController.viewControllers[0];
    [apvc enableEditMode:inEditMode];
    
    [self saveCurrentPageOnCompletion:nil];
}

-(void)cancelPressed {
    
    [self setReadOnlyBarButtonItems];
    inEditMode = NO;
    
    AlbumPageViewController * apvc = self.pageViewController.viewControllers[0];
    [apvc enableEditMode:inEditMode];
    
    [UIView animateWithDuration:0.3 animations:^{
        [apvc disregardChanges];
    }];
}

-(void)editPressed {
    
    [self setEditionBarButtonItems];
    inEditMode = YES;
    
    AlbumPageViewController * apvc = self.pageViewController.viewControllers[0];
    [apvc enableEditMode:inEditMode];
}

#pragma mark - PageViewController

-(UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController {
    
    if (inEditMode)
        return nil;
    
    
    int currentIndex = [self currentIndex] + 1;
    if (currentIndex < self.album.pages.count) {
        
        return [self pageControllerAtIndex:currentIndex];
    }
    
    return nil;
}

-(UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController {
    
    if (inEditMode)
        return nil;
    
    int currentIndex = [self currentIndex] - 1;
    if (currentIndex >= 0) {
     
        return [self pageControllerAtIndex:currentIndex];
    }
    
    return nil;
}

-(int)currentIndex {
    
    AlbumPageViewController * pageController = (AlbumPageViewController *)self.pageViewController.viewControllers[0];
    DAPage * page = pageController.page;
    NSUInteger index = [self.album.pages indexOfObject:page];
    if (index == NSNotFound) {
        index = 0;
    }
    
    return  (int)index;
    
}

-(AlbumPageViewController *)pageControllerAtIndex:(int)index {
    
    if (self.album.pages.count == 0) {
        self.album.pages = @[[[DAPage alloc] init]];
    }
    
    AlbumPageViewController * page = [[AlbumPageViewController alloc] initWithPage:self.album.pages[index]];
    page.delegate = self;
    return page;
}

#pragma mark - AlbumPage delegate

-(void)pageController:(AlbumPageViewController *)page imageTapped:(DAImage *)image {
    
    UIView  * blackOverlay = [[UIView alloc] initWithFrame:self.view.window.bounds];
    blackOverlay.backgroundColor = [UIColor blackColor];
    blackOverlay.alpha = 0;
    [self.view.window addSubview:blackOverlay];
    
    UIImageView * imgvToZoom = [[UIImageView alloc] initWithImage:image.localImage];
    imgvToZoom.frame = CGRectMake(0, 0, 200, 200);
    imgvToZoom.contentMode = UIViewContentModeScaleAspectFit;
    imgvToZoom.transform = image.viewTransform;
    imgvToZoom.center = [self.view.window convertPoint:image.viewCenter fromView:page.canvas];
    [self.view.window addSubview:imgvToZoom];
    
    [UIView animateWithDuration:0.3 animations:^{
       
        blackOverlay.alpha = 1;
        imgvToZoom.transform = CGAffineTransformIdentity;
        imgvToZoom.frame = self.view.window.bounds;
        
    } completion:^(BOOL finished) {
        
        GalleryViewController * gvc = [[GalleryViewController alloc] init];
        gvc.album = self.album;
        gvc.startingIndex = [self.album.allImages indexOfObject:image];
        
        [self.navigationController setNavigationBarHidden:YES animated:NO];
        [self.navigationController pushViewController:gvc animated:NO];
        
        [UIView animateWithDuration:0.3 animations:^{
            
            blackOverlay.alpha = 0;
            
        } completion:^(BOOL finished) {
            
            [self.navigationController setNavigationBarHidden:NO animated:YES];
            [blackOverlay removeFromSuperview];
            [imgvToZoom removeFromSuperview];
        }];
        
    }];
}

-(void)didSelectCreateNewPage {
    
    [self saveCurrentPageOnCompletion:^(BOOL success) {
        
        int newPageIndex = [self currentIndex] + 1;
        DAPage * page = [[DAPage alloc] init];
        NSMutableArray * pages = [self.album.pages mutableCopy];
        
        if (pages.count > newPageIndex)
            [pages insertObject:page atIndex:newPageIndex];
        else
            [pages addObject:page];
        self.album.pages = pages.copy;
        
        NSArray * array = @[[self pageControllerAtIndex:newPageIndex]];
        [self.pageViewController setViewControllers:array direction:UIPageViewControllerNavigationDirectionForward animated:YES completion:nil];
        
        [self donePressed];
        
    }];
}

-(void)didSelectDeletePage {
    
    int index = [self currentIndex];
    
    NSMutableArray * pages = self.album.pages.mutableCopy;
    AlbumPageViewController * pageController = (AlbumPageViewController *)self.pageViewController.viewControllers[0];
    DAPage * page = pageController.page;
    [pages removeObject:page];
    self.album.pages = pages.mutableCopy;
    
    if (index >= (int)self.album.pages.count && index != 0) {
        index = (int)self.album.pages.count - 1;
    }
    
    NSArray * array = @[[self pageControllerAtIndex:index]];
    [self.pageViewController setViewControllers:array direction:UIPageViewControllerNavigationDirectionReverse animated:YES completion:nil];
    
    [[AlbumManager manager] deleteDiskDataOfPage:page inAlbum:self.album];
    [self donePressed];
}

-(void)WillEnterInEditMode {
    
    [self editPressed];
    
}

-(void)willLeaveEditMode {
    
    [self cancelPressed];
}

#pragma mark - Memory

- (void)didReceiveMemoryWarning {
    
    [super didReceiveMemoryWarning];
    
    if ([self isViewLoaded] && self.view.window == nil) {
        
        self.view = nil;
    }
    
    if (![self isViewLoaded]) {
        
        //Clean outlets here
    }
    
    //Clean rest of resources here eg:arrays, maps, dictionaries, etc
}

@end
