//
//  MarkdownParser.swift
//  MyPal
//
//  Created by Chidume Nnamdi on 12/08/2025.
//

import Foundation
import SwiftUI

public struct MarkdownParser {

    static let shared = MarkdownParser()
    
    enum MardownTokenType {
        case text;
        case bold;
    }

    struct MarkdownToken {
        let type: MardownTokenType;
        let value: String;
    }
    
    func parse(text: String) -> [MarkdownToken] {
                
        var stack = "";
        var index = -1;
        
        var isBold = false;
        
        var heap: [MarkdownToken] = [];
        
        for character in text {
            
            index = index + 1;
            let nextCharacter: Character = index + 1 < text.count ? text[text.index(text.startIndex, offsetBy: index + 1)] : " ";
            
            // detect bold: **
            if(character == "*" && nextCharacter == "*") {
                
                if (isBold) {
                    
                    heap += [MarkdownToken(type: .bold, value: stack)]
                    stack = "";
                    isBold = false
                    continue
                    
                }
                
                if (!isBold) {
                    
                    heap += [MarkdownToken(type: .text, value: stack)]
                    stack = "";
                    
                    isBold = true
                    continue
                }
                
            }
            
            if (character == "*") {
                continue;
            }
            
            stack += String(character);
            
        }

        heap += [MarkdownToken(type: .text, value: stack)]
        stack = "";
        
        return heap
        
    }
    
}
