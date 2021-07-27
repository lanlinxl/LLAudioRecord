//
//  SFAudioPlay.swift
//  SFAudioComponent
//
//  Created by 兰林 on 2021/5/17.
//

import Foundation
import AVFoundation


class SFAudioPlay {
    
    let audioEngine: AVAudioEngine = AVAudioEngine()
    private var audioFilePlayer: AVAudioPlayerNode = AVAudioPlayerNode()
    ///是否播放
    public private(set) var isPlay = false
    var audioFile: AVAudioFile?
    
    var mixerOutputFileURL: URL?
    var mixerOutputAudioFile: AVAudioFile?
    ///资源加载相关
    var resourceSuccess: Bool = true
    init() {
        
    }
    

    public func startPlay(fileUrl:URL? ,complete:@escaping RecordCompletion , playComplet:@escaping PlayRecordCompleton) {
        guard let tempUrl = fileUrl else { return }
        do {
            let file = try AVAudioFile(forReading: tempUrl)
            audioFile = file
            print("文件成功 -> \(file.url)")
        }catch {
            resourceSuccess = false
            print("文件失败")
        }
        audioEngine.attach(self.audioFilePlayer)
        self.isPlay = true
        guard let tempAudioFile = self.audioFile else {
            complete(SFAudioRecordResult(message: "音频资源失效", error: nil, success: false))
            return }

        self.audioEngine.connect(self.audioFilePlayer, to: self.audioEngine.mainMixerNode, format: tempAudioFile.processingFormat)
        self.audioEngine.connect(self.audioEngine.mainMixerNode, to: self.audioEngine.outputNode, format: tempAudioFile.processingFormat)

        self.audioFilePlayer.scheduleSegment(tempAudioFile,
            startingFrame: AVAudioFramePosition(0),
            frameCount: AVAudioFrameCount(tempAudioFile.length),
            at: nil,
            completionHandler: nil)

        print(tempAudioFile.length)

        startEngine { [weak self] result in
            if result.success {
                self?.audioFilePlayer.play()
            }else {
                complete(result)
                return
            }
        }
    }
    private func startEngine(complete: @escaping RecordCompletion) {
        if !audioEngine.isRunning {
            do {
                _ = try audioEngine.start()
                print("引擎启动成功")
                return complete(SFAudioRecordResult(message: nil, error: nil, success: true))
            }catch let err{
                print("引擎启动失败 -> \(err)")
                return complete(SFAudioRecordResult(message: "录音引擎启动失败 \(err.localizedDescription)", error: err, success: false))
            }
        }
        return complete(SFAudioRecordResult(message: nil, error: nil, success: true))
    }
    
}



