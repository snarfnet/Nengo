import SwiftUI
import GoogleMobileAds
import AppTrackingTransparency

@main
struct NengoApp: App {
    init() {
        MobileAds.shared.start(completionHandler: nil)
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        ATTrackingManager.requestTrackingAuthorization(completionHandler: { _ in })
                    }
                }
        }
    }
}
