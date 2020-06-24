//
//  Planets.swift
//  Luna
//
//  Created by 46-1920 on 2020-06-21.
//  Copyright © 2020 Devray Boutique. All rights reserved.
//

import SwiftUI

struct Mercury: View {
    var body: some View {
        List {
            VStack(alignment: .leading) {
                Text("Mercury:")
                    .font(.headline)
                Text("Info")
            }
        }
        .listStyle(GroupedListStyle())
        .environment(\.horizontalSizeClass, .regular)
        .navigationBarTitle(Text("Mercury"))
    }
}

struct Venus: View {
    var body: some View {
        List {
            VStack(alignment: .leading) {
                Text("Venus:")
                    .font(.headline)
                Text("Info")
            }
        }
        .listStyle(GroupedListStyle())
        .environment(\.horizontalSizeClass, .regular)
        .navigationBarTitle(Text("Venus"))
    }
}

struct Earth: View {
    var body: some View {
        List {
            VStack(alignment: .leading) {
                Text("Earth:")
                    .font(.headline)
                Text("Info")
            }
        }
        .listStyle(GroupedListStyle())
        .environment(\.horizontalSizeClass, .regular)
        .navigationBarTitle(Text("Earth"))
    }
}

struct The_Moon: View {
    var body: some View {
        List {
            VStack(alignment: .leading) {
                Text("The Moon")
                    .font(.headline)
                Text("Info")
            }
        }
        .listStyle(GroupedListStyle())
        .environment(\.horizontalSizeClass, .regular)
        .navigationBarTitle(Text("The Moon"))
    }
}

struct Mars: View {
    var body: some View {
        List {
            VStack(alignment: .leading) {
                Text("Mars")
                    .font(.headline)
                Text("Info")
            }
        }
        .listStyle(GroupedListStyle())
        .environment(\.horizontalSizeClass, .regular)
        .navigationBarTitle(Text("Mars"))
    }
}

struct Jupiter: View {
    var body: some View {
        List {
            VStack(alignment: .leading) {
                Text("Jupiter")
                    .font(.headline)
                Text("Info")
            }
        }
        .listStyle(GroupedListStyle())
        .environment(\.horizontalSizeClass, .regular)
        .navigationBarTitle(Text("Jupiter"))
    }
}

struct Saturn: View {
    var body: some View {
       List {
           VStack(alignment: .leading) {
               Text("Saturn")
                   .font(.headline)
               Text("Info")
           }
       }
       .listStyle(GroupedListStyle())
       .environment(\.horizontalSizeClass, .regular)
       .navigationBarTitle(Text("Saturn"))
    }
}

struct Uranus: View {
    var body: some View {
       List {
           VStack(alignment: .leading) {
               Text("Uranus")
                   .font(.headline)
               Text("Info")
           }
       }
       .listStyle(GroupedListStyle())
       .environment(\.horizontalSizeClass, .regular)
       .navigationBarTitle(Text("Uranus"))
    }
}

struct Neptune: View {
    var body: some View {
        List {
            VStack(alignment: .leading) {
                Text("Neptune")
                    .font(.headline)
                Text("Info")
            }
        }
        .listStyle(GroupedListStyle())
        .environment(\.horizontalSizeClass, .regular)
        .navigationBarTitle(Text("Neptune"))
    }
}
