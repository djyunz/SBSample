//
//  HeartData.swift
//  SBSample
//
//  Created by Durk Jae Yun on 9/17/25.
//


import SwiftUI

class HeartData: ObservableObject {
    @Published var beatsPerMinute: Int
    
    init(beatsPerMinute: Int) {
        self.beatsPerMinute = beatsPerMinute
    }
}

struct HeartRateView: View {
    @ObservedObject var data: HeartData
    
    var body: some View {
        Text("\(data.beatsPerMinute) BPM")
    }
}

#Preview {
    HeartRateView(data: HeartData(beatsPerMinute: 70))
}
