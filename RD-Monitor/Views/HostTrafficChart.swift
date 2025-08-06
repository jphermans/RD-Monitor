//
//  HostTrafficChart.swift
//  RD-Monitor
//
//  Created by Jean-Pierre Hermans on 28/05/2025.
//
import SwiftUI
import Charts

struct HostTrafficChart: View {
    var data: [HostTraffic]

    var body: some View {
        VStack(alignment: .leading) {
            Text("🔌 Traffic Usage (GB)")
                .font(.headline)
                .padding(.leading)

            Chart(data) { entry in
                BarMark(
                    x: .value("Used (GB)", entry.usedGB),
                    y: .value("Host", entry.host)
                )
            }
            .chartXAxisLabel("Used GB")
            .frame(height: 300)
            .padding()
        }
    }
}
