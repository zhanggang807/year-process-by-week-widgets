import SwiftUI

@main
struct YearProgressApp: App {
    var body: some Scene {
        WindowGroup {
            YearProgressHomeView()
                // The host page is a light-on-light editorial preview; the
                // widget itself remains adaptive and fixed to its slate theme.
                .preferredColorScheme(.light)
        }
    }
}
