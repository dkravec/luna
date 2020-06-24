//
//  The_Sun.swift
//  Luna
//
//  Created by 46-1920 on 2020-06-21.
//  Copyright © 2020 Devray Boutique. All rights reserved.
//

import SwiftUI

struct The_Sun: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading) {
                    Text("Sun")
                        .font(.headline)
                    Text("Info")
                        .font(.subheadline)
                }
            }
        }
       // .listStyle(SidebarListStyle())
       // .listStyle(GroupedListStyle())
        .navigationBarTitle(Text("The Sun"))
    }
}
