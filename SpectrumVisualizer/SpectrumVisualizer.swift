//
//  SpectrumVisualizer.swift
//  SpectrumVisualizer
//
//  Created by S485856 on 2024/9/16.
//

import SwiftUI
import Charts

struct SpectrumVisualizer: View {
    @StateObject private var audioEngineManager = AudioEngineManager()
    @State private var isPlaying: Bool = false
    
    // 假設採樣率為 48000 Hz，FFT 窗口大小為 1024
        let sampleRate: Double = /*48000*/ 44100
        let fftSize: Int = 1024
    
    // 計算每個索引對應的頻率
        private func frequency(for index: Int) -> Double {
            return (Double(index) * sampleRate) / Double(fftSize)
        }
    
    var body: some View {
        VStack {
            Chart(audioEngineManager.magnitudes.indices, id: \.self) { index in
                BarMark(
                    x: .value("Frequency", frequency(for: index)),
                    y: .value("Amplitude", audioEngineManager.magnitudes[index])
                )
                .foregroundStyle(.blue)
            }
            .chartXAxis {
                AxisMarks(values: Array(stride(from: 0, through: 1000, by: 100))) { value in
                    if let frequency = value.as(Double.self) {
                        AxisValueLabel(String(format: "%.0f Hz", frequency), centered: true)
                        AxisGridLine()
                        AxisTick()
                    }
                }
            }
            .chartScrollableAxes(.horizontal)
            .chartXScale(domain: .automatic)  // 資料範圍，設定 X 軸上實際資料點的範圍
            .chartYScale(domain: 0...10000)
            .clipped()
            .frame(width: 300, height: 500)
            .padding()
            
            Button(action: {
                if isPlaying {
                    audioEngineManager.stopAudioProcessing()
                    isPlaying = false
                } else {
                    audioEngineManager.loadAudioFile(file: "數碼寶貝")
                    audioEngineManager.startAudioProcessing()
                    isPlaying = true
                }
            }) {
                Text("Start/Pause Music & Spectrum")
            }
            .padding()
            Button(action: {
                if isPlaying {
                    audioEngineManager.stopAudioProcessing()
                    isPlaying = false
                } else {
                    audioEngineManager.loadAudioFile(file: "旅行的意義")
                    audioEngineManager.startAudioProcessing()
                    isPlaying = true
                }
            }) {
                Text("Start/Pause Music & Spectrum")
            }.padding()
        }
        .onAppear {
            
        }
        .onDisappear {
            if isPlaying {
                audioEngineManager.stopAudioProcessing()
            }
        }
    }
}
