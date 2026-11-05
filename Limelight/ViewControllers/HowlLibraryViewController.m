//
//  HowlLibraryViewController.m
//  Howl
//
//  Reads the Howl backend library so the app shows the same tiles as the web
//  client at howl.chiuhuang.dev. Streaming still goes through the native
//  Moonlight host; tiles only supply titles/covers/order and launch targets.
//

#import "HowlLibraryViewController.h"
#import "Logger.h"

static NSString * const kHowlLibraryCellIdentifier = @"HowlLibraryTile";
static NSString * const kHowlBaseURLDefaultsKey = @"HowlBaseURL";
static NSString * const kHowlDefaultBaseURL = @"https://howl.chiuhuang.dev";

static UIColor *HowlInk(void)
{
    return [UIColor colorWithRed:0.051 green:0.043 blue:0.031 alpha:1.0];
}

static UIColor *HowlAmber(void)
{
    return [UIColor colorWithRed:1.0 green:0.82 blue:0.36 alpha:1.0];
}

static NSString *HowlBaseURLString(void)
{
    NSString *override = [[NSUserDefaults standardUserDefaults] stringForKey:kHowlBaseURLDefaultsKey];
    override = [override stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (override.length > 0 && [override hasPrefix:@"http"]) {
        return [override hasSuffix:@"/"] ? [override substringToIndex:override.length - 1] : override;
    }
    return kHowlDefaultBaseURL;
}

/// Backend art URLs are either absolute, root-relative (/api/art/x.png) or a
/// Wolf config path such as /etc/wolf/cfg/art/123.png -> /api/art/123.png.
static NSString *HowlArtURLString(NSString *path, NSString *base)
{
    if (path.length == 0) {
        return nil;
    }
    if ([path hasPrefix:@"http://"] || [path hasPrefix:@"https://"]) {
        return path;
    }
    if ([path rangeOfString:@"cfg/art"].location != NSNotFound) {
        return [NSString stringWithFormat:@"%@/api/art/%@", base, path.lastPathComponent];
    }
    if ([path hasPrefix:@"/"]) {
        return [base stringByAppendingString:path];
    }
    return nil;
}

#pragma mark - Tile model

@interface HowlTile : NSObject
@property (nonatomic, copy) NSString *wolfId;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *coverURL;
@property (nonatomic) BOOL blur;
@property (nonatomic) BOOL needPassword;
@property (nonatomic) BOOL revealed;
@end

@implementation HowlTile
@end

#pragma mark - Tile cell

@interface HowlTileCell : UICollectionViewCell
@property (nonatomic, strong) UIImageView *coverView;
@property (nonatomic, strong) UIView *shadeView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *lockLabel;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) NSURLSessionDataTask *artTask;
@property (nonatomic, copy) NSString *artURL;
- (void)applyTile:(HowlTile *)tile;
@end

static NSCache *HowlArtCache(void)
{
    static NSCache *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 120;
    });
    return cache;
}

@implementation HowlTileCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.contentView.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
        self.contentView.layer.cornerRadius = 10.0;
        self.contentView.clipsToBounds = YES;

        _coverView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _coverView.translatesAutoresizingMaskIntoConstraints = NO;
        _coverView.contentMode = UIViewContentModeScaleAspectFill;
        _coverView.clipsToBounds = YES;
        _coverView.backgroundColor = [UIColor colorWithWhite:0.16 alpha:1.0];
        [self.contentView addSubview:_coverView];

        _shadeView = [[UIView alloc] initWithFrame:CGRectZero];
        _shadeView.translatesAutoresizingMaskIntoConstraints = NO;
        _shadeView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.62];
        [self.contentView addSubview:_shadeView];

        _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _nameLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
        _nameLabel.textColor = [UIColor whiteColor];
        _nameLabel.numberOfLines = 2;
        _nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [_shadeView addSubview:_nameLabel];

        _lockLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _lockLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _lockLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightBold];
        _lockLabel.text = @"🔒";
        _lockLabel.hidden = YES;
        [_shadeView addSubview:_lockLabel];

        UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
        blur.translatesAutoresizingMaskIntoConstraints = NO;
        blur.hidden = YES;
        blur.userInteractionEnabled = NO;
        [self.contentView addSubview:blur];
        _blurView = blur;

        [NSLayoutConstraint activateConstraints:@[
            [_coverView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [_coverView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [_coverView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [_coverView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

            [_blurView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [_blurView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [_blurView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [_blurView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],

            [_shadeView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [_shadeView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [_shadeView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
            [_shadeView.heightAnchor constraintEqualToConstant:38.0],

            [_nameLabel.leadingAnchor constraintEqualToAnchor:_shadeView.leadingAnchor constant:8.0],
            [_nameLabel.trailingAnchor constraintEqualToAnchor:_shadeView.trailingAnchor constant:-8.0],
            [_nameLabel.centerYAnchor constraintEqualToAnchor:_shadeView.centerYAnchor],

            [_lockLabel.centerYAnchor constraintEqualToAnchor:_shadeView.centerYAnchor],
            [_lockLabel.centerXAnchor constraintEqualToAnchor:_shadeView.centerXAnchor],
        ]];
    }
    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [self.artTask cancel];
    self.artTask = nil;
    self.artURL = nil;
    self.coverView.image = nil;
    self.nameLabel.text = nil;
    self.lockLabel.hidden = YES;
    self.blurView.hidden = YES;
}

- (void)applyTile:(HowlTile *)tile
{
    BOOL locked = tile.blur && tile.needPassword;
    BOOL blurred = tile.blur && !tile.revealed;

    self.nameLabel.text = locked ? @" " : tile.title;
    self.lockLabel.hidden = !locked;
    self.blurView.hidden = !blurred;

    [self.artTask cancel];
    self.artTask = nil;
    self.coverView.image = nil;
    self.artURL = tile.coverURL;

    if (tile.coverURL.length == 0) {
        return;
    }

    NSCache *artCache = HowlArtCache();
    UIImage *cached = [artCache objectForKey:tile.coverURL];
    if (cached != nil) {
        self.coverView.image = cached;
        return;
    }

    NSURL *url = [NSURL URLWithString:tile.coverURL];
    if (url == nil) {
        return;
    }

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url
                                                           completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error != nil || data.length == 0) {
            return;
        }
        UIImage *image = [UIImage imageWithData:data];
        if (image == nil) {
            return;
        }
        [artCache setObject:image forKey:tile.coverURL];
        dispatch_async(dispatch_get_main_queue(), ^{
            // The cell may have been reused for another tile by now.
            HowlTileCell *cell = self;
            if ([cell.artURL isEqualToString:tile.coverURL]) {
                cell.coverView.image = image;
            }
        });
    }];
    self.artTask = task;
    [task resume];
}

@end

#pragma mark - Library controller

@interface HowlLibraryViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) NSArray<HowlTile *> *tiles;
@property (nonatomic) BOOL loading;

- (NSArray<HowlTile *> *)tilesFromWolfApps:(NSArray *)apps baseURL:(NSString *)base;
- (NSNumber *)orderForTitle:(NSString *)title inApps:(NSArray *)apps;

@end

@implementation HowlLibraryViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = HowlInk();
    self.title = @"遊戲庫";
    self.edgesForExtendedLayout = UIRectEdgeAll;

    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    self.navigationController.navigationBar.tintColor = HowlAmber();
    self.navigationController.navigationBar.titleTextAttributes =
        @{ NSForegroundColorAttributeName : [UIColor whiteColor] };

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [closeButton setTitle:@"關閉" forState:UIControlStateNormal];
    [closeButton setTitleColor:HowlAmber() forState:UIControlStateNormal];
    [closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:closeButton];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumLineSpacing = 14.0;
    layout.minimumInteritemSpacing = 14.0;
    layout.sectionInset = UIEdgeInsetsMake(16.0, 16.0, 16.0, 16.0);

    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    self.collectionView.alwaysBounceVertical = YES;
    [self.collectionView registerClass:[HowlTileCell class] forCellWithReuseIdentifier:kHowlLibraryCellIdentifier];
    [self.view addSubview:self.collectionView];

    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.tintColor = HowlAmber();
    [self.refreshControl addTarget:self action:@selector(loadLibrary) forControlEvents:UIControlEventValueChanged];
    [self.collectionView addSubview:self.refreshControl];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    self.statusLabel.font = [UIFont systemFontOfSize:14.0];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 0;
    [self.view addSubview:self.statusLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.statusLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.statusLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:32.0],
        [self.statusLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-32.0],
    ]];

    [self loadLibrary];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (self.tiles.count == 0 && !self.loading) {
        [self loadLibrary];
    }
}

- (void)closeTapped
{
    if ([self.delegate respondsToSelector:@selector(howlLibraryDidRequestClose:)]) {
        [self.delegate howlLibraryDidRequestClose:self];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - Loading

- (void)setStatus:(NSString *)status
{
    self.statusLabel.text = status;
    self.statusLabel.hidden = (status.length == 0);
}

- (void)loadLibrary
{
    if (self.loading) {
        return;
    }
    self.loading = YES;
    if (self.tiles.count == 0) {
        [self setStatus:@"載入遊戲庫中…"];
    }

    NSString *base = HowlBaseURLString();
    NSURL *url = [NSURL URLWithString:[base stringByAppendingString:@"/api/library/win"]];
    if (url == nil) {
        self.loading = NO;
        [self.refreshControl endRefreshing];
        [self setStatus:@"遊戲庫網址無效"];
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:20.0];
    request.HTTPMethod = @"GET";

    Log(LOG_I, @"Howl library: GET %@", url);

    __weak typeof(self) weakSelf = self;
    [[[NSURLSession sharedSession] dataTaskWithRequest:request
                                    completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        typeof(self) self_ = weakSelf;
        if (self_ == nil) {
            return;
        }

        NSArray<HowlTile *> *tiles = nil;
        NSString *failure = nil;

        NSInteger statusCode = [response isKindOfClass:[NSHTTPURLResponse class]]
            ? ((NSHTTPURLResponse *)response).statusCode : 0;

        if (error != nil) {
            failure = @"無法連線到 Howl";
        } else if (data.length == 0 || statusCode >= 400) {
            failure = [NSString stringWithFormat:@"遊戲庫回應錯誤（%ld）", (long)statusCode];
        } else {
            NSError *jsonError = nil;
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            NSArray *apps = [json isKindOfClass:[NSDictionary class]] ? json[@"wolfApps"] : nil;
            if (![apps isKindOfClass:[NSArray class]]) {
                failure = @"遊戲庫格式無法辨識";
            } else {
                tiles = [self_ tilesFromWolfApps:apps baseURL:base];
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self_.loading = NO;
            [self_.refreshControl endRefreshing];
            if (tiles != nil) {
                self_.tiles = tiles;
                [self_.collectionView reloadData];
                [self_ setStatus:(tiles.count == 0 ? @"遊戲庫是空的" : @"")];
            } else {
                if (self_.tiles.count == 0) {
                    [self_ setStatus:failure ?: @"無法載入遊戲庫"];
                }
                Log(LOG_W, @"Howl library failed: %@", failure);
            }
        });
    }] resume];
}

- (NSArray<HowlTile *> *)tilesFromWolfApps:(NSArray *)apps baseURL:(NSString *)base
{
    NSMutableArray<HowlTile *> *tiles = [NSMutableArray array];

    for (id item in apps) {
        if (![item isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDictionary *app = item;
        NSString *title = app[@"title"];
        if (![title isKindOfClass:[NSString class]] || title.length == 0) {
            continue;
        }
        // Same exclusions as the web client's library grid.
        if ([title isEqualToString:@"Wolf-UI"] || [title isEqualToString:@"Wolf"] ||
            [title isEqualToString:@"Steam"]) {
            continue;
        }

        NSDictionary *config = [app[@"config"] isKindOfClass:[NSDictionary class]] ? app[@"config"] : @{};
        NSString *display = [config[@"pendingTitle"] isKindOfClass:[NSString class]]
            ? config[@"pendingTitle"] : title;

        NSString *icon = [config[@"icon"] isKindOfClass:[NSString class]]
            ? config[@"icon"] : app[@"icon_png_path"];
        NSString *cover = [icon isKindOfClass:[NSString class]] ? HowlArtURLString(icon, base) : nil;

        HowlTile *tile = [[HowlTile alloc] init];
        tile.wolfId = [app[@"id"] description] ?: @"";
        tile.title = display;
        tile.coverURL = cover;
        tile.blur = [config[@"blur"] boolValue];
        tile.needPassword = config[@"needPassword"] == nil ? YES : [config[@"needPassword"] boolValue];
        tile.revealed = NO;

        [tiles addObject:tile];
    }

    // Web order: Big Picture first, then the configured order, then name.
    [tiles sortUsingComparator:^NSComparisonResult(HowlTile *a, HowlTile *b) {
        NSNumber *oa = [self orderForTitle:a.title inApps:apps];
        NSNumber *ob = [self orderForTitle:b.title inApps:apps];
        if (oa != nil || ob != nil) {
            NSInteger ia = oa != nil ? oa.integerValue : NSIntegerMax;
            NSInteger ib = ob != nil ? ob.integerValue : NSIntegerMax;
            if (ia != ib) {
                return ia < ib ? NSOrderedAscending : NSOrderedDescending;
            }
        }
        return [a.title localizedCaseInsensitiveCompare:b.title];
    }];

    NSUInteger bigPicture = [tiles indexOfObjectPassingTest:^BOOL(HowlTile *tile, NSUInteger idx, BOOL *stop) {
        return [tile.title isEqualToString:@"Steam (Big Picture)"];
    }];
    if (bigPicture != NSNotFound && bigPicture > 0) {
        HowlTile *tile = tiles[bigPicture];
        [tiles removeObjectAtIndex:bigPicture];
        [tiles insertObject:tile atIndex:0];
    }

    return tiles;
}

- (NSNumber *)orderForTitle:(NSString *)title inApps:(NSArray *)apps
{
    for (id item in apps) {
        if (![item isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDictionary *app = item;
        NSDictionary *config = [app[@"config"] isKindOfClass:[NSDictionary class]] ? app[@"config"] : nil;
        NSString *name = [config[@"pendingTitle"] isKindOfClass:[NSString class]]
            ? config[@"pendingTitle"] : app[@"title"];
        if ([name isEqualToString:title] && [config[@"order"] isKindOfClass:[NSNumber class]]) {
            return config[@"order"];
        }
    }
    return nil;
}

#pragma mark - Collection view

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.tiles.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    HowlTileCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kHowlLibraryCellIdentifier
                                                                  forIndexPath:indexPath];
    [cell applyTile:self.tiles[indexPath.item]];
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                    layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat width = collectionView.bounds.size.width;
    CGFloat insets = 16.0 * 2.0;
    CGFloat spacing = 14.0;
    NSInteger columns = (width >= 700.0) ? 3 : 2;
    CGFloat itemWidth = floor((width - insets - spacing * (columns - 1)) / columns);
    return CGSizeMake(itemWidth, floor(itemWidth * 1.34) + 0.0);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    HowlTile *tile = self.tiles[indexPath.item];
    if (tile.blur && !tile.revealed) {
        tile.revealed = YES;
        [collectionView reloadItemsAtIndexPaths:@[ indexPath ]];
        return;
    }

    Log(LOG_I, @"Howl library selected: %@ (wolf id %@)", tile.title, tile.wolfId);
    [self.delegate howlLibrary:self didSelectAppTitle:tile.title wolfId:tile.wolfId];
}

@end
