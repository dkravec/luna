//
//  AppSideNavigation.swift
//  School
//
//  Created by Daniel Kravec on 2020-08-02.
//

import SwiftUI
struct AppSideBarNavigation: View {
    #if os(iOS)
    enum NavigationItem {
        case ar
        case settings
    }
    @State private var selection: Set<NavigationItem> = [.ar]
    
    var body: some View {
        
        NavigationView {
            List(selection: self.$selection) {
                NavigationLink(destination: ARView()){
                    Label("View in AR", systemImage: "hexagon")
                        .tag(NavigationItem.ar)
                }
                .font(.callout)
                NavigationLink(destination: Settings()){
                    Label("Settings", systemImage: "gear")
                        .tag(NavigationItem.settings)
                }
                .font(.callout)
                Section(header: Text("Sun")) {
                    NavigationLink(destination: The_Sun()) {
                        Text("The Sun")
                            .font(.headline)
                    }
                }
                Section(header: Text("Planets")) {
                    NavigationLink(destination: Mercury()) {
                        Text("Mercury")
                            .font(.headline)
                    }
                    NavigationLink(destination: Venus()) {
                        Text("Venus")
                            .font(.headline)
                    }
                    NavigationLink(destination: Earth()) {
                        Text("Earth")
                            .font(.headline)
                    }
                    NavigationLink(destination: Mars()) {
                        Text("Mars")
                            .font(.headline)
                    }
                    NavigationLink(destination: Jupiter()) {
                        Text("Jupiter")
                            .font(.headline)
                    }
                    NavigationLink(destination: Saturn()) {
                        Text("Saturn")
                            .font(.headline)
                    }
                    NavigationLink(destination: Uranus()) {
                        Text("Uranus")
                            .font(.headline)
                    }
                    NavigationLink(destination: Neptune()) {
                        Text("Neptune")
                            .font(.headline)
                    }
                    
                }
                Section(header: Text("Dwarf Planet")) {
                    NavigationLink(destination: Pluto()) {
                        Text("Pluto")
                            .font(.headline)
                    }
                }
            }
            .listStyle(SidebarListStyle())
            ARView()
        }

    }
    #endif
    #if os(macOS)
    enum NavigationItem {
        case main
        case ar
        case settings
    }
    @State private var selection: Set<NavigationItem> = [.settings]
    
    var body: some View {
        
        NavigationView {
            List(selection: self.$selection) {
                NavigationLink(destination: Settings()){
                    Label("Home", systemImage: "house")
                        .tag(NavigationItem.ar)
                }
                .font(.callout)
                NavigationLink(destination: Settings()){
                    Label("Settings", systemImage: "gear")
                        .tag(NavigationItem.settings)
                }
                .font(.callout)
                Section(header: Text("Sun")) {
                    NavigationLink(destination: The_Sun()) {
                        Text("The Sun")
                            .font(.headline)
                    }
                }
                Section(header: Text("Planets")) {
                    NavigationLink(destination: Mercury()) {
                        Text("Mercury")
                            .font(.headline)
                    }
                    NavigationLink(destination: Venus()) {
                        Text("Venus")
                            .font(.headline)
                    }
                    NavigationLink(destination: Earth()) {
                        Text("Earth")
                            .font(.headline)
                    }
                    NavigationLink(destination: Mars()) {
                        Text("Mars")
                            .font(.headline)
                    }
                    NavigationLink(destination: Jupiter()) {
                        Text("Jupiter")
                            .font(.headline)
                    }
                    NavigationLink(destination: Saturn()) {
                        Text("Saturn")
                            .font(.headline)
                    }
                    NavigationLink(destination: Uranus()) {
                        Text("Uranus")
                            .font(.headline)
                    }
                    NavigationLink(destination: Neptune()) {
                        Text("Neptune")
                            .font(.headline)
                    }
                    
                }
                Section(header: Text("Dwarf Planet")) {
                    NavigationLink(destination: Pluto()) {
                        Text("Pluto")
                            .font(.headline)
                    }
                }
            }
            .listStyle(SidebarListStyle())
            Settings()
        }

    }
    #endif

}

