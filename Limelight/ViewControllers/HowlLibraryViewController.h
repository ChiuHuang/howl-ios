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

/// Backend base URL (https://howl.chiuhuang.dev unless HowlBaseURL overrides it).
FOUNDATION_EXPORT NSString *HowlBackendBaseURL(void);

/// Logs into the Howl backend; the session cookie is kept in the shared cookie store.
FOUNDATION_EXPORT void HowlLoginWithPassword(NSString *password,
                                             void (^completion)(BOOL ok, NSInteger statusCode));

/// Asks the backend to approve a native Moonlight pairing with this 4-digit PIN.
FOUNDATION_EXPORT void HowlApprovePairingWithPin(NSString *pin,
                                                 void (^completion)(BOOL ok, NSInteger statusCode));

NS_ASSUME_NONNULL_END
