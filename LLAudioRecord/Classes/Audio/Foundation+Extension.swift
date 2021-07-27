//
//  Foundation+Extension.swift
//  SFAudioComponent
//
//  Created by 兰林 on 2021/5/25.
//

import Foundation


extension Array {
    
    func fetch(_ index: Int) -> Element? {
        guard 0..<self.count ~= index else { return nil }
        return self[index]
    }
    
}

extension String {
    static func ~= (lhs: String, rhs: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: rhs) else { return false }
        let range = NSRange(location: 0, length: lhs.utf16.count)
        return regex.firstMatch(in: lhs, options: [], range: range) != nil
    }
    
}

infix operator =~
func =~(lhs: String, rhs: String) -> Bool {
    do {
        return try RegexHelper(rhs).match(input: lhs)
    } catch _ {
        return false
    }
}

struct RegexHelper {
    let regex: NSRegularExpression
    
    init(_ pattern: String) throws {
        try regex = NSRegularExpression(pattern: pattern,
                                        options: .caseInsensitive)
    }
    
    func match(input: String) -> Bool {
        let matches = regex.matches(in: input,
                                            options: [],
                                            range: NSMakeRange(0, input.utf16.count))
        return matches.count > 0
    }
}
