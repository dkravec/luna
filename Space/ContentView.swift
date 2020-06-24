//
//  ContentView.swift
//  Space
//
//  Created by 46-1920 on 2020-06-21.
//  Copyright © 2020 Devray Boutique. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            ARView()
                .tabItem {
                    VStack {
                        Image(systemName: "hexagon")
                        .font(.system(size: 22))
                        Text("")
                    }
            }.tag(1)
            
            // 2
            Information()
                .tabItem {
                    VStack {
                        Image(systemName: "info.circle")
                        .font(.system(size: 22))
                        Text("")
                    }
            }.tag(2)
            
            // 3
            Settings()
                .tabItem {
                    VStack {
                        Image(systemName: "gear")
                        .font(.system(size: 22))
                        Text("")
                    }
            }.tag(3)
            // 4
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
