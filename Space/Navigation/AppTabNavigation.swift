//
//  AppTabNavigation.swift
//  School
//
//  Created by Daniel Kravec on 2020-08-02.
//

import SwiftUI

struct AppTabNavigation: View {
    
    var body: some View {
        ARView()
    }
}




/*
struct AppTabNavigation: View {
    
    @State var selected = 0
    
    var body: some View {
    
        ZStack(alignment: .bottom){
            
            VStack{
                
                if self.selected == 0{
                    GeometryReader { _ in
                        ARView()
                    }
                }
                else if self.selected == 1{
                    
                    GeometryReader{_ in
                        
                        Information()
                    }
                    
                }
                else{
                    
                    GeometryReader{_ in
                        
                        Settings()
                    }
                }
                
            }.background(Color("BackgroundColor").edgesIgnoringSafeArea(.all))
            
            FloatingTabBar(selected: self.$selected)
        }
    }
}

struct FloatingTabBar: View {
    
    @Binding var selected : Int
    @State var expand = false

    var body: some View {
        HStack {
            Spacer(minLength: /*@START_MENU_TOKEN@*/0/*@END_MENU_TOKEN@*/)
            HStack {
                if !self.expand {

                    Button(action: {
                        self.expand.toggle()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 22))
                            .foregroundColor( .blue).padding()
                    }
                }
                else {
//                    Spacer(minLength: /*@START_MENU_TOKEN@*/0/*@END_MENU_TOKEN@*/)
                    Button(action: {
                        self.selected = 0
                    }) {
                        Image(systemName: "hexagon")
                            .font(.system(size: 22))
                            .foregroundColor(self.selected == 0 ? .blue :  .gray)
                            .padding(.horizontal)
                    }
                    Spacer(minLength: 5)
//                        .frame(minWidth: 5, maxWidth: 15)
                    Button(action: {
                        self.selected = 1
                    }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 22))
                            .foregroundColor(self.selected == 1 ? .blue :  .gray)
                            .padding(.horizontal)
                    }
                    Spacer(minLength: 5)
 //                       .frame(minWidth: 5, maxWidth: 15)
                    Button(action: {
                        self.selected = 2
                    }) {
                        Image(systemName: "gear")
                            .font(.system(size: 22))
                            .foregroundColor(self.selected == 2 ? .blue :  .gray)
                            .padding(.horizontal)
                    }
                    Spacer(minLength: 5)
 //                       .frame(minWidth: 5, maxWidth: 15)
                    Button(action: {
                        self.expand.toggle()
                    }) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 22))
                            .foregroundColor(.gray).padding()
                    }
//                    Spacer(minLength: /*@START_MENU_TOKEN@*/0/*@END_MENU_TOKEN@*/)
                }
            }
            .padding(.vertical, self.expand ? 10 : 10)
            .padding(.horizontal, self.expand ? 10 : 8)
            .background(Color("TabColor"))
            .clipShape(Capsule())
            .padding(22)
            .onLongPressGesture {
                self.expand.toggle()
            }
            .animation(.interactiveSpring(response: 0.45, dampingFraction: 0.6, blendDuration: 0.6))
        }
    }
}


extension AppTabNavigation {
    enum Tab {
        case home
        case classes
        case schedule
        case timetable
        case homework
    }
}

struct AppTabNavigation_Previews: PreviewProvider {
    static var previews: some View {
        AppTabNavigation()
    }
}
*/
