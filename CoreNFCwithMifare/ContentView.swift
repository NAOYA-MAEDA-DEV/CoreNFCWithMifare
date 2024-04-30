//
//  ContentView.swift
//
//
//  Created by Naoya Maeda on 2024/04/20
//
//

import SwiftUI

struct ContentView: View {
  @StateObject private var reader = MifareTagReader()
  @FocusState private var textFieldIsFocused: Bool
  
  @State var showAlert = false
  @State var inputText = ""
  
  var body: some View {
    VStack(spacing: 0) {
      Text("Scan Result")
        .font(.largeTitle)
      Text(reader.readMessage ?? "")
      Spacer()
      if reader.sessionType == .write {
        VStack(alignment: .leading) {
          Text("Write message within 4 characters.")
          TextField(
            "Enter the message.",
            text: $inputText
          )
          .keyboardType(.asciiCapable)
          
          .onChange(of: inputText) {
            if inputText.count > 4 {
              inputText = String(inputText.prefix(4))
              showAlert = true
            }
            reader.writeMesage = inputText
          }
          .focused($textFieldIsFocused)
          .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding()
      }
      Picker("Session Type", selection: $reader.sessionType) {
        ForEach(SessionType.allCases) { session in
          Text(session.rawValue).tag(session)
        }
      }
      .colorMultiply(.accentColor)
      .pickerStyle(.segmented)
      .padding()
      Button(action: {
        reader.beginScanning()
      }, label: {
        Text("Scan")
          .frame(width: 200, height: 15)
      })
      .padding()
      .accentColor(Color.white)
      .background(Color.accentColor)
      .cornerRadius(.infinity)
      .disabled(!reader.readingAvailable)
    }
    .padding()
    .alert(isPresented: $showAlert) {
      Alert(
        title: Text("Maximum input length is less than 5 characters.")
      )
    }
  }
}

#Preview {
  ContentView()
}
