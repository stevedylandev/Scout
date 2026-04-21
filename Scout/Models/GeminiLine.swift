//
//  GeminiLine.swift
//  Scout
//

import Foundation

enum GeminiLine {
    case text(String)
    case link(url: String, label: String)
    case heading1(String)
    case heading2(String)
    case heading3(String)
    case listItem(String)
    case quote(String)
    case preformattedBlock(String, alt: String)
}
