//
//  SFAudioRecordResult.swift
//  SFAudioComponent
//
//  Created by 兰林 on 2021/5/20.
//

import Foundation
public typealias PlayRecordCompleton = () -> (Void)
public typealias RecordCompletion = (_ result: SFAudioRecordResult) -> (Void)
public struct SFAudioRecordResult {
    public var message: String?
    public var error: Error?
    public var success: Bool = false
}
