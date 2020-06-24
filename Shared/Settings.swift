//
//  Settings.swift
//  Space
//
//  Created by 46-1920 on 2020-06-24.
//

import SwiftUI

import SwiftUI
import WebKit

struct Settings: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("About")){
                    Text("Luna - View Space in AR")
                        .font(.headline)
                    Text("NOVA Productions")
                        .font(.subheadline)
                    Text("v1.0 (b13.3)")
                        .font(.footnote)
                }
                Section(header: Text("More")) {
                    VStack {
                        NavigationLink(destination: AboutMePage()) {
                            Text("About")
                                .font(.headline)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    VStack {
                        NavigationLink(destination: ContactMePage()) {
                            Text("Contact")
                                .font(.headline)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    VStack {
                        NavigationLink(destination: WebPagePrivacy()) {
                           Text("Privacy")
                                .font(.headline)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    VStack {
                        NavigationLink(destination: LegalPage()) {
                            Text("Legal")
                                .font(.headline)
                        }
                    }
                        .buttonStyle(PlainButtonStyle())
                }
            }
            .listStyle(SidebarListStyle())
            .navigationBarTitle(Text("Settings"))
        }
    }
}

struct AboutMePage: View {
    var body: some View {
        List {
            Section(header: Text("About me")){
                Text("Daniel is a student, he makes apps, videos, and he also does work on Blender. I started working on The School App on December 17, 2018. I started working on Blender on May 2, 2019. I uploaded my first video on May 14, 2016.")
            }
            
            Section {
                VStack {
                    NavigationLink(destination: HistoryWork()) {
                       Text("History of my Work")
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .listStyle(GroupedListStyle())
            .environment(\.horizontalSizeClass, .regular)
        .navigationBarTitle(Text("About"))
    }
}

struct HistoryWork: View {
    var body: some View {
        List {
           // Text("")
            Section(header: Text("NOVA Productions")) {
                Text("Started on August 7, 2019.")
                Text("Worked on this update for nearly 9 months.")
                Text("I made 1 video in 8 months.")
                Text("I merged RoboTeck and TNTChannels into NOVA Productions.")
                Text("All the TNTChannels were merged and started a channel called NOVA Productions.")
                Text("I started working tech projects yet to come out.")
                Text("I made NOVA Pro Classic")
                Text("I upload all my old video before this point on this channel")
                Text("I upload Biweekly on the NOVA Pro Classic channel.")
            }
            
            Section(header: Text("TNTChannels")) {
                Text("Phase 3 of TNTBOY99.")
                Text("Started on December 25, 2018.")
                Text("I worked on this update for a full month.")
                Text("I made this so I could have all my different channels connected.")
            }
            
            Section(header: Text("B.A.K. BROZ")) {
                Text("Started on September 5, 2018.")
                Text("The first video was uploaded on September 6, 2018.")
                Text("Me and my friends made this Youtube channel.")
                Text("We upload every couple of months.")
                Text("These videos takes weeks to create.")
            }
            
            Section(header: Text("TNTTech")) {
                Text("Started on August 1, 2018.")
                Text("Phase 2 of TNTBOY99.")
                Text("I uploaded all of my tech videos on this channel.")
                Text("I uploaded Gaming videos and vlogs on TNTBOY99.")
            }
            
            Section(header: Text("TNTBOY99")) {
                Text("On uploading on May 27, 2016.")
                Text("I converted my account so I could upload random videos I liked from TheProGamers.")
                Text("On Febuary 26 and 27, 2017.")
                Text("I uploaded my first vlogs becuase people in TheGaming5 didn't like my vlogs I made.")
                Text("On Febuary 8, 2018.")
                Text("Then I started uploading more vlogs on Febuary 8, 2018.")
            }

            Section(header: Text("TheGaming5")) {
                Text("Started on November 13, 2016.")
                Text("We stopped uploading on March 13, 2017.")
                Text("Then we uploaded 15 more videos in attempt to revive the channel.")
                Text("The last video uploaded on July 1, 2018.")
            }

            Section(header: Text("TheProGamers")) {
                Text("On May 14, 2016.")
                Text("I started uploading gaming YouTube videos on this channel.")
                Text("On May 27, 2016.")
                Text("We made a new channel to upload all the new videos.")
            }
            
            Section(header: Text("RoboTeck")) {
                Text("Started in 2012.")
                Text("I drew tech designs in school.")
                Text("Few projects came to life.")
                Text("In 2015 I had an idea for the Robo Band.")
                Text("In December of 2016 I created Robo Band for a science fair.")
                Text("It can unlock your computer by using a band onto a computer.")
                Text("You still needed to write your password in the code that makes the Robo Band work.")
                Text("I never showed it to the public.")
                Text("Other than my classmates.")
            }
        }
        .listStyle(GroupedListStyle())
            .environment(\.horizontalSizeClass, .regular)
        .navigationBarTitle(Text("History"))
    }
}

struct ContactMePage: View {
    var body: some View {
        List {
            Section(header: Text("Contact")){
                Text("You can email NOVA Productions anytime for any reason at: daniel@novapro.net.")
                Text("You can iMessage me at: daniel@novapro.net")
            }
            
            Section(header: Text("Social Media")) {
                Text("My Twitter is: @NOVAPro_")
                Text("My Instagram is: @novapro_official_")
                Text("My Facebook is: @novapro.official")
            }
        }
        .listStyle(GroupedListStyle())
            .environment(\.horizontalSizeClass, .regular)
        .navigationBarTitle(Text("Contact Me"))
    }
}


struct LegalPage: View {
    var body: some View {
        List {
            Section {
                Text("Email me for any reason at: apps@novapro.net")
                

            }
        }
        .listStyle(GroupedListStyle())
            .environment(\.horizontalSizeClass, .regular)
        .navigationBarTitle(Text("Contact Me"), displayMode: .inline)
    }
}


struct WebPagePrivacy: View {
    var body: some View {
        VStack {
            WebView(request: URLRequest(url: URL(string: "https://novapro.net/privacy/")!))
        }
        .navigationBarTitle(Text("Privacy"), displayMode: .inline)
    }
}

struct WebView: UIViewRepresentable {
    let request: URLRequest
    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }
    func updateUIView(_ uiView: WKWebView, context: UIViewRepresentableContext<WebView>) {
        uiView.load(request)
    }
}

