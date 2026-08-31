//
//  TranslationResult.swift
//  Lyric Fever
//
//  Created by Avi Wadhwa on 2025-08-04.
//

import Foundation
#if canImport(Translation)
import Translation

enum TranslationResult {
    case success([TranslationSession.Response])
    case needsConfigUpdate(Locale.Language)
    case failure
}
#endif
