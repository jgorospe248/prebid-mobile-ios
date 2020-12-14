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
#import "PBVLineItemsSetupValidator.h"
#import "LineItemKeywordsManager.h"
#import "PBVSharedConstants.h"
#import "MPAdView.h"
#import "MPInterstitialAdController.h"
#import "MPInterstitialAdManager.h"
#import "MoPub.h"
#import "PBViewTool.h"
#import "AdServerValidationURLProtocol.h"
#import "NSURLSessionConfiguration+PBProtocols.h"

@import PrebidMobile;

@interface PBVLineItemsSetupValidator() <MPAdViewDelegate,
                                         MPInterstitialAdControllerDelegate,
                                         GADBannerViewDelegate,
                                         GADInterstitialDelegate,GADNativeCustomTemplateAdLoaderDelegate,DFPBannerAdLoaderDelegate,
                                        AdServerValidationURLProtocolDelegate,PrebidNativeAdDelegate>
@property id adObject;
@property NSString *requestUUID;
@property NSString *adServerResponseString;
@property NSString *adServerRequestString;
@property NSString *adServerRequestPostData;
@property NSDictionary *keywords;
@end

@implementation PBVLineItemsSetupValidator

- (instancetype)init
{
    self = [super init];
    [NSURLProtocol registerClass:[AdServerValidationURLProtocol class]];
    [AdServerValidationURLProtocol setDelegate:self];
    return self;
}

- (void)willInterceptRequest:(NSString *)requestString andPostData:(NSString *) data
{
    if ([requestString containsString:self.requestUUID] || [data containsString:self.requestUUID]) {
        self.adServerRequestString = requestString;
        self.adServerRequestPostData = data;
        BOOL containsKeyValues = YES;
        if ([requestString containsString:@"pubads.g.doubleclick.net/gampad/ads?"]) {
            for (NSString *key in self.keywords.allKeys) {
                NSString *keyValuePair = [NSString stringWithFormat:@"%@%@%@", key,@"%3D", [self.keywords objectForKey:key]];
                if (![requestString containsString:keyValuePair]) {
                    containsKeyValues = NO;
                }
            }
        } else {
            for (NSString *key in self.keywords.allKeys) {
                NSString *keyValuePair = [NSString stringWithFormat:@"%@:%@", key,[self.keywords objectForKey:key]];
                if (![data containsString:keyValuePair]) {
                    containsKeyValues = NO;
                }
            }
        }
        if (containsKeyValues) {
            [self.delegate didFindPrebidKeywordsOnTheAdServerRequest];
        } else {
            [self.delegate didNotFindPrebidKeywordsOnTheAdServerRequest];
        }
    }
}

- (void)didReceiveResponse:(NSString *)responseString forRequest:(NSString *)requestString
{
    if (self.requestUUID != nil && ([requestString containsString:self.requestUUID] || [self.adServerRequestPostData containsString:self.requestUUID])) {
        self.adServerResponseString = responseString;
    }
}

- (void)startTest
{
    NSString *adServerName = [[NSUserDefaults standardUserDefaults] stringForKey:kAdServerNameKey];
    NSString *adFormatName = [[NSUserDefaults standardUserDefaults] stringForKey:kAdFormatNameKey];
    NSString *adSizeString = [[NSUserDefaults standardUserDefaults] stringForKey:kAdSizeKey];
    NSString *adUnitID = [[NSUserDefaults standardUserDefaults] stringForKey:kAdUnitIdKey];
    NSString *bidPrice = [[NSUserDefaults standardUserDefaults] stringForKey:kBidPriceKey];
        
    GADAdSize GADAdSize = kGADAdSizeInvalid;
    CGSize adSize = CGSizeZero;
    if ([adSizeString isEqualToString:kSizeString320x50]) {
        GADAdSize = kGADAdSizeBanner;
        adSize = CGSizeMake(320, 50);
    } else if ([adSizeString isEqualToString:kSizeString300x250]) {
        GADAdSize = kGADAdSizeMediumRectangle;
        adSize = CGSizeMake(300, 250);
    } else if ([adSizeString isEqualToString:kSizeString320x480]) {
        adSize = CGSizeMake(320, 480);
        GADAdSize = GADAdSizeFromCGSize(adSize);
    } else if ([adSizeString isEqualToString:kSizeString300x600]) {
        adSize = CGSizeMake(300, 600);
        GADAdSize = GADAdSizeFromCGSize(adSize);
    } else if ([adSizeString isEqualToString:kSizeString320x100]) {
        adSize = CGSizeMake(320, 100);
        GADAdSize = kGADAdSizeLargeBanner;
    } else if ([adSizeString isEqualToString:kSizeString1x1]) {
        adSize = CGSizeMake(1, 1);
        GADAdSize = kGADAdSizeFluid;
    }
    if ([adServerName isEqualToString:kMoPubString]) {
        if ([adFormatName isEqualToString:kBannerString]) {
            self.keywords = [self createUniqueKeywordsWithBidPrice:bidPrice forSize:adSizeString];
            MPAdView *adView = [self createMPAdViewWithAdUnitId:adUnitID WithSize:adSize WithKeywords:self.keywords];
            [adView stopAutomaticallyRefreshingContents]; // forcing on the client side, server side management seems to be broken
            self.adObject = adView;
            [adView loadAd];
        } else if ([adFormatName isEqualToString:kInterstitialString]){
            self.keywords = [self createUniqueKeywordsWithBidPrice:bidPrice forSize:adSizeString];
            MPInterstitialAdController *interstitial = [self createMPInterstitialAdControllerWithAdUnitId:adUnitID WithKeywords:self.keywords];
            self.adObject = interstitial;
            [interstitial loadAd];
        } else if ([adFormatName isEqualToString:kBannerNativeString]){
            self.keywords = [self createUniqueKeywordsWithBidPrice:bidPrice forSize:adSizeString];
            MPInterstitialAdController *interstitial = [self createMPInterstitialAdControllerWithAdUnitId:adUnitID WithKeywords:self.keywords];
            self.adObject = interstitial;
            [interstitial loadAd];
        } else if ([adFormatName isEqualToString:kInAppNativeString]) {
            MPStaticNativeAdRendererSettings *settings = [[MPStaticNativeAdRendererSettings alloc] init];
            MPNativeAdRendererConfiguration *config = [MPStaticNativeAdRenderer rendererConfigurationWithRendererSettings:settings];
            MPNativeAdRequest *mpNative = [MPNativeAdRequest requestWithAdUnitIdentifier:adUnitID rendererConfigurations:@[config]];
            MPNativeAdRequestTargeting *targeting = [MPNativeAdRequestTargeting targeting];
            self.keywords = [self createUniqueKeywordsWithBidPrice:bidPrice forSize:adSizeString];
            NSString *keywordsString = [self formatMoPubKeywordStringFromDictionary:self.keywords];
            targeting.keywords = keywordsString;
            mpNative.targeting = targeting;
            [mpNative startWithCompletionHandler:^(MPNativeAdRequest *request, MPNativeAd *response, NSError *error) {
                if (error == nil) {
                    [self.delegate adServerRespondedWithPrebidCreative];
                }else{
                    [self.delegate adServerDidNotRespondWithPrebidCreative:error];
                }
            }];

        }
    } else if([adServerName isEqualToString:kDFPString]){
        if ([adFormatName isEqualToString:kBannerString] || [adFormatName isEqualToString:kBannerNativeString]) {
            DFPBannerView *adView = [self createDFPBannerViewWithAdUnitId:adUnitID WithSize:GADAdSize];
            // hack to attach to screen
            adView.frame = CGRectMake(-500, -500 , GADAdSize.size.width, GADAdSize.size.height);
            [((UIViewController *) _delegate).view addSubview:adView];
            self.adObject = adView;
            DFPRequest *request = [DFPRequest request];
            self.keywords = [self createUniqueKeywordsWithBidPrice:bidPrice forSize:adSizeString];
            request.customTargeting = self.keywords;
            [adView loadRequest:request];
        } else if ([adFormatName isEqualToString:kInterstitialString]){
            self.keywords = [self createUniqueKeywordsWithBidPrice:bidPrice forSize:adSizeString];
            DFPInterstitial *interstitial = [self createDFPInterstitialWithAdUnitId:adUnitID];
            self.adObject = interstitial;
            DFPRequest *request = [DFPRequest request];
            request.customTargeting = self.keywords;
            [interstitial loadRequest:request];
        } else if ([adFormatName isEqualToString:kInAppNativeString]){
            GADAdLoader *adLoader = [[GADAdLoader alloc] initWithAdUnitID:adUnitID rootViewController:(UIViewController *) self.delegate adTypes:@[kGADAdLoaderAdTypeDFPBanner, kGADAdLoaderAdTypeNativeCustomTemplate] options:@[]];
            adLoader.delegate = self;
            DFPRequest *request = [[DFPRequest alloc] init];
            self.keywords = [self createUniqueKeywordsWithBidPrice:bidPrice forSize:adSizeString];
            request.customTargeting = self.keywords;
            [adLoader loadRequest:request];
        }
    }
}
- (NSDictionary *) createUniqueKeywordsWithBidPrice:(NSString *)bidPrice forSize:(NSString *)adSizeString
{
    NSString *host = [[NSUserDefaults standardUserDefaults]stringForKey:kPBHostKey];
    NSMutableDictionary *keywords = [[[LineItemKeywordsManager sharedManager] keywordsWithBidPrice:bidPrice forSize:adSizeString forHost:host] mutableCopy];
    self.requestUUID = [[NSUUID UUID] UUIDString];
    [keywords setObject:self.requestUUID forKey:@"hb_dr_prebid"];
    return [keywords copy];
}

#pragma mark DFP
-(DFPInterstitial *) createDFPInterstitialWithAdUnitId:(NSString *)adUnitID
{
    DFPInterstitial *interstitial = [[DFPInterstitial alloc] initWithAdUnitID:adUnitID];
    interstitial.delegate = self;
    return interstitial;
}

- (DFPBannerView *)createDFPBannerViewWithAdUnitId:(NSString *) adUnitID WithSize:(GADAdSize)GADAdSize
{
    DFPBannerView *banner = [[DFPBannerView alloc] initWithAdSize:GADAdSize];
    banner.delegate = self;
    banner.rootViewController = (UIViewController *) self.delegate;
    banner.adUnitID = adUnitID;
    banner.autoloadEnabled = NO;
    return banner;
}

- (void)adViewDidReceiveAd:(GADBannerView *)bannerView
{
    if (self.adServerResponseString != nil && ([self.adServerResponseString containsString:@"pbm.js"] || [self.adServerResponseString containsString:@"creative.js"])) {
        [self.delegate adServerRespondedWithPrebidCreative];
    } else {
        [self.delegate adServerDidNotRespondWithPrebidCreative:nil];
    }
}

- (void)adView:(GADBannerView *)bannerView didFailToReceiveAdWithError:(GADRequestError *)error
{
    [self.delegate adServerDidNotRespondWithPrebidCreative:error];
}

- (void)interstitialDidReceiveAd:(GADInterstitial *)ad
{
    if (self.adServerResponseString != nil && ([self.adServerResponseString containsString:@"pbm.js"] || [self.adServerResponseString containsString:@"creative.js"])) {
         [self.delegate adServerRespondedWithPrebidCreative];
    } else {
        [self.delegate adServerDidNotRespondWithPrebidCreative:nil];
    }
}

- (void)interstitial:(GADInterstitial *)ad didFailToReceiveAdWithError:(GADRequestError *)error
{
    [self.delegate adServerDidNotRespondWithPrebidCreative:error];
}

#pragma mark :- DFP Native Delegate

- (void)adLoader:(nonnull GADAdLoader *)adLoader
didFailToReceiveAdWithError:(nonnull GADRequestError *)error{
    [self.delegate adServerDidNotRespondWithPrebidCreative:error];
}

- (nonnull NSArray<NSString *> *)nativeCustomTemplateIDsForAdLoader:(nonnull GADAdLoader *)adLoader{
    return @[@"11963183"];
}

- (void)adLoader:(nonnull GADAdLoader *)adLoader
didReceiveNativeCustomTemplateAd:(nonnull GADNativeCustomTemplateAd *)nativeCustomTemplateAd{
    [self.delegate adServerRespondedWithPrebidCreative];
}

- (nonnull NSArray<NSValue *> *)validBannerSizesForAdLoader:(nonnull GADAdLoader *)adLoader{
   return @[NSValueFromGADAdSize(kGADAdSizeBanner)];
}

#pragma mark MoPub
- (NSString *) formatMoPubKeywordStringFromDictionary:(NSDictionary *) keywordsDict
{
    NSString *keywordsString = @"";
    for (NSString *key in keywordsDict) {
        NSString *formatKey = [key stringByAppendingString:@":"];
        NSString *formatKeyword = [formatKey stringByAppendingString:keywordsDict[key]];
        keywordsString = [keywordsString stringByAppendingString:[formatKeyword stringByAppendingString:@","]];
    }
    return keywordsString;
}

- (MPAdView *) createMPAdViewWithAdUnitId: (NSString *) adUnitID WithSize: (CGSize)adSize WithKeywords:(NSDictionary *)keywordsDict
{
    NSString *keywordsString = [self formatMoPubKeywordStringFromDictionary:keywordsDict];
    MPAdView *adView = [[MPAdView alloc] initWithAdUnitId:adUnitID
                                                     size:adSize];
    adView.delegate = self;
    CGFloat x = ([UIScreen mainScreen].bounds.size.width - adSize.width) / 2.0;
    adView.frame = CGRectMake(x, kAdLocationY, adSize.width, adSize.height);
    [adView setKeywords:keywordsString];
    return adView;
}

- (MPInterstitialAdController *) createMPInterstitialAdControllerWithAdUnitId: (NSString *) adUnitID WithKeywords:(NSDictionary *) keywordsDict
{
    NSString *keywords = [self formatMoPubKeywordStringFromDictionary:keywordsDict];
    Class MPInterstitialClass = [MPInterstitialAdController class];
    SEL initMethodSel = NSSelectorFromString(@"initWithAdUnitId:");
    id interstitial = [MPInterstitialClass alloc];
    if ([interstitial respondsToSelector:initMethodSel]) {
        NSMethodSignature *methSig = [interstitial methodSignatureForSelector:initMethodSel];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methSig];
        [invocation setSelector:initMethodSel];
        [invocation setTarget:interstitial];
        [invocation setArgument:&adUnitID atIndex:2];
        [invocation invoke];
        [(MPInterstitialAdController *)interstitial setKeywords:keywords];
        [(MPInterstitialAdController *)interstitial setDelegate:self];
    }
    return interstitial;
}

- (void)interstitialDidLoadAd:(MPInterstitialAdController *)interstitial
{
 
    if (self.adServerResponseString != nil && ( [self.adServerResponseString containsString:@"pbm.js"] || [self.adServerResponseString containsString:@"creative.js"])) {
        [self.delegate adServerRespondedWithPrebidCreative];
    } else {
        [self.delegate adServerDidNotRespondWithPrebidCreative:nil];
    }
}

- (void)interstitialDidFailToLoadAd:(MPInterstitialAdController *)interstitial
{
    [self.delegate adServerDidNotRespondWithPrebidCreative:nil];
}

-(void)adViewDidLoadAd:(MPAdView *)view
{
    if (self.adServerResponseString != nil && ([self.adServerResponseString containsString:@"pbm.js"] || [self.adServerResponseString containsString:@"creative.js"])) {
        [self.delegate adServerRespondedWithPrebidCreative];
    } else {
        [self.delegate adServerDidNotRespondWithPrebidCreative:nil];
    }
}

- (void)adViewDidFailToLoadAd:(MPAdView *)view
{
    [self.delegate adServerDidNotRespondWithPrebidCreative:nil];
}

- (UIViewController *)viewControllerForPresentingModalView
{
    return (UIViewController *)self.delegate;
}

- (NSObject *) getDisplayable
{
    return self.adObject;
}

- (NSString *)getAdServerResponse
{
    return self.adServerResponseString;
}

- (NSString *)getAdServerRequest
{
    return self.adServerRequestString;
}

- (NSString *)getAdServerPostData
{
    return self.adServerRequestPostData;
}

@end

