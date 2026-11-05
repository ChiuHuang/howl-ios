//
//  HowlLibraryViewController.h
//  Howl
//
//  Game library backed by the Howl backend (/api/library/win), mirroring the
//  web client's tiles: same order, covers, blur and lock states.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class HowlLibraryViewController;

@protocol HowlLibraryViewControllerDelegate <NSObject>

/// The user picked a tile that is not blurred; launch the matching app.
- (void)howlLibrary:(HowlLibraryViewController *)controller
  didSelectAppTitle:(NSString *)title
             wolfId:(NSString *)wolfId;

@optional
- (void)howlLibraryDidRequestClose:(HowlLibraryViewController *)controller;

@end

@interface HowlLibraryViewController : UIViewController

@property (nonatomic, weak, nullable) id<HowlLibraryViewControllerDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
