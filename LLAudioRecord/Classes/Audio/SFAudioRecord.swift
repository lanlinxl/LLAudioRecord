//
//  SFAudioRecord.swift
//  SFAudioComponent
//
//  Created by 兰林 on 2021/5/17.
//

import Foundation
import UIKit
import AVFoundation


public class SFAudioRecord {
    ///录音结果回调
    private var audioEngine: AVAudioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    ///背景音乐播放
    private var audioPlayer: AVAudioPlayerNode = AVAudioPlayerNode()
    private var outref: ExtAudioFileRef?
    ///录音播放
    private var audioFilePlayer: AVAudioPlayerNode = AVAudioPlayerNode()
//    private var mixer: AVAudioMixerNode = AVAudioMixerNode()
    ///wav录音地址
    public private(set) var filePath : String? = nil
    ///MP3录音地址
    public private(set) var filePathMP3: String? = nil
    ///是否播放
    public private(set) var isPlay = false
    ///是否录音
    public private(set) var isRec = false
    ///是否是需要录音后的文件转码成mp3
    public var isMP3Active = true
    private var sdate: Date = Date()
    
    private var input: AVAudioInputNode {
        return audioEngine.inputNode
    }
    private var output: AVAudioNode?
    private var backgroundFile: AVAudioFile?
    private var playerLoopBuffer: AVAudioPCMBuffer?
    
    private var backgroundMusicURL: URL?
    private var needPlayBackgroundMusic: Bool = false
    
    /// 采样率相关
    public var sampleRate: Double = 44100
    ///mp3 压缩比 (64: 正常对话 ,96FM 广播，128 MP3 , 329 CD，500 - 1411 无损编码 )
    public var mp3Rate: Int = 128
    private let mp3BuffSize = 8192
    
    /// 初始化方法
    /// - Parameter backgroundMusicUrl: 传入背景音乐
    public init(with backgroundMusicUrl: URL?) {
        loadBackgroundMusic(url: backgroundMusicURL)
        nodeCreate()
        addNotification()
        AvAudioSessionChange()
    }
    
    /// 初始化方法
    public init() {
        nodeCreate()
        addNotification()
        AvAudioSessionChange()
    }
    
    /// 传入背景音乐
    /// - Parameter url: 传nil 没有背景音乐
    public func loadBackgroundMusic(with url: URL?) {
        if let audioUrl = url {
            needPlayBackgroundMusic = true
            backgroundMusicURL = audioUrl
        }else {
            needPlayBackgroundMusic = false
        }
    }
    
    private func nodeCreate() {
        self.audioEngine.attach(audioFilePlayer)
//        self.audioEngine.attach(mixer)
    }
    
    ///监听
    private func addNotification() {
        ///引擎配置更改
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: OperationQueue.main) {[weak self] note in
            ///重新链接
            self?.nodeCreate()
        }
    }
    
    private func AvAudioSessionChange() {
        let session = AVAudioSession.sharedInstance()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption(userInfo:)), name: AVAudioSession.interruptionNotification, object: session)
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange(userInfo:)), name: AVAudioSession.routeChangeNotification, object: session)
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleMediaServicesReset(userInfo:)), name: AVAudioSession.mediaServicesWereResetNotification, object: session)
    }
    
    private func createAvAudioSession(completion: @escaping RecordCompletion) {
        do {
            let session = AVAudioSession.sharedInstance()
            if #available(iOS 10.0, *) {
                try session.setCategory(.playAndRecord, options: [.allowBluetoothA2DP,.defaultToSpeaker,.allowAirPlay])
            }else {
                try session.setCategory(.playAndRecord, options: [.allowBluetooth,.defaultToSpeaker])
            }
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            try session.setPreferredSampleRate(sampleRate)
            completion(SFAudioRecordResult(message: nil, error: nil, success: true))
            
        } catch let err{
            completion(SFAudioRecordResult(message: err.localizedDescription, error: err, success: false))
            print(err)
        }
    }
    
    private func loadBackgroundMusic(url: URL?)  {
        if let audioUrl = url {
            needPlayBackgroundMusic = true
            backgroundMusicURL = audioUrl
        }else {
            needPlayBackgroundMusic = false
        }
    }
    
    private func preparePlayer(complet: @escaping RecordCompletion) {
        guard let tempUrl = backgroundMusicURL else { return  }
        do {
            let file = try AVAudioFile(forReading: tempUrl)
            backgroundFile = file
            print("背景音乐文件加载成功 -> \(file.url)")
        }catch let err{
            print("文件失败 -> \(err)")
            complet(SFAudioRecordResult(message: "背景音乐文件加载失败 \(err.localizedDescription)", error: err, success: false))
            return
        }
        guard let tempFile = backgroundFile else {
            complet(SFAudioRecordResult(message: "背景音乐文件加载失败", error: nil, success: false))
            return
        }
        
        let audioFormat = tempFile.processingFormat
        let audioFrameCount = UInt32(tempFile.length)
        let audioFileBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: audioFrameCount)
        guard let tempFileBuffer = audioFileBuffer else {
            complet(SFAudioRecordResult(message: "PCM缓冲区加载失败", error: nil, success: false))
            return
        }
        do {
            playerLoopBuffer = tempFileBuffer
            _ = try tempFile.read(into: tempFileBuffer, frameCount: audioFrameCount)
        } catch let err{
            print("缓冲文件失败 -> \(err)")
            complet(SFAudioRecordResult(message: "PCM缓冲区加载失败\(err.localizedDescription)", error: err, success: false))
            return
        }
        audioEngine.attach(audioPlayer)
        audioEngine.connect(audioPlayer, to: audioEngine.mainMixerNode, format: audioFormat)
        audioPlayer.scheduleFile(tempFile, at: nil, completionHandler: nil)
        audioPlayer.scheduleBuffer(tempFileBuffer, at: nil, options: .loops, completionHandler: nil)
        print("背景音乐准备完成")
        complet(SFAudioRecordResult(message: nil, error: nil, success: true))
    }
    
   public func startRecordFile(recordComplet: @escaping RecordCompletion) {
        createAvAudioSession {[weak self] result in
            guard let self = self else {
                recordComplet(SFAudioRecordResult(message: nil, error: nil, success: false))
                return}
            if !result.success {
                recordComplet(result)
                return
            }
            ///判断有没有背景音乐
            if self.needPlayBackgroundMusic {
                self.preparePlayer { bgResult in
                    if bgResult.success {
                        self.startRecord { recordResult in
                            recordComplet(recordResult)
                        }
                    }else {
                        recordComplet(bgResult)
                    }
                }
            }else {
                ///开始录音
                self.startRecord(recordComplete: { recordResult in
                    recordComplet(recordResult)
                })
            }
        }
    }
    
    private func startRecord(recordComplete: @escaping RecordCompletion) {
        isRec = true
        filePath = nil
        isMP3Active = true
        guard let inputDevice = AVAudioSession.sharedInstance().currentRoute.outputs.fetch(0) else {
            return
        }
        let isHeadphoneSpeaker = (inputDevice.portType.rawValue =~ "(luetooth)|(irplay)|(eadphone)") // b(B)luetooth / a(A)irplay / h(H)eadphone
        let output = isHeadphoneSpeaker ? self.audioEngine.mainMixerNode : self.audioEngine.inputNode
        self.output = output
        
        let format = output.inputFormat(forBus: 0)
        
        if isHeadphoneSpeaker {
            self.mixMicroPhone()
        } else {
            self.disconnectMicroPhone()
        }
        guard let dir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else {
            recordComplete(SFAudioRecordResult(message: "沙箱路径获取错误", error: nil, success: false))
            return  }
        filePath =  dir.appending("/temp\(Int(Date.init().timeIntervalSince1970)).wav")
        guard let tempPath =  filePath
            else {
            recordComplete(SFAudioRecordResult(message: "format错误", error: nil, success: false))
            return  }
           let tempUrl: CFURL = URL(fileURLWithPath: tempPath) as CFURL
        _ = ExtAudioFileCreateWithURL(tempUrl,
            kAudioFileWAVEType,
            format.streamDescription,
            nil,
            AudioFileFlags.eraseFile.rawValue,
            &outref)
        output.installTap(onBus: 0, bufferSize: AVAudioFrameCount(mp3BuffSize), format: format, block: {[weak self] (buffer, time) -> Void in
            guard let self = self ,
                  let tempOut = self.outref
                  else {
                recordComplete(SFAudioRecordResult(message: "录音错误", error: nil, success: false))
                return }
            
            let audioBuffer : AVAudioBuffer = buffer
            _ = ExtAudioFileWrite(tempOut, buffer.frameLength, audioBuffer.audioBufferList)
        })
        
        
        startEngine {[weak self] result in
            if !result.success {
                recordComplete(result)
                return
            }else {
                guard let tempPath = self?.filePath,
                      let rate = self?.mp3Rate
                      else { return  }
                self?.audioPlayer.play()
                if self?.isMP3Active == true {
                    self?.startMP3Rec(path: tempPath, rate: Int32(rate))
                }
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
    
    private func startMP3Rec(path: String, rate: Int32) {
        print("开始MP3转码")
        self.isMP3Active = true
        var total = 0
        var read = 0
        var write: Int32 = 0
        let mp3path = path.replacingOccurrences(of: "wav", with: "mp3")
        var pcm: UnsafeMutablePointer<FILE> = fopen(path, "rb")
        fseek(pcm, 4*1024, SEEK_CUR)
        let mp3: UnsafeMutablePointer<FILE> = fopen(mp3path, "wb")
        let PCM_SIZE: Int = 8192
        let MP3_SIZE: Int32 = 8192
        let pcmbuffer = UnsafeMutablePointer<Int16>.allocate(capacity: Int(PCM_SIZE*2))
        let mp3buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(MP3_SIZE))

        let sampleRate = Int32(input.inputFormat(forBus: 0).sampleRate)
        let lame = lame_init()
        lame_set_num_channels(lame, 1)
        lame_set_mode(lame, MONO)
        lame_set_in_samplerate(lame, sampleRate / 2)
        lame_set_out_samplerate(lame, sampleRate)
        lame_set_brate(lame, rate)
        lame_set_VBR(lame, vbr_off)
        lame_set_quality(lame, 2)
        lame_init_params(lame)
        DispatchQueue.global(qos: .default).async {
            while true {
                pcm = fopen(path, "rb")
                fseek(pcm, 4*1024 + total, SEEK_CUR)
                read = fread(pcmbuffer, MemoryLayout<Int16>.size, PCM_SIZE, pcm)
                if read != 0 {
                    write = lame_encode_buffer(lame, pcmbuffer, nil, Int32(read), mp3buffer, MP3_SIZE)
                    fwrite(mp3buffer, Int(write), 1, mp3)
                    total += read * MemoryLayout<Int16>.size
                    fclose(pcm)
                } else if !self.isMP3Active {
                    _ = lame_encode_flush(lame, mp3buffer, MP3_SIZE)
                    _ = fwrite(mp3buffer, Int(write), 1, mp3)
                    break
                } else {
                    fclose(pcm)
                    usleep(50)
                }
            }
            lame_close(lame)
            fclose(mp3)
            fclose(pcm)
            DispatchQueue.main.async { [weak self] in
                print("转码结束")
                print("mp3 -> \(mp3path)")
                self?.filePathMP3 = mp3path
            }
        }
    }
    
    public func stopRecord() {
        self.isRec = false
        if self.output is AVAudioMixerNode  {
            self.audioEngine.stop()
        }else {
            self.audioEngine.pause()
        }
        let output = getOutPutNode()
        guard let outPutNode = output else { return }
        outPutNode.removeTap(onBus: 0)
        
        self.stopMP3Rec()
        guard let tempOutRef = outref else { return  }
        ExtAudioFileDispose(tempOutRef)
        
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch let err{
            print(err)
        }
    }
    ///录音播放
    public func startPlay(complete:@escaping RecordCompletion , playComplet:@escaping PlayRecordCompleton) {
        
        guard let path = filePath else {
            complete(SFAudioRecordResult(message: "录音音频播放失败", error: nil, success: false))
            return }
        self.isPlay = true
        do {
            self.audioFile = try AVAudioFile(forReading: URL(fileURLWithPath: path))
        } catch let err {
            print(err)
        }

        guard let tempAudioFile = self.audioFile else {
            complete(SFAudioRecordResult(message: "音频资源失效", error: nil, success: false))
            return }

        self.audioEngine.connect(self.audioFilePlayer, to: self.audioEngine.mainMixerNode, format: tempAudioFile.processingFormat)
        self.audioEngine.connect(self.audioEngine.mainMixerNode, to: self.audioEngine.outputNode, format: tempAudioFile.processingFormat)

        self.audioFilePlayer.scheduleSegment(tempAudioFile,
            startingFrame: AVAudioFramePosition(0),
            frameCount: AVAudioFrameCount(tempAudioFile.length),
            at: nil,
            completionHandler: playComplet)

        self.sdate = Date()
        print(tempAudioFile.length)

        startEngine { [weak self] result in
            if result.success {
                self?.audioFilePlayer.play()
            }else {
                complete(result)
                return
            }
        }
        complete(SFAudioRecordResult(message: nil, error: nil, success: true))
    }
    
    public func stopPlay(complete:@escaping RecordCompletion) {
        self.isPlay = false
        if self.audioFilePlayer.isPlaying {
            self.audioFilePlayer.stop()
        }
        self.audioEngine.stop()
        let elapsed = Date().timeIntervalSince(self.sdate)
        print(elapsed)
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch let err{
            complete(SFAudioRecordResult(message: err.localizedDescription, error: err, success: false))
        }
        complete(SFAudioRecordResult(message: nil, error: nil, success: true))
    }
    
    
    private func stopMP3Rec() {
        self.isMP3Active = false
    }
    
    private func getOutPutNode() -> AVAudioNode? {
        guard let inputDevice = AVAudioSession.sharedInstance().currentRoute.outputs.fetch(0) else {
            return nil
        }
        let isHeadphoneSpeaker = (inputDevice.portType.rawValue =~ "(luetooth)|(irplay)|(eadphone)")
        let output = isHeadphoneSpeaker ? self.audioEngine.mainMixerNode : self.audioEngine.inputNode
        return output
    }
    
    
    
//    MARK: 通知相关方法
    @objc func handleInterruption(userInfo: NSNotification) {
        print(userInfo)
    }
    
    @objc func handleRouteChange(userInfo: NSNotification) {
        print(userInfo)
        ///作一些操作
        
        
    }
    
    @objc func handleMediaServicesReset(userInfo: NSNotification) {
        print(userInfo)
        nodeCreate()
    }
    
    deinit {
        let session = AVAudioSession.sharedInstance()
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: session)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: session)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.mediaServicesWereResetNotification, object: session)
    }
    
}

extension SFAudioRecord {
    
    func mixMicroPhone() {
        if input.inputFormat(forBus: 0).sampleRate > 1,
           input.inputFormat(forBus: 0).channelCount > 0 {
            return
        }
        audioEngine.connect(audioEngine.inputNode, to: audioEngine.mainMixerNode, format: input.inputFormat(forBus: 0))
    }
    
    func disconnectMicroPhone() {
        audioEngine.disconnectNodeOutput(audioEngine.inputNode)
    }
}


