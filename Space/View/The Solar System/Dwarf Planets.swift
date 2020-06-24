//
//  Dwarf Planets.swift
//  Luna
//
//  Created by 46-1920 on 2020-06-21.
//  Copyright © 2020 Devray Boutique. All rights reserved.
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

