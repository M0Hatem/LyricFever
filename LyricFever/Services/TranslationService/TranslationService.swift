//
//  TranslationService.swift
//  Lyric Fever
//
//  Created by Avi Wadhwa on 2025-08-04.
//

import Foundation
import NaturalLanguage
#if canImport(Translation)
import Translation

class TranslationService {
    static func translationTask(_ session: TranslationSession, request: [TranslationSession.Request]) async -> TranslationResult {
        print("Translation Service: Translation Task Called")
        do {
            let response = try await session.translations(from: request)
            if let sourceLanguage = response.first?.sourceLanguage, let targetLanguage = response.first?.targetLanguage {
                print("Translation Service: Successfully generated translation from \(String(describing: sourceLanguage.languageCode)) to \(String(describing: targetLanguage.languageCode))")
            }
            return TranslationResult.success(response)
            
        } catch {
            print("Translation Service, couldn't generate response")
            if let source = findRealLanguage(for: request) {
                print("Translation Service: Real Language Found: \(String(describing: source.languageCode))")
                return .needsConfigUpdate(source)
            } else {
                print("Translation Service: Unexpected Error Translating: \(error)")
                return .failure
            }
        }
    }
    
    static private func findRealLanguage(for translationRequest: [TranslationSession.Request]) -> Locale.Language? {
        var langCount: [Locale.Language: Int] = [:]
        let recognizer = NLLanguageRecognizer()
        for lyric in translationRequest {
            recognizer.reset()
            recognizer.processString(lyric.sourceText)
            if let dominantLanguage = recognizer.dominantLanguage {
                let value: Locale.Language = .init(identifier: dominantLanguage.rawValue)
                if value != Locale.Language.systemLanguages.first! {
                    langCount[value, default: 0] += 1
                }
            }
        }
        let totalCount = langCount.values.reduce(0, +)
        guard let highest = langCount.max(by: { $0.value < $1.value }) else {
            return nil
        }
        print("Language count:", langCount)
        if Double(highest.value) / Double(totalCount) > 0.8 {
            return highest.key
        } else {
            return nil
        }
    }
}
#endif
