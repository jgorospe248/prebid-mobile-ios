/*   Copyright 2019-2022 Prebid.org, Inc.
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "GAMOriginalAPINativeViewController.h"
#import "PrebidDemoMacros.h"

NSString * const nativeStoredImpression = @"imp-prebid-banner-native-styles";
NSString * const gamNativeAdUnitId = @"/21808260008/apollo_custom_template_native_ad_unit";

@interface GAMOriginalAPINativeViewController ()

// Prebid
@property (nonatomic) NativeRequest * nativeUnit;
@property (nonatomic) PBMNativeAd * nativeAd;

// GAM
@property (nonatomic) GADAdLoader * adLoader;

@end

@implementation GAMOriginalAPINativeViewController

- (void)loadView {
    [super loadView];
    
    [self createAd];
}

- (void)createAd {
    // 1. Setup a NativeRequest
    PBMNativeAssetImage *image = [[PBMNativeAssetImage alloc] initWithMinimumWidth:200 minimumHeight:200 required:true];
    image.type = PBMImageAsset.Main;
    
    PBMNativeAssetImage *icon = [[PBMNativeAssetImage alloc] initWithMinimumWidth:20 minimumHeight:20 required:true];
    icon.type = PBMImageAsset.Icon;
    
    PBMNativeAssetTitle *title = [[PBMNativeAssetTitle alloc] initWithLength:90 required:true];
    PBMNativeAssetData *body = [[PBMNativeAssetData alloc] initWithType:PBMDataAssetDescription required:true];
    PBMNativeAssetData *cta = [[PBMNativeAssetData alloc] initWithType:PBMDataAssetCtatext required:true];
    PBMNativeAssetData *sponsored = [[PBMNativeAssetData alloc] initWithType:PBMDataAssetSponsored required:true];
    
    PBMNativeEventTracker * eventTracker = [[PBMNativeEventTracker alloc] initWithEvent:PBMEventType.Impression
                                                                          methods:@[PBMEventTracking.Image, PBMEventTracking.js]];
    
    self.nativeUnit = [[NativeRequest alloc] initWithConfigId:nativeStoredImpression
                                                       assets:@[title, icon, image, sponsored, body, cta]
                                                eventTrackers:@[eventTracker]];
    
    // 2. Configure the NativeRequest
    self.nativeUnit.context = ContextType.Social;
    self.nativeUnit.placementType = PlacementType.FeedContent;
    self.nativeUnit.contextSubType = ContextSubType.Social;
    
    // 3. Make a bid request
    GAMRequest * gamRequest = [GAMRequest new];
    @weakify(self);
    [self.nativeUnit fetchDemandWithAdObject:gamRequest completion:^(enum PBMResultCode resultCode) {
        @strongify(self);
        if (!self) { return; }
        
        //4. Configure and make a GAM ad request
        self.adLoader = [[GADAdLoader alloc] initWithAdUnitID:gamNativeAdUnitId
                                           rootViewController:self
                                                      adTypes:@[GADAdLoaderAdTypeCustomNative] options:@[]];
        self.adLoader.delegate = self;
        [self.adLoader loadRequest:gamRequest];
    }];
}

// MARK: GADCustomNativeAdLoaderDelegate

- (NSArray<NSString *> *)customNativeAdFormatIDsForAdLoader:(GADAdLoader *)adLoader {
    return @[@"11934135"];
}

- (void)adLoader:(GADAdLoader *)adLoader didReceiveCustomNativeAd:(GADCustomNativeAd *)customNativeAd {
    PBMUtils.shared.delegate = self;
    [PBMUtils.shared findNativeWithAdObject:customNativeAd];
}

// MARK: GADAdLoaderDelegate

- (void)adLoader:(GADAdLoader *)adLoader didFailToReceiveAdWithError:(NSError *)error {
    PBMLogError(@"%@", error.localizedDescription)
}

// MARK: - NativeAdDelegate

- (void)nativeAdLoadedWithAd:(PBMNativeAd *)ad {
    self.nativeAd = ad;
    self.titleLable.text = ad.title;
    self.bodyLabel.text = ad.text;
    [self.callToActionButton setTitle:ad.callToAction forState:UIControlStateNormal];
    self.sponsoredLabel.text = ad.sponsoredBy;
    
    [[NSURLSession.sharedSession dataTaskWithURL:[NSURL URLWithString:self.nativeAd.iconUrl] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.iconView.image = [[UIImage alloc] initWithData:data];
        });
    }] resume];
    
    [[NSURLSession.sharedSession dataTaskWithURL:[NSURL URLWithString:self.nativeAd.imageUrl] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.mainImageView.image = [[UIImage alloc] initWithData:data];
        });
    }] resume];
    
    [self.nativeAd registerViewWithView:self.view clickableViews:@[self.callToActionButton]];
}

- (void)nativeAdNotFound {
    PBMLogError(@"Native ad not found.");
}

- (void)nativeAdNotValid {
    PBMLogError(@"Native ad not valid.");
}

@end