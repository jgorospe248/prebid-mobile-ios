/*
 *    Copyright 2018 Prebid.org, Inc.
 *
 *    Licensed under the Apache License, Version 2.0 (the "License");
 *    you may not use this file except in compliance with the License.
 *    You may obtain a copy of the License at
 *
 *        http://www.apache.org/licenses/LICENSE-2.0
 *
 *    Unless required by applicable law or agreed to in writing, software
 *    distributed under the License is distributed on an "AS IS" BASIS,
 *    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *    See the License for the specific language governing permissions and
 *    limitations under the License.
 */

#import <Foundation/Foundation.h>
#import "PBVPrebidSDKValidator.h"
#import "PBVSharedConstants.h"
#import "MPAdView.h"
#import "MPWebView.h"
#import <WebKit/WebKit.h>
#import "MPInterstitialAdController.h"
#import "MoPub.h"
#import "PBViewTool.h"
#import "SDKValidationURLProtocol.h"
#import "AppDelegate.h"

@import GoogleMobileAds;
@import PrebidMobile;

@interface PBVPrebidSDKValidator() <MPAdViewDelegate,MPInterstitialAdControllerDelegate,GADBannerViewDelegate,GADInterstitialDelegate,GADNativeCustomTemplateAdLoaderDelegate,DFPBannerAdLoaderDelegate,SDKValidationURLProtocolDelegate,PrebidNativeAdDelegate>
@property (nonatomic, readwrite) CLLocationManager *locationManager;
@property Boolean initialPrebidServerRequestReceived;
@property Boolean initialPrebidServerResponseReceived;
@property Boolean bidReceived;
@property NSString *adServerRequest;
@property NSString *adServerResponse;
@property NSString *adServerRequestPostData;
@property id adObject;
@property (nonatomic, strong) AdUnit *adUnit;
@property (nonatomic, strong) DFPBannerView *dfpView;
@property (nonatomic, strong) DFPInterstitial *dfpInterstitial;
@property (nonatomic, strong) DFPRequest *request;
@property (nonatomic, strong) GADAdLoader *adLoader;
@property (nonatomic, strong) MPAdView *mopubAdView;
@property (nonatomic, strong) MPInterstitialAdController *mopubInterstitial;
@property (nonatomic, strong) MPNativeAdRequest *mpNative;
@property (nonatomic, strong) MPNativeAd *mpAd;
@end

@implementation PBVPrebidSDKValidator

- (instancetype)initWithDelegate: (id<PBVPrebidSDKValidatorDelegate>) delegate
{
    self = [super init];
    if (self) {
        self.initialPrebidServerRequestReceived = NO;
        self.initialPrebidServerResponseReceived = NO;
        self.bidReceived = NO;
        [SDKValidationURLProtocol setDelegate:self];
        [NSURLProtocol registerClass:[SDKValidationURLProtocol class]];
        self.delegate = delegate;
        [self setupPrebidAndRegisterAdUnits];
    }
    return self;
}

#pragma mark - Prebid Mobile Setup

- (BOOL)setupPrebidAndRegisterAdUnits {
    @try {
        // Prebid Mobile setup!
        [self setPrebidTargetingParams];
        
        // Retriev settings from core data and create ad unit based on that
        NSString *adFormatName = [[NSUserDefaults standardUserDefaults] stringForKey:kAdFormatNameKey];
        NSString *adSizeString = [[NSUserDefaults standardUserDefaults] stringForKey:kAdSizeKey];
        NSString *configId = [[NSUserDefaults standardUserDefaults] stringForKey:kPBConfigKey];
        NSString *accountId = [[NSUserDefaults standardUserDefaults] stringForKey:kPBAccountKey];
        
        if([adFormatName isEqualToString:kBannerString]) {
            self.adUnit = [[BannerAdUnit alloc] initWithConfigId:configId size:CGSizeMake(320, 50)];
            // set size on adUnit
            NSMutableArray* array = [NSMutableArray new];
            if ([adSizeString isEqualToString: kSizeString320x50]) {
                [array addObject:[NSValue valueWithCGSize:CGSizeMake(320, 50)]];
                
            } else if ([adSizeString isEqualToString: kSizeString300x250]) {
                [array addObject:[NSValue valueWithCGSize:CGSizeMake(300, 250)]];
            } else if ([adSizeString isEqualToString:kSizeString320x480]){
                [array addObject:[NSValue valueWithCGSize:CGSizeMake(320, 480)]];
            } else if ([adSizeString isEqualToString:kSizeString320x100]){
                [array addObject:[NSValue valueWithCGSize:CGSizeMake(320, 100)]];
            } else if ([adSizeString isEqualToString:kSizeString300x600]){
                [array addObject:[NSValue valueWithCGSize:CGSizeMake(300, 600)]];
            } else {
                [array addObject:[NSValue valueWithCGSize:CGSizeMake(728, 90)]];
            }
            [( (BannerAdUnit *) self.adUnit) addAdditionalSizeWithSizes:array];
        } else if ([adFormatName isEqualToString:kInterstitialString]){
            self.adUnit = [[InterstitialAdUnit alloc] initWithConfigId:configId];
        } else if ([adFormatName isEqualToString:kBannerNativeString] || [adFormatName isEqualToString:kInAppNativeString]){
            //NativeRequest *request = ((AppDelegate*)[UIApplication sharedApplication].delegate).nativeRequest;
            NativeRequest *request = [self loadNativeAssetsWithConfigId:configId];
//            request.configId = configId;
            self.adUnit = request;
        } else {
            NSLog(@"Native and video not supported for now.");
            return NO;
        }
        //NSArray *adUnits = [NSArray arrayWithObjects:adUnit, nil];
        NSString *adServerName = [[NSUserDefaults standardUserDefaults] stringForKey:kAdServerNameKey];
        NSString *host = [[NSUserDefaults standardUserDefaults] stringForKey:kPBHostKey];
        Prebid.shared.prebidServerAccountId = accountId;
        if ([adServerName isEqualToString:kMoPubString]) {
                if ([host isEqualToString:kAppNexusString]) {
                    Prebid.shared.prebidServerHost = PrebidHostAppnexus;
                } else if ([host isEqualToString:kRubiconString]) {
                    Prebid.shared.prebidServerHost = PrebidHostRubicon;
                }
        } else if([adServerName isEqualToString:kDFPString]){
                if ([host isEqualToString:kAppNexusString]) {
                    Prebid.shared.prebidServerHost = PrebidHostAppnexus;
                } else if ([host isEqualToString:kRubiconString]) {
                    Prebid.shared.prebidServerHost = PrebidHostRubicon;
                }
        }
        [self.delegate adUnitRegistered];
    } @catch (NSException *ex) {//(PBException *ex) {
        NSLog(@"%@",[ex reason]);
    } @finally {
        return YES;
    }
}

-(NativeRequest *) loadNativeAssetsWithConfigId:(NSString *)configId{
    NativeAssetImage *image = [[NativeAssetImage alloc] initWithMinimumWidth:200 minimumHeight:200 required:true];
    image.type = ImageAsset.Main;
    
    NativeAssetImage *icon = [[NativeAssetImage alloc] initWithMinimumWidth:20 minimumHeight:20 required:true];
    icon.type = ImageAsset.Icon;
    
    NativeAssetTitle *title = [[NativeAssetTitle alloc] initWithLength:90 required:true];
    NativeAssetData *body = [[NativeAssetData alloc] initWithType:DataAssetDescription required:true];
    NativeAssetData *cta = [[NativeAssetData alloc] initWithType:DataAssetCtatext required:true];
    NativeAssetData *sponsored = [[NativeAssetData alloc] initWithType:DataAssetSponsored required:true];
    
    NativeRequest *nativeUnit = [[NativeRequest alloc] initWithConfigId:configId assets:@[icon,title,image,body,cta,sponsored]];
    nativeUnit.context = ContextType.Social;
    nativeUnit.placementType = PlacementType.FeedContent;
    nativeUnit.contextSubType = ContextSubType.Social;
    
    NativeEventTracker *eventTrackers = [[NativeEventTracker alloc] initWithEvent:EventType.Impression methods:@[EventTracking.Image, EventTracking.js]];
    nativeUnit.eventtrackers = @[eventTrackers];
    return  nativeUnit;;
    
}

- (void)setPrebidTargetingParams {
    Targeting.shared.gender = GenderFemale;
    Prebid.shared.shareGeoLocation = TRUE;
    
}

#pragma mark - PBVPrebidSDKValidator APIs
-(void)startTest
{
    // Retrieve Config
    NSString *adServerName = [[NSUserDefaults standardUserDefaults] stringForKey:kAdServerNameKey];
    NSString *adFormatName = [[NSUserDefaults standardUserDefaults] stringForKey:kAdFormatNameKey];
    NSString *adUnitID = [[NSUserDefaults standardUserDefaults] stringForKey:kAdUnitIdKey];
    NSString *adSizeString = [[NSUserDefaults standardUserDefaults] stringForKey:kAdSizeKey];
    // sanity check that whether PBM send the initial request or not
    if (self.initialPrebidServerRequestReceived) {
        [self.delegate requestToPrebidServerSent:NO];
        [self.delegate prebidServerResponseReceived:NO];
        [self.delegate bidReceivedAndCached:NO];
    }
    // Create ad unit
    if ([adServerName isEqualToString:kMoPubString]){
        if ([adFormatName isEqualToString:kBannerString]){
            NSArray *widthHeight = [adSizeString componentsSeparatedByString:@"x"];
            double width = [widthHeight[0] doubleValue];
            double height = [widthHeight[1] doubleValue];
            self.mopubAdView = [[MPAdView alloc] initWithAdUnitId:adUnitID
                                                         size:CGSizeMake(width, height)];
            [self.mopubAdView stopAutomaticallyRefreshingContents];
            self.mopubAdView.delegate = self;
            [self.adUnit fetchDemandWithAdObject:self.mopubAdView completion:^(enum ResultCode result) {
                [self.mopubAdView loadAd];
            }];
            
        } else if([adFormatName isEqualToString:kInterstitialString]){
            self.mopubInterstitial = [MPInterstitialAdController interstitialAdControllerForAdUnitId:adUnitID];
            self.mopubInterstitial.delegate = self;
            [self.adUnit fetchDemandWithAdObject:self.mopubInterstitial completion:^(enum ResultCode result) {
                [self.mopubInterstitial loadAd];
            }];
        }
        else if ([adFormatName isEqualToString:kInAppNativeString]) {
            MPStaticNativeAdRendererSettings *settings = [[MPStaticNativeAdRendererSettings alloc] init];
            MPNativeAdRendererConfiguration *config = [MPStaticNativeAdRenderer rendererConfigurationWithRendererSettings:settings];
            self.mpNative = [MPNativeAdRequest requestWithAdUnitIdentifier:adUnitID rendererConfigurations:@[config]];
            MPNativeAdRequestTargeting *targeting = [MPNativeAdRequestTargeting targeting];
            self.mpNative.targeting = targeting;
            __weak PBVPrebidSDKValidator *weakSelf = self;
            [self.adUnit fetchDemandWithAdObject:self.mpNative completion:^(enum ResultCode result) {
                PBVPrebidSDKValidator *strongSelf = weakSelf;
                [strongSelf.mpNative startWithCompletionHandler:^(MPNativeAdRequest *request, MPNativeAd *response, NSError *error) {
                    if (error == nil) {
                        self.mpAd = response;
                        Utils.shared.delegate = self;
                        [Utils.shared findNativeWithAdObject:self.mpAd];
                    }
                }];
            }];            
        }
            
    } else if ([adServerName isEqualToString:kDFPString]) {
        if ([adFormatName isEqualToString:kBannerString]) {
            NSArray *widthHeight = [adSizeString componentsSeparatedByString:@"x"];
            double width = [widthHeight[0] doubleValue];
            double height = [widthHeight[1] doubleValue];
            self.dfpView = [[DFPBannerView alloc] initWithAdSize:GADAdSizeFromCGSize(CGSizeMake(width, height))];
            self.dfpView.adUnitID = adUnitID;
            self.dfpView.delegate = self;
            self.dfpView.rootViewController = (UIViewController *)_delegate;
            
            self.request = [[DFPRequest alloc] init];
            GADMobileAds.sharedInstance.requestConfiguration.testDeviceIdentifiers = @[kDFPSimulatorID];
            [self.adUnit fetchDemandWithAdObject:self.request completion:^(enum ResultCode result) {
                [self.dfpView loadRequest:self.request];
            }];
            
        } else if([adFormatName isEqualToString:kInterstitialString]){
            self.dfpInterstitial = [[DFPInterstitial alloc] initWithAdUnitID:adUnitID];
            self.dfpInterstitial.delegate = self;
            self.request = [[DFPRequest alloc] init];
            GADMobileAds.sharedInstance.requestConfiguration.testDeviceIdentifiers = @[kDFPSimulatorID];
            [self.adUnit fetchDemandWithAdObject:self.request completion:^(enum ResultCode result) {
                [self.dfpInterstitial loadRequest:self.request];
            }];
        } else if ([adFormatName isEqualToString:kBannerNativeString]) {
            self.dfpView = [[DFPBannerView alloc] initWithAdSize:kGADAdSizeFluid];
            self.dfpView.adUnitID = adUnitID;
            self.dfpView.delegate = self;
            self.dfpView.rootViewController = (UIViewController *)_delegate;
            
            self.request = [[DFPRequest alloc] init];
            GADMobileAds.sharedInstance.requestConfiguration.testDeviceIdentifiers = @[kDFPSimulatorID];
            [self.adUnit fetchDemandWithAdObject:self.request completion:^(enum ResultCode result) {
                [self.dfpView loadRequest:self.request];
            }];
            
        } else if ([adFormatName isEqualToString:kInAppNativeString]) {
            self.request = [[DFPRequest alloc] init];
            GADMobileAds.sharedInstance.requestConfiguration.testDeviceIdentifiers = @[kDFPSimulatorID];
            __weak PBVPrebidSDKValidator *weakSelf = self;
            [self.adUnit fetchDemandWithAdObject:self.request completion:^(enum ResultCode result) {
                PBVPrebidSDKValidator *strongSelf = weakSelf;
                strongSelf.adLoader = [[GADAdLoader alloc] initWithAdUnitID:adUnitID rootViewController:(UIViewController *)strongSelf.delegate adTypes:@[kGADAdLoaderAdTypeDFPBanner, kGADAdLoaderAdTypeNativeCustomTemplate] options:@[]];
                strongSelf.adLoader.delegate = strongSelf;
                [strongSelf.adLoader loadRequest:strongSelf.request];
            }];
            
        }
    }
}

- (NSObject *)getAdObject
{
    return self.adObject;
}

- (NSString *)getAdServerRequest
{
    return self.adServerRequest;
}

- (NSString *)getAdServerResponse;
{
    return self.adServerResponse;
}

- (NSString *)getAdServerRequestPostData
{
    return self.adServerRequestPostData;
}
#pragma mark - DFP delegate
- (void)interstitial:(GADInterstitial *)ad didFailToReceiveAdWithError:(GADRequestError *)error
{
    [self.delegate adServerResponseContainsPBMCreative:NO];
}

- (void)interstitialDidReceiveAd:(GADInterstitial *)ad
{
    if ([self.adServerResponse containsString:@"pbm.js"]||[self.adServerResponse containsString:@"creative.js"]) {
        [self.delegate adServerResponseContainsPBMCreative:YES];
    } else {
        [self.delegate adServerResponseContainsPBMCreative:NO];
    }
}

- (void)adViewDidReceiveAd:(GADBannerView *)bannerView
{
    if ([self.adServerResponse containsString:@"pbm.js"]||[self.adServerResponse containsString:@"creative.js"]) {
        [self.delegate adServerResponseContainsPBMCreative:YES];
    } else {
        [self.delegate adServerResponseContainsPBMCreative:NO];
    }
}

- (void)adView:(GADBannerView *)bannerView didFailToReceiveAdWithError:(GADRequestError *)error
{
    [self.delegate adServerResponseContainsPBMCreative:NO];
}

#pragma mark :- DFP Native Delegate

- (void)adLoader:(nonnull GADAdLoader *)adLoader
didFailToReceiveAdWithError:(nonnull GADRequestError *)error{
    [self.delegate adServerResponseContainsPBMCreative:NO];
}

- (nonnull NSArray<NSString *> *)nativeCustomTemplateIDsForAdLoader:(nonnull GADAdLoader *)adLoader{
    return @[@"11963183"];
}

- (void)adLoader:(nonnull GADAdLoader *)adLoader
didReceiveNativeCustomTemplateAd:(nonnull GADNativeCustomTemplateAd *)nativeCustomTemplateAd{
    Utils.shared.delegate = self;
    [Utils.shared findNativeWithAdObject:nativeCustomTemplateAd];
}

- (nonnull NSArray<NSValue *> *)validBannerSizesForAdLoader:(nonnull GADAdLoader *)adLoader{
   return @[NSValueFromGADAdSize(kGADAdSizeBanner)];
}

#pragma mark :- PrebidNativeAdDelegate Delegate

- (void)prebidNativeAdLoadedWithAd:(PrebidNativeAd *)ad{
    self.adObject = ad;
    [self.delegate adServerResponseContainsPBMCreative:YES];
}
- (void)prebidNativeAdNotFound{
    [self.delegate adServerResponseContainsPBMCreative:NO];
}
- (void)prebidNativeAdNotValid{
    [self.delegate adServerResponseContainsPBMCreative:NO];
}

#pragma mark - MoPub delegate
- (void)interstitialDidLoadAd:(MPInterstitialAdController *)interstitial
{
    if ([self.adServerResponse containsString:@"pbm.js"] || [self.adServerResponse containsString:@"creative.js"]) {
        [self.delegate adServerResponseContainsPBMCreative:YES];
    } else {
        [self.delegate adServerResponseContainsPBMCreative:NO];
    }
}

- (void)interstitialDidFailToLoadAd:(MPInterstitialAdController *)interstitial
{
    [self.delegate adServerResponseContainsPBMCreative:NO];
}

- (UIViewController *)viewControllerForPresentingModalView
{
    return (UIViewController *)self.delegate; // this should work since we don't test click through here.
}

- (void)adViewDidLoadAd:(MPAdView *)view
{
    [PBViewTool checkMPAdViewContainsPBMAd:view withCompletionHandler:^(BOOL result) {
        if( result) {
            [self.delegate adServerResponseContainsPBMCreative:YES];
        } else
        {
            [self.delegate adServerResponseContainsPBMCreative:NO];
        }
    }];
}
- (void)adViewDidFailToLoadAd:(MPAdView *)view
{
    [self.delegate adServerResponseContainsPBMCreative:NO];
}

#pragma mark - SDKValidationURLProtocolDelegate
- (void)willInterceptPrebidServerRequest
{
    if (!self.initialPrebidServerRequestReceived) {
        self.initialPrebidServerRequestReceived = YES;
        [self.delegate requestToPrebidServerSent:YES];
    }
}

- (void)didReceivePrebidServerResponse:(NSString *)response
{
    if (!self.initialPrebidServerResponseReceived) {
        self.initialPrebidServerResponseReceived = YES;
        [self.delegate prebidServerResponseReceived:YES];
        if (response != nil) {
            NSError *error =nil;
            NSData *data = [response dataUsingEncoding:NSUTF8StringEncoding];
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error) {
                [self.delegate bidReceivedAndCached:NO];
            } else {
                Boolean containHbCacheId = NO;
                NSDictionary *response = (NSDictionary *)json;
                if ([[response objectForKey:@"seatbid"] isKindOfClass:[NSArray class]]) {
                    NSArray *seatbids = (NSArray *)[response objectForKey:@"seatbid"];
                    for (id seatbid in seatbids) {
                        if ([seatbid isKindOfClass:[NSDictionary class]]) {
                            NSDictionary *seatbidDict = (NSDictionary *)seatbid;
                            if ([[seatbidDict objectForKey:@"bid"] isKindOfClass:[NSArray class]]) {
                                NSArray *bids = (NSArray *)[seatbidDict objectForKey:@"bid"];
                                for (id bid in bids) {
                                    if ([bid isKindOfClass:[NSDictionary class]]) {
                                        NSDictionary *bidDict = (NSDictionary *)bid;
                                        if ([bidDict.allKeys containsObject:@"ext"]) {
                                            NSDictionary *ext = [bidDict objectForKey:@"ext"];
                                            if ([ext.allKeys containsObject:@"prebid"]) {
                                                NSDictionary *prebid = [ext objectForKey:@"prebid"];
                                                if ([prebid.allKeys containsObject:@"targeting"]) {
                                                    NSDictionary *targeting = [prebid objectForKey:@"targeting"];
                                                    for (NSString *key in targeting.allKeys) {
                                                        if ([key isEqualToString:@"hb_cache_id"]) {
                                                            containHbCacheId = YES;
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                if (containHbCacheId) {
                    [self.delegate bidReceivedAndCached:YES];
                } else {
                    [self.delegate bidReceivedAndCached:NO];
                }
            }
        } else {
            [self.delegate bidReceivedAndCached:NO];
        }
    }
}

- (void)willInterceptAdServerRequest:(NSString *)request withPostData:(NSString *)data
{
    self.adServerRequest = request;
    self.adServerRequestPostData = data;
    [self.delegate adServerRequestSent:request andPostData: data];
}

- (void)didReceiveAdServerResponse:(NSString *)response forRequest:(NSString *)request
{
    self.adServerResponse = response;
}
    
@end
