//
//  SplashScreenStartView.swift
//  AwattarApp
//
//  Created by Léon Becker on 16.10.20.
//

import SwiftUI

struct SplashScreenStartViewTitle: View {
    var body: some View {
        VStack(spacing: 15) {
            Image("BigAppIcon")
                .resizable()
                .frame(width: 220, height: 220)
            
            VStack(spacing: 5) {
                Text("splashScreen.start.welcome")
                    .font(
                        .custom("SFCompactDisplay-Black",
                                size: 45,
                                relativeTo: .largeTitle)
                    )
                
                Text("AWattPrice")
                    .foregroundColor(Color(hue: 0.5648, saturation: 1.0000, brightness: 0.6235))
                    .font(
                        .custom("SFCompactDisplay-Black",
                                size: 50,
                                relativeTo: .largeTitle)
                    )
            }
        }
    }
}

/**
 Start of all splash screens. Presents and describes the main functionalities of the app briefly.
 */
struct SplashScreenStartView: View {
    @EnvironmentObject var currentSetting: CurrentSetting
    @State var redirectToNextSplashScreen: Int? = 0

    var body: some View {
        NavigationView {
            VStack {
                Spacer()

                SplashScreenStartViewTitle()

                Spacer()
                Spacer()

                NavigationLink("", destination: SplashScreenFeaturesAndConsentView(), tag: 1, selection: $redirectToNextSplashScreen)
                    .frame(width: 0, height: 0)
                    .hidden()

                NotAffiliatedView(showGrayedOut: false)
                    .padding(.bottom, 20)

                Button(action: {
                    redirectToNextSplashScreen = 1
                }) {
                    Text("general.continue")
                }
                .buttonStyle(ContinueButtonStyle())
            }
            .padding([.leading, .trailing], 20)
            .padding(.bottom, 16)
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct SplashScreenStartView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenStartView()
            .preferredColorScheme(.light)
    }
}
