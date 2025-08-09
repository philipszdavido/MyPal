//
//  printUtils.swift
//  MyPal
//
//  Created by Chidume Nnamdi on 05/08/2025.
//

import Foundation

func printJSON(data: Data) {
    if let json = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers),
       let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
       let prettyString = String(data: prettyData, encoding: .utf8) {
        print("📦 Response JSON:\n\(prettyString)")
    }
}
