import UIKit
import Flutter
import GoogleMaps
import UserNotifications
import Firebase

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    FirebaseApp.configure()
    
    // Google Maps API Key
    GMSServices.provideAPIKey("AIzaSyCQy1lcXsx_E1cibmuTKs2XL3M7gEqLIdY")
    
    // Notification setup
    if #available(iOS 10.0, *) {
      let center = UNUserNotificationCenter.current()
      center.delegate = self  // No need to conform to `UNUserNotificationCenterDelegate` explicitly
      center.requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
        if let error = error {
          print("Error requesting notification permissions: \(error.localizedDescription)")
        } else {
          print("Notification permissions granted: \(granted)")
        }
      }
      application.registerForRemoteNotifications()
    } else {
      let settings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
      application.registerForRemoteNotifications()
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle notifications while in the foreground
  @available(iOS 10.0, *)
 override func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.alert, .badge, .sound])
  }
  
  // Handle notification interaction
  @available(iOS 10.0, *)
 override func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
    completionHandler()
  }
}
