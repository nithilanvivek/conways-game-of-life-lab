import SwiftUI

@main
struct ConwaysGameOfLifeLabApp: App {
    var body: some Scene {
        WindowGroup {
            LabWebView()
                .background(Color(red: 0.03, green: 0.035, blue: 0.055))
                .ignoresSafeArea()
        }
    }
}
