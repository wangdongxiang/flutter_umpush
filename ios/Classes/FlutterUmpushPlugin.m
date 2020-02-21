#import "FlutterUmpushPlugin.h"
#import <UserNotifications/UserNotifications.h>
#import <UMCommon/UMCommon.h>
#import <UMPush/UMessage.h>
#import <UMAnalytics/MobClick.h>
#import <UMCommonLog/UMCommonLogHeaders.h>

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0

@interface FlutterUmpushPlugin () <UNUserNotificationCenterDelegate>
@end

#endif

@implementation FlutterUmpushPlugin {
    FlutterMethodChannel *_channel;
    NSDictionary *_launchNotification;
    BOOL _resumingFromBackground;
}
+ (void)registerWithRegistrar:(NSObject <FlutterPluginRegistrar> *)registrar {
    NSLog(@"umeng_push_plugin registerWithRegistrar registrar: %@", registrar);
    FlutterMethodChannel *channel = [FlutterMethodChannel
            methodChannelWithName:@"flutter_umpush"
                  binaryMessenger:[registrar messenger]];
    FlutterUmpushPlugin *instance = [[FlutterUmpushPlugin alloc] initWithChannel:channel];
    [registrar addMethodCallDelegate:instance channel:channel];
    [registrar addApplicationDelegate:instance];
    NSLog(@"umeng_push_plugin register ok");
}

- (instancetype)initWithChannel:(FlutterMethodChannel *)channel {
    self = [super init];
    if (self) {
        _channel = channel;
        _resumingFromBackground = NO;
    }
    return self;
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    NSLog(@"umeng_push_plugin handleMethodCall call: %@", call);
    NSString *method = call.method;
    if ([@"configure" isEqualToString:method]) {
        [[UIApplication sharedApplication] registerForRemoteNotifications];
        result(nil);
    }else if([@"getToken" isEqualToString:method]) {
        NSString * token=[NSUserDefaults.standardUserDefaults valueForKey:@"DEVICETOKEN"];
        NSLog(@"umeng_push_plugin token: %@", token);
        result(token);
    }else if([@"getPushData" isEqualToString:method]) {
        NSString *data = [NSString stringWithFormat:@"%@", [NSUserDefaults.standardUserDefaults objectForKey:@"PUSHDATA"]];
        NSLog(@"umeng_push_plugin data: %@", data);
        [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"PUSHDATA"];
        result(data);
    }else {
        result(FlutterMethodNotImplemented);
    }
}

- (NSString *)convertToJsonData:(NSDictionary *)userInfo {
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:userInfo options:nil error:&error];
    NSString *jsonString;
    if (!jsonData) {
        NSLog(@"%@", error);
    } else {
        jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    return jsonString;
}

- (void)didReceiveRemoteNotification:(NSDictionary *)userInfo {
    NSLog(@"umeng_push_plugin didReceiveRemoteNotification userInfo: %@", userInfo);
    NSLog(@"umeng_push_plugin call onMessage: %@", _channel);
    [self saveData:userInfo];
}

- (BOOL) application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"umeng_push_plugin application didFinishLaunchingWithOptions %@", _launchNotification);
    NSDictionary * dict = [[NSBundle mainBundle] infoDictionary];
    NSString * appid = [dict objectForKey:@"UPUSH_Appkey"];
    NSString * channel = [dict objectForKey:@"UPUSH_Channel"];
    [UMCommonLogManager setUpUMCommonLogManager];
    [UMConfigure setLogEnabled:YES];

    [UMConfigure initWithAppkey:appid channel:channel];
    [MobClick event:@"flutter_ok"];
    NSLog(@"umeng_push_plugin application init umeng ok");
    UMessageRegisterEntity *entity = [[UMessageRegisterEntity alloc] init];
    //type是对推送的几个参数的选择，可以选择一个或者多个。默认是三个全部打开，即：声音，弹窗，角标
    entity.types = UMessageAuthorizationOptionBadge | UMessageAuthorizationOptionAlert;
    [UNUserNotificationCenter currentNotificationCenter].delegate = self;
    [UMessage registerForRemoteNotificationsWithLaunchOptions:launchOptions Entity:entity completionHandler:^(BOOL granted, NSError *_Nullable error) {
        if (granted) {
        } else {
        }
    }];
    [UMessage openDebugMode:YES];
    [UMessage addLaunchMessage];
    NSDictionary *dic = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    NSLog(@"umeng_push didFinishLaunchingWithOptions %@", dic);
    if (dic != nil) {
        [self saveData:dic];
    }
    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    _resumingFromBackground = YES;
    NSLog(@"umeng_push_plugin applicationDidEnterBackground");
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    _resumingFromBackground = NO;
    NSLog(@"umeng_push_plugin applicationDidBecomeActive");
    application.applicationIconBadgeNumber = 1;
    application.applicationIconBadgeNumber = 0;
}

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0

//iOS10新增：处理前台收到通知的代理方法
- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    NSLog(@"umeng_push_plugin userNotificationCenter willPresentNotification");
    NSDictionary *userInfo = notification.request.content.userInfo;
    if ([notification.request.trigger isKindOfClass:[UNPushNotificationTrigger class]]) {
        [UMessage setAutoAlert:NO];
        //应用处于前台时的远程推送接受
        //必须加这句代码
        [UMessage didReceiveRemoteNotification:userInfo];
        [self didReceiveRemoteNotification:userInfo];
    } else {
        //应用处于前台时的本地推送接受
    }
    completionHandler(UNNotificationPresentationOptionSound | UNNotificationPresentationOptionBadge | UNNotificationPresentationOptionAlert);
}

//iOS10新增：处理后台点击通知的代理方法
- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)())completionHandler {
    NSLog(@"umeng_push_plugin userNotificationCenter didReceiveNotificationResponse");
    NSDictionary *userInfo = response.notification.request.content.userInfo;
    if ([response.notification.request.trigger isKindOfClass:[UNPushNotificationTrigger class]]) {
        //应用处于后台时的远程推送接受
        //必须加这句代码
        [UMessage didReceiveRemoteNotification:userInfo];
        [self didReceiveRemoteNotification:userInfo];
    } else {
        //应用处于后台时的本地推送接受
    }
}

#endif

- (NSString *)stringDevicetoken:(NSData *)deviceToken {
    if (![deviceToken isKindOfClass:[NSData class]]) return @"";
    const unsigned *tokenBytes = (const unsigned *)[deviceToken bytes];
    NSString *pushToken = [NSString stringWithFormat:@"%08x%08x%08x%08x%08x%08x%08x%08x",
                          ntohl(tokenBytes[0]), ntohl(tokenBytes[1]), ntohl(tokenBytes[2]),
                          ntohl(tokenBytes[3]), ntohl(tokenBytes[4]), ntohl(tokenBytes[5]),
                          ntohl(tokenBytes[6]), ntohl(tokenBytes[7])];
    NSLog(@"deviceToken:%@",pushToken);
    return pushToken;
}
- (void)saveData:(NSDictionary *)userInfo {
    NSString *json = [self convertToJsonData:userInfo];
    NSLog(@"umeng_push json: %@", json);
    [[NSUserDefaults standardUserDefaults] setObject:json forKey:@"PUSHDATA"];
    [NSUserDefaults.standardUserDefaults synchronize];
}
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    [UMessage setAutoAlert:NO];
    [UMessage didReceiveRemoteNotification:userInfo];
    [self saveData:userInfo];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"userInfoNotification" object:self userInfo:@{@"userinfo": [NSString stringWithFormat:@"%@", userInfo]}];
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSLog(@"umeng_push_plugin application didRegisterForRemoteNotificationsWithDeviceToken%@", deviceToken);
    [NSUserDefaults.standardUserDefaults setValue:[self stringDevicetoken:deviceToken] forKey:@"DEVICETOKEN"];
    [NSUserDefaults.standardUserDefaults synchronize];
}
@end

