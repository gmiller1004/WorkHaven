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
        TabView {
            SpotListView(context: viewContext)
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Spots")
                }
            
            SpotSearchView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
            
            MapView()
                .tabItem {
                    Image(systemName: "map")
                    Text("Map")
                }
            
            ImportView()
                .tabItem {
                    Image(systemName: "square.and.arrow.down")
                    Text("Import")
                }
        }
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
