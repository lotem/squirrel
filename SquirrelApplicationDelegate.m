#import "SquirrelApplicationDelegate.h"

#import <rime_api.h>
#import "SquirrelConfig.h"
#import "SquirrelPanel.h"

static NSString *const kRimeWikiURL = @"https://github.com/rime/home/wiki";

@implementation SquirrelApplicationDelegate

-(IBAction)deploy:(id)sender
{
  NSLog(@"Start maintenance...");
  [self shutdownRime];
  [self startRimeWithFullCheck:YES];
  [self loadSettings];
}

-(IBAction)syncUserData:(id)sender
{
  NSLog(@"Sync user data");
  rime_get_api()->sync_user_data();
}

-(IBAction)configure:(id)sender
{
  [[NSWorkspace sharedWorkspace] openFile:(@"~/Library/Rime").stringByStandardizingPath];
}

-(IBAction)openWiki:(id)sender
{
  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:kRimeWikiURL]];
}

void show_message(const char* msg_text, const char* msg_id) {
  @autoreleasepool {
    id notification = [[NSClassFromString(@"NSUserNotification") alloc] init];
    [notification performSelector:@selector(setTitle:)
                       withObject:NSLocalizedString(@"Squirrel", nil)];
    [notification performSelector:@selector(setSubtitle:)
                       withObject:NSLocalizedString(@(msg_text), nil)];
    id notificationCenter = [(id)NSClassFromString(@"NSUserNotificationCenter")
        performSelector:@selector(defaultUserNotificationCenter)];
    [notificationCenter performSelector:@selector(removeAllDeliveredNotifications)];
    [notificationCenter performSelector:@selector(deliverNotification:)
                             withObject:notification];
  }
}

static void show_status_message(const char* msg_text, const char* msg_id) {
  SquirrelPanel* panel = NSApp.squirrelAppDelegate.panel;
  if (panel) {
    NSString *message = NSLocalizedString(@(msg_text), nil);
    if ([[message substringToIndex:1]  isEqual: @"!"]) {
      message = [message substringFromIndex:1];
    }
    [panel updateStatus: message];
  }
}

void notification_handler(void* context_object, RimeSessionId session_id,
                          const char* message_type, const char* message_value) {
  if (!strcmp(message_type, "deploy")) {
    if (!strcmp(message_value, "start")) {
      show_message("deploy_start", message_type);
    }
    else if (!strcmp(message_value, "success")) {
      show_message("deploy_success", message_type);
    }
    else if (!strcmp(message_value, "failure")) {
      show_message("deploy_failure", message_type);
    }
    return;
  }
  // off?
  id app_delegate = (__bridge id)context_object;
  if (app_delegate && ![app_delegate enableNotifications]) {
    return;
  }
  // schema change
  if (!strcmp(message_type, "schema")) {
    const char* schema_name = strchr(message_value, '/');
    if (schema_name) {
      ++schema_name;
      show_status_message(schema_name, message_type);
    }
    return;
  }
  // option change
  if (!strcmp(message_type, "option")) {
    show_status_message(message_value, message_type);
  }
}

-(void)setupRime
{
  NSString* userDataDir = (@"~/Library/Rime").stringByStandardizingPath;
  NSFileManager* fileManager = [NSFileManager defaultManager];
  if (![fileManager fileExistsAtPath:userDataDir]) {
    if (![fileManager createDirectoryAtPath:userDataDir
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:NULL]) {
      NSLog(@"Error creating user data directory: %@", userDataDir);
    }
  }
  rime_get_api()->set_notification_handler(notification_handler, (__bridge void *)(self));
  RIME_STRUCT(RimeTraits, squirrel_traits);
  squirrel_traits.shared_data_dir = [NSBundle mainBundle].sharedSupportPath.UTF8String;
  squirrel_traits.user_data_dir = userDataDir.UTF8String;
  squirrel_traits.distribution_code_name = "Squirrel";
  squirrel_traits.distribution_name = "鼠鬚管";
  squirrel_traits.distribution_version =
      [[NSBundle mainBundle].infoDictionary[@"CFBundleVersion"] UTF8String];
  squirrel_traits.app_name = "rime.squirrel";
  rime_get_api()->setup(&squirrel_traits);
}

-(void)startRimeWithFullCheck:(BOOL)fullCheck
{
  NSLog(@"Initializing la rime...");
  rime_get_api()->initialize(NULL);
  // check for configuration updates
  if (rime_get_api()->start_maintenance((Bool)fullCheck)) {
    // update squirrel config
    rime_get_api()->deploy_config_file("squirrel.yaml", "config_version");
  }
}

- (void)shutdownRime {
  [_config close];
  rime_get_api()->finalize();
}

-(void)loadSettings {
  _config = [[SquirrelConfig alloc] init];
  if (![_config openBaseConfig]) {
    return;
  }

  _enableNotifications =
      ![[_config getString:@"show_notifications_when"] isEqualToString:@"never"];
  [self.panel loadConfig:_config forDarkMode:NO];
  if (@available(macOS 10.14, *)) {
    [self.panel loadConfig:_config forDarkMode:YES];
  }
}

-(void)loadSchemaSpecificSettings:(NSString *)schemaId {
  if (schemaId.length == 0 || [schemaId characterAtIndex:0] == '.') {
    return;
  }
  SquirrelConfig *schema = [[SquirrelConfig alloc] init];
  if ([schema openWithSchemaId:schemaId baseConfig:self.config] &&
      [schema hasSection:@"style"]) {
    [self.panel loadConfig:schema forDarkMode:NO];
  } else {
    [self.panel loadConfig:self.config forDarkMode:NO];
  }
  if (@available(macOS 10.14, *)) {
      if ([schema openWithSchemaId:schemaId baseConfig:self.config] &&
        [schema hasSection:@"style"]) {
      [self.panel loadConfig:schema forDarkMode:YES];
    } else {
      [self.panel loadConfig:self.config forDarkMode:YES];
    }
  }
  [schema close];
}

// prevent freezing the system
-(BOOL)problematicLaunchDetected
{
  BOOL detected = NO;
  NSString* logfile =
      [NSTemporaryDirectory() stringByAppendingPathComponent:@"squirrel_launch.dat"];
  //NSLog(@"[DEBUG] archive: %@", logfile);
  NSData* archive = [NSData dataWithContentsOfFile:logfile
                                           options:NSDataReadingUncached
                                             error:nil];
  if (archive) {
    NSDate* previousLaunch = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
    if (previousLaunch && previousLaunch.timeIntervalSinceNow >= -2) {
      detected = YES;
    }
  }
  NSDate* now = [NSDate date];
  NSData* record = [NSKeyedArchiver archivedDataWithRootObject:now];
  [record writeToFile:logfile atomically:NO];
  return detected;
}

-(void)workspaceWillPowerOff:(NSNotification *)aNotification
{
  NSLog(@"Finalizing before logging out.");
  [self shutdownRime];
}

-(void)rimeNeedsReload:(NSNotification *)aNotification
{
  NSLog(@"Reloading rime on demand.");
  [self deploy:nil];
}

-(NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
  NSLog(@"Squirrel is quitting.");
  rime_get_api()->cleanup_all_sessions();
  return NSTerminateNow;
}

//add an awakeFromNib item so that we can set the action method.  Note that
//any menuItems without an action will be disabled when displayed in the Text
//Input Menu.
-(void)awakeFromNib
{
  NSNotificationCenter* center = [NSWorkspace sharedWorkspace].notificationCenter;
  [center addObserver:self
             selector:@selector(workspaceWillPowerOff:)
                 name:NSWorkspaceWillPowerOffNotification
               object:nil];

  NSDistributedNotificationCenter* notifCenter = [NSDistributedNotificationCenter defaultCenter];
  [notifCenter addObserver:self
                  selector:@selector(rimeNeedsReload:)
                      name:@"SquirrelReloadNotification"
                    object:nil];

}

-(void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
  if (_panel) {
    [_panel hide];
  }
}

@end  //SquirrelApplicationDelegate

@implementation NSApplication (SquirrelApp)

-(SquirrelApplicationDelegate *)squirrelAppDelegate {
  return (SquirrelApplicationDelegate *)self.delegate;
}

@end

