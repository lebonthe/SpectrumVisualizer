//
//  AudioEngineManager.swift
//  SpectrumVisualizer
//
//  Created by S485856 on 2024/9/16.
//

import AVFoundation
import SwiftUI
import Charts
import Accelerate

class AudioEngineManager: ObservableObject {
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode() // 播放音樂的節點
    private var audioFile: AVAudioFile?
    @Published var magnitudes: [Float] = Array(repeating: 0, count: 512) // 用於儲存每個頻率的震幅
    
    let sampleRate: Double = 48000 // 採樣率
    let fftSize: Int = 1024 // 假設的 FFT 大小
    
    func loadAudioFile(file: String) {
        if let fileURL = Bundle.main.url(forResource: file, withExtension: "wav") {
            print("音樂文件路徑: \(fileURL)")
            do {
                audioFile = try AVAudioFile(forReading: fileURL)
            } catch {
                print("無法讀取音樂文件: \(error)")
            }
        } else {
            print("音樂文件加載失敗")
        }
        
        
    }
    
    func startAudioProcessing() {
        guard let audioFile = audioFile else {
            print("音樂文件未加載")
            return
        }
        
        let format = audioFile.processingFormat
        print(format) 
        // <AVAudioFormat 0x60000212caa0:  2 ch,  48000 Hz, Float32, deinterleaved>
        // 2ch: 兩聲道
        // 48000 Hz: Sample Rate
        // Float32: 音樂儲存格式
        // deinterleaved: 去交錯格式
        // <AVAudioFormat 0x6000021601e0:  2 ch,  44100 Hz, Float32, deinterleaved>
        
        // 連接 playerNode 到 audioEngine
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format) // 將節點與引擎的混音節點連接
        
        // 設置 Audio Tap 來捕捉音樂並進行 FFT 分析
        let inputNode = audioEngine.mainMixerNode
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputNode.outputFormat(forBus: 0)) { (buffer, time) in
            self.processAudioBuffer(buffer: buffer)
        }
        
        do {
            // 啟動引擎並播放音樂
            try audioEngine.start()
            playerNode.scheduleFile(audioFile, at: nil, completionHandler: nil)
            playerNode.play()
        } catch {
            print("無法啟動 audioEngine: \(error)")
        }
    }
    
    func stopAudioProcessing() {
        audioEngine.stop()
        audioEngine.mainMixerNode.removeTap(onBus: 0)
        playerNode.stop()
    }
    
    func processAudioBuffer(buffer: AVAudioPCMBuffer) {
        // 實時處理音樂緩衝區，執行 FFT 分析
        let fftMagnitudes = fft(buffer: buffer)
        
        // 更新分析結果，刷新 UI
        DispatchQueue.main.async {
            self.magnitudes = fftMagnitudes
        }
    }
    
    // 傅立葉轉換: 把一段時間上的音樂訊號分解成不同頻率的組合
    func fft(buffer: AVAudioPCMBuffer) -> [Float] {
        let frameCount = Int(buffer.frameLength)
        guard let channelData = buffer.floatChannelData?[0] else { return [] }
        
        // 設置 FFT
        let log2n = UInt(round(log2(Float(frameCount))))
        let fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2))!
        
        var realp = [Float](repeating: 0, count: frameCount/2)
        var imagp = [Float](repeating: 0, count: frameCount/2)
        
        return realp.withUnsafeMutableBufferPointer { realPointer in
            imagp.withUnsafeMutableBufferPointer { imagPointer in
                var complexBuffer = DSPSplitComplex(realp: realPointer.baseAddress!, imagp: imagPointer.baseAddress!)
                
                // 將音樂數據轉換為複數格式
                channelData.withMemoryRebound(to: DSPComplex.self, capacity: frameCount) { pointer in
                    vDSP_ctoz(pointer, 2, &complexBuffer, 1, UInt(frameCount/2))
                }
                
                // 執行 FFT
                vDSP_fft_zrip(fftSetup, &complexBuffer, 1, log2n, FFTDirection(FFT_FORWARD))
                
                // 計算每個頻率的幅度
                var magnitudes = [Float](repeating: 0.0, count: frameCount/2)
                vDSP_zvmags(&complexBuffer, 1, &magnitudes, 1, UInt(frameCount/2))
                
                // 釋放 FFT 設置
                vDSP_destroy_fftsetup(fftSetup)
                
                // 印出每個頻率對應的震幅值
                for index in 0..<512 {
                    let frequency = (Double(index) * sampleRate) / Double(fftSize)
                    print("Frequency: \(frequency) Hz, Amplitude: \(magnitudes[index])")
                }
                
                // 只返回前 512 個低頻分量 (這些對應於低於 24000 Hz 的頻率)
                return Array(magnitudes.prefix(512)) // 保留前 512 項
            }
        }
    }
}
