#import "AudioTogglePlugin.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

NSString *const SpeakerSelectedNotification = @"speaker";
NSString *const AudioOptionsAvailable = @"audioOutputsAvailable";

@interface AudioTogglePlugin()
@property (nonatomic, strong) NSMutableDictionary *eventCallbacks;
@property (nonatomic, strong) MPVolumeView *volumeView;
@property (nonatomic) BOOL audioOutputsAvailable;
@end

@implementation AudioTogglePlugin

- (void) pluginInitialize {
	self.eventCallbacks = [NSMutableDictionary dictionaryWithCapacity:2];
	[self.eventCallbacks setValue:[NSMutableArray array] forKey:@"speaker"];
	[self.eventCallbacks setValue:[NSMutableArray array] forKey:@"audioOutputsAvailable"];

	self.audioOutputsAvailable = false;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAudioRouteChange:) name:AVAudioSessionRouteChangeNotification object:nil];
}


- (void) audioRoutingOptionsChangeDetector:(BOOL) newValue {
	if	(newValue != self.audioOutputsAvailable) {
		self.audioOutputsAvailable = newValue;
		
		for (id callbackId in self.eventCallbacks[@"audioOutputsAvailable"]) {
			CDVPluginResult* pluginResult = nil;
			pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:self.audioOutputsAvailable];
			[pluginResult setKeepCallbackAsBool:YES];
			[self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
		}
	}
}

- (BOOL) checkAudioRoutingOptions:(CDVInvokedUrlCommand *)command {
	NSArray<AVAudioSessionPortDescription *> *inputs = [AVAudioSession sharedInstance].availableInputs;
	
	BOOL hasOptions = inputs.count > 1;
	[self audioRoutingOptionsChangeDetector: hasOptions];
	
	CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:hasOptions];
	[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
	
	return hasOptions;
}

- (void)setAudioMode:(CDVInvokedUrlCommand *)command
{
	NSError* __autoreleasing err = nil;
	NSString* mode = [[NSString stringWithFormat:@"%@", [command.arguments objectAtIndex:0]] lowercaseString];

	AVAudioSession *session = [AVAudioSession sharedInstance];

	if ([mode isEqualToString:@"earpiece"]) {
		[session overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:&err];
	} else if ([mode isEqualToString:@"speaker"] || [mode isEqualToString:@"ringtone"]) {
		[session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&err];
	} else if ([mode isEqualToString:@"normal"]) {
		[session setCategory:AVAudioSessionCategorySoloAmbient error:&err];
	}
}

-(void) displayIOSAudioRoutingComponent:(CDVInvokedUrlCommand *)command {
	if (!self.volumeView) {
		self.volumeView = [MPVolumeView new];
		self.volumeView.showsRouteButton = YES;
		self.volumeView.showsVolumeSlider = NO;
		self.volumeView.hidden = true;
		UIViewController *rootController = [UIApplication sharedApplication].delegate.window.rootViewController;
		[rootController.view addSubview:self.volumeView];
	}
	for (UIButton *button in self.volumeView.subviews)
	{
		if ([button isKindOfClass:[UIButton class]])
		{
			[button sendActionsForControlEvents:UIControlEventTouchUpInside];
			return;
		}
	}
}

- (void) registerListener:(CDVInvokedUrlCommand *)command {
	NSString* eventName = command.arguments.firstObject;
	if(self.eventCallbacks[eventName] != nil) {
		[self.eventCallbacks[eventName] addObject:command.callbackId];
	}
}

- (void)handleAudioRouteChange:(NSNotification *) notification
{
	[self checkAudioRoutingOptions:nil];
	AVAudioSessionRouteChangeReason reasonValue = [notification.userInfo[@"AVAudioSessionRouteChangeReasonKey"] unsignedIntegerValue];

	AVAudioSessionRouteDescription* currentRoute = [AVAudioSession sharedInstance].currentRoute;
	AVAudioSessionPortDescription *output = currentRoute.outputs.firstObject;
	
	if([currentRoute.outputs count] > 0 && (reasonValue == AVAudioSessionRouteChangeReasonOverride || reasonValue == AVAudioSessionRouteChangeReasonCategoryChange)) {
		AVAudioSessionPortDescription *output = currentRoute.outputs.firstObject;
		
		for (id callbackId in self.eventCallbacks[@"speaker"]) {
			CDVPluginResult* pluginResult = nil;
			pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:[output.portType isEqual:AVAudioSessionPortBuiltInSpeaker]];
			[pluginResult setKeepCallbackAsBool:YES];
			[self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
		}
	}
}

@end
