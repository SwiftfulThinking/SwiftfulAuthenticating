//
//  SwiftUIView.swift
//  SwiftfulAuthenticating
//
//  Created by Nick Sarno on 10/3/24.
//

import SwiftUI

#Preview("ButtonPreviews") {
    ScrollView {
        VStack(spacing: 24) {
            SignInAnonymousButtonView(type: .continue)
                .frame(height: 60)
            SignInAppleButtonView(type: .continue)
                .frame(height: 60)
            SignInGoogleButtonView(type: .continue)
                .frame(height: 60)
        }
        .padding(40)
    }
    .background(Color.gray.ignoresSafeArea())
}
