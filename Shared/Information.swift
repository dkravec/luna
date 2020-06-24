//
//  Information.swift
//  Space
//
//  Created by 46-1920 on 2020-06-24.
//

import SwiftUI

struct Information: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Sun")){
                    NavigationLink(destination: The_Sun()) {
                        Text("The Sun")
                            .font(.headline)
                    }
                }
                Section(header: Text("Planets")){
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
                    NavigationLink(destination: The_Moon()) {
                        Text("The Moon")
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
                Section(header: Text("Dwarf Planets")){
                    NavigationLink(destination: Pluto()) {
                        Text("Pluto")
                            .font(.headline)
                    }
                
                }
            }
            .listStyle(SidebarListStyle())
            .navigationBarTitle(Text("Information"))
        }
    }
}
