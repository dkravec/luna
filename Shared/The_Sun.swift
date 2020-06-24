//
//  The_Sun.swift
//  Space
//
//  Created by 46-1920 on 2020-06-24.
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
        .listStyle(GroupedListStyle())
        .environment(\.horizontalSizeClass, .regular)
        .navigationBarTitle(Text("The Sun"))
    }
}
