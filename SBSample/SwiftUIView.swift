//
//  SwiftUIView.swift
//  SBSample
//
//  Created by Durk Jae Yun on 9/17/25.
//


import SwiftUI

struct SwiftUIView: View {
    var body: some View {
        HStack {
            Image(systemName: "smiley")
            Text("This is a Swift UI View")
        }
        .font(.title3)
        .padding()
    }
}

#Preview {
    SwiftUIView()
}
