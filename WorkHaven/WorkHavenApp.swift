//
//  WorkHavenApp.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//

import SwiftUI

@main
struct WorkHavenApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
