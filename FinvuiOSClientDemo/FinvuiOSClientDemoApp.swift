import SwiftUI
import FinvuSDK

@main
struct FinvuiOSClientDemoApp: App {
    
    private class EventListener: NSObject, FinvuEventListener {
           func onEvent(_ event: FinvuEvent) {
               print("Event: \(event.eventName)")
               print("Category: \(event.eventCategory)")
               print("Params: \(event.params)")
               
               // Send to your analytics
           }
       }
       
       private let listener = EventListener()
       
       init() {
           FinvuManager.shared.addEventListener(listener)
           FinvuManager.shared.setEventsEnabled(true)
       }
       
    var body: some Scene {
        WindowGroup {
            LoginView()
        }
    }
}
