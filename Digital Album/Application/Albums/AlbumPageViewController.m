//
//  AlbumPageViewController.m
//  Digital Album
//
//  Created by Ernesto Carrion on 2/17/14.
//  Copyright (c) 2014 Salarion. All rights reserved.
//

#import "AlbumPageViewController.h"
#import "UIImageView+AspectSize.h"

@interface AlbumPageViewController () <UIGestureRecognizerDelegate> {
    
    double lastScale;
    double lastRotation;
    double firstX;
    double firstY;
}

@end

@implementation AlbumPageViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

-(id)initWithImage:(DAImage *)image {
    
    self = [super init];
    if (self) {
        
        self.image = image;
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.imageView.image = [self.image localImage];
    
    CGPoint center = self.imageView.center;
    self.imageView.frame = [self.imageView contentModetRect];
    self.imageView.center = center;
    self.imageView.layer.allowsEdgeAntialiasing = YES;
    
    self.imageView.layer.borderWidth = 3;
    [self enableEditMode:NO];
}

-(void)enableEditMode:(BOOL)edit {
    
    if (edit) {
        
        [self setUpEditionImageGestureRecognizers];
        
    } else {
        
        [self setUpReadOnlyGesturesRecognizers];
        
    }
    
    UIColor * color = edit ? [UIColor colorWithPatternImage:[UIImage imageNamed:@"wood-texture-2.png"]] : [UIColor clearColor];
    self.imageView.layer.borderColor = color.CGColor;
    
}

#pragma mark - Gestures Recognizers

-(void)removeGesturesRecognizers {
    
    for (UIGestureRecognizer * gr in self.view.gestureRecognizers) {
        [self.view removeGestureRecognizer:gr];
    }
    
    for (UIGestureRecognizer * gr in self.imageView.gestureRecognizers) {
        [self.imageView removeGestureRecognizer:gr];
    }
}

-(void)setUpReadOnlyGesturesRecognizers {
    
    [self removeGesturesRecognizers];
    
    UITapGestureRecognizer * tapGestureRecornizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(imageTapped:)];
    tapGestureRecornizer.numberOfTapsRequired = 1;
    [self.view addGestureRecognizer:tapGestureRecornizer];
}

-(void)setUpEditionImageGestureRecognizers {
    
    [self removeGesturesRecognizers];
    
    UIPinchGestureRecognizer *pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(scale:)];
	[pinchRecognizer setDelegate:self];
	[self.view addGestureRecognizer:pinchRecognizer];
    
	UIRotationGestureRecognizer *rotationRecognizer = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(rotate:)];
	[rotationRecognizer setDelegate:self];
	[self.view addGestureRecognizer:rotationRecognizer];
    
	UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(move:)];
	[panRecognizer setMinimumNumberOfTouches:1];
	[panRecognizer setMaximumNumberOfTouches:1];
	[panRecognizer setDelegate:self];
	[self.imageView addGestureRecognizer:panRecognizer];
}

-(void)imageTapped:(UITapGestureRecognizer *)gestureRecognizer {
    
    if ([self.delegate respondsToSelector:@selector(pageController:imageTapped:)]) {
        
        [self.delegate pageController:self imageTapped:self.image];
    }
}

-(void)scale:(UIPinchGestureRecognizer *)gestureRecognizer {
    
    if([gestureRecognizer state] == UIGestureRecognizerStateBegan) {
        lastScale = 1.0;
    }
    
    CGFloat scale = 1.0 - (lastScale - [gestureRecognizer scale]);
    
    CGAffineTransform currentTransform = self.imageView.transform;
    CGAffineTransform newTransform = CGAffineTransformScale(currentTransform, scale, scale);
    
    [self.imageView setTransform:newTransform];
    
    lastScale = [gestureRecognizer scale];
}

-(void)rotate:(UIRotationGestureRecognizer *)gestureRecognizer {
    
    if([gestureRecognizer state] == UIGestureRecognizerStateEnded) {
        
        lastRotation = 0.0;
        return;
    }
    
    CGFloat rotation = 0.0 - (lastRotation - [gestureRecognizer rotation]);
    
    CGAffineTransform currentTransform = self.imageView.transform;
    CGAffineTransform newTransform = CGAffineTransformRotate(currentTransform,rotation);
    
    [self.imageView setTransform:newTransform];
    lastRotation = [gestureRecognizer rotation];
}

-(void)move:(UIPanGestureRecognizer *)gestureRecognizer {
    
    CGPoint translatedPoint = [gestureRecognizer translationInView:self.view];
    
    if([gestureRecognizer state] == UIGestureRecognizerStateBegan) {
        firstX = [self.imageView center].x;
        firstY = [self.imageView center].y;
    }
    
    translatedPoint = CGPointMake(firstX + translatedPoint.x, firstY + translatedPoint.y);
    [self.imageView setCenter:translatedPoint];
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
