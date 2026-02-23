import Flutter
import UIKit
import flutter_local_notifications
import EventKit
import EventKitUI

@main
@objc class AppDelegate: FlutterAppDelegate, EKEventEditViewDelegate, FlutterImplicitEngineDelegate {

    // MARK: - Properties

    /// The method channel name for communication with Flutter
    private let channelName = "org.totem.calendar"

    /// EventKit store for calendar operations
    private let eventStore = EKEventStore()

    /// Callback to return results to Flutter
    private var flutterResultCallback: FlutterResult?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // This is required to make any communication available in the action isolate.
        FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
            GeneratedPluginRegistrant.register(with: registry)
        }

        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - FlutterImplicitEngineDelegate

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

        let methodChannel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: engineBridge.applicationRegistrar.messenger()
        )

        methodChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            guard let self = self else { return }

            switch call.method {
            case "addToCalendar":
                guard let args = call.arguments as? [String: Any] else {
                    result(FlutterError(code: "BAD_ARGS", message: "Missing args", details: nil))
                    return
                }
                self.flutterResultCallback = result
                self.handleAddToCalendar(args: args)

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // MARK: - Calendar Methods

    /// Handles adding an event to the device calendar
    /// - Parameter args: Dictionary containing event details from Flutter
    private func handleAddToCalendar(args: [String: Any]) {
        // Request access to Calendar if needed
        eventStore.requestAccess(to: .event) { [weak self] (granted: Bool, error: Error?) in
            guard let self = self else { return }

            DispatchQueue.main.async {
                if let error = error {
                    self.flutterResultCallback?(FlutterError(code: "PERM_ERR", message: error.localizedDescription, details: nil))
                    self.flutterResultCallback = nil
                    return
                }

                if !granted {
                    self.flutterResultCallback?(FlutterError(code: "NO_ACCESS", message: "Calendar access not granted", details: nil))
                    self.flutterResultCallback = nil
                    return
                }

                // Build event
                let title = (args["title"] as? String) ?? ""
                let desc = (args["description"] as? String) ?? ""
                let location = (args["location"] as? String) ?? ""
                let startMs = (args["start"] as? NSNumber)?.doubleValue ?? 0
                let endMs = (args["end"] as? NSNumber)?.doubleValue ?? 0
                let allDay = (args["allDay"] as? Bool) ?? false
                let reminderMinutesBefore = (args["reminderMinutesBefore"] as? NSNumber)?.intValue

                let startDate = Date(timeIntervalSince1970: startMs / 1000.0)
                let endDate   = Date(timeIntervalSince1970: endMs / 1000.0)

                let event = EKEvent(eventStore: self.eventStore)
                event.title = title
                event.notes = desc
                event.location = location
                event.startDate = startDate
                event.endDate = endDate
                event.isAllDay = allDay
                event.calendar = self.eventStore.defaultCalendarForNewEvents

                if let reminder = reminderMinutesBefore {
                    // reminder is minutes BEFORE start, so we use a relative alarm
                    let alarm = EKAlarm(relativeOffset: TimeInterval(-reminder * 60))
                    event.addAlarm(alarm)
                }

                // Present native edit UI
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
                    self.flutterResultCallback?(FlutterError(code: "NO_VC", message: "No view controller available", details: nil))
                    self.flutterResultCallback = nil
                    return
                }

                let editVC = EKEventEditViewController()
                editVC.event = event
                editVC.eventStore = self.eventStore
                editVC.editViewDelegate = self

                rootVC.present(editVC, animated: true, completion: nil)
            }
        }
    }

    // MARK: - EKEventEditViewDelegate

    /// Handles completion of the event edit view controller
    /// - Parameters:
    ///   - controller: The event edit view controller
    ///   - action: The action taken by the user (saved, canceled, deleted)
    func eventEditViewController(_ controller: EKEventEditViewController,
                                 didCompleteWith action: EKEventEditViewAction) {

        // action: .canceled / .saved / .deleted
        defer {
            controller.dismiss(animated: true, completion: nil)
        }

        guard let callback = flutterResultCallback else { return }
        flutterResultCallback = nil

        switch action {
        case .saved:
            callback(true)   // user tapped "Add"
        default:
            callback(false)  // user canceled or something else
        }
    }
}
