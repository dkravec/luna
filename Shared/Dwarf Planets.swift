//
//  Dwarf Planets.swift
//  LunaUni
//
//  Created by 46-1920 on 2020-06-24.
//

import SwiftUI

struct Pluto: View {
    var body: some View {
        List {
            VStack(alignment: .leading) {
                Text("Pluto")
                    .font(.headline)
                Text("Info")
            }
        }
        .listStyle(GroupedListStyle())
        .environment(\.horizontalSizeClass, .regular)
        .navigationBarTitle(Text("Pluto"))
    }
}

