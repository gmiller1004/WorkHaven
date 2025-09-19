//
//  ContentView.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        SpotListView(context: viewContext)
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
