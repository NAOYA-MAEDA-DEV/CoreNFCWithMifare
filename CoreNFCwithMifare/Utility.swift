//
//  Utility.swift
//
//
//  Created by Naoya Maeda on 2024/04/20
//
//

import Foundation

enum SessionType: String, CaseIterable, Identifiable  {
  case read
  case write
  var id: String { rawValue }
}
