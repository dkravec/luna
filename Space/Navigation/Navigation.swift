//
//  Navigation.swift
//  School
//
//  Created by Daniel Kravec on 2020-08-02.
//

import SwiftUI

struct Navigation: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @ViewBuilder var body: some View {
        if horizontalSizeClass == .compact {
            AppTabNavigation()
        }else {
            AppSideBarNavigation()
                //.frame(minWidth: 900, maxWidth: .infinity, minHeight: 500, maxHeight: .infinity)
        }
    }
    #endif
    #if os(macOS)
    var body: some View {
        AppSideBarNavigation()
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: toggleSidebar, label: {
                    Image(systemName: "sidebar.left")
                })
            }
        }
    }
    #endif
}

#if os(macOS)
func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
}
#endif
