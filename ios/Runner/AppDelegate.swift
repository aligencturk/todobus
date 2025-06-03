import Flutter
import UIKit
import Firebase
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Firebase'i başlat
    FirebaseApp.configure()
    
    // Bildirim için mesaj delegate'ini ayarla
    Messaging.messaging().delegate = self
    
    // iOS bildirim ayarları
    UNUserNotificationCenter.current().delegate = self
    
    // Bildirim izinlerini talep et
    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound, .provisional, .criticalAlert]
    UNUserNotificationCenter.current().requestAuthorization(
      options: authOptions,
      completionHandler: { granted, error in
        if granted {
          print("iOS bildirim izinleri verildi")
        } else {
          print("iOS bildirim izinleri reddedildi: \(String(describing: error))")
        }
      }
    )
    
    // Bildirim kayıt ayarları
    application.registerForRemoteNotifications()
    
    // APNs ayarları
    if #available(iOS 10.0, *) {
      // iOS 10 ve üzeri için
      UNUserNotificationCenter.current().delegate = self
      
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound, .provisional, .criticalAlert]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { _, _ in }
      )
    } else {
      // iOS 9 ve altı için (daha eski sürümler için)
      let settings: UIUserNotificationSettings =
        UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }
    
    // Foreground bildirimleri için ayar
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    
    // Flutter plugins kaydı
    GeneratedPluginRegistrant.register(with: self)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // APNs token'ı Firebase'e bağla
  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    print("APNs token alındı ve Firebase'e bağlanıyor")
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // APNs kayıt hatası durumunda
  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("APNs kayıt hatası: \(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
  
  // Arka plan bildirimleri için
  override func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    print("Arka plan bildirimi alındı: \(userInfo)")
    
    // Bildirimi FirebaseMessaging'e ilet
    Messaging.messaging().appDidReceiveMessage(userInfo)
    
    // Üst sınıfın metodunu çağır
    super.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
  }
}

// FCM Token yenileme davranışı için FirebaseMessagingDelegate
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("Firebase Token güncellendi: \(String(describing: fcmToken))")
    
    let dataDict: [String: String] = ["token": fcmToken ?? ""]
    NotificationCenter.default.post(
      name: Notification.Name("FCMToken"),
      object: nil,
      userInfo: dataDict
    )
  }
}

// Foreground bildirim davranışı için UNUserNotificationCenterDelegate
@available(iOS 10.0, *)
extension AppDelegate {
  override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    let userInfo = notification.request.content.userInfo
    print("Ön planda bildirim alındı: \(userInfo)")
    
    // Bildirimi FirebaseMessaging'e ilet
    Messaging.messaging().appDidReceiveMessage(userInfo)
    
    // iOS 14+ için tüm bildirim seçeneklerini göster
    if #available(iOS 14.0, *) {
      completionHandler([[.banner, .list, .sound, .badge]])
    } else {
      completionHandler([[.alert, .sound, .badge]])
    }
  }
  
  override func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo
    print("Bildirime tıklandı: \(userInfo)")
    
    // Bildirimi FirebaseMessaging'e ilet
    Messaging.messaging().appDidReceiveMessage(userInfo)
    
    completionHandler()
  }
}
