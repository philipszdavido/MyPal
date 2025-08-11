//
//  MarkdownParser.swift
//  MyPal
//
//  Created by Chidume Nnamdi on 10/08/2025.
//

import Foundation
import SwiftUI

class MarkdownStreamParser {
    
    static let shared = MarkdownStreamParser()
    
    private var buffer = ""
    
    private var text: Text = Text("")

    func append(chunk: String) -> Text {
        
        var first = false;
        var isBold = false
        var prevC = ""
        
        for c in chunk {
            
            if isBold {
                
                text = text + Text(buffer)
                buffer = ""
                
            }
            
            if c == "*" {
                
                if first {
                    isBold = true;
                    first = false
                    continue;
                }
                
                first = true
                continue
            }
            
            buffer.append(c)
        }
        
        return parseMarkdown(buffer)
    }

    private func parseMarkdown(_ markdown: String) -> Text {

        if let attributed = try? AttributedString(markdown: markdown) {
            return Text(attributed)
        } else {
            return Text(markdown)
        }
        
    }
}
