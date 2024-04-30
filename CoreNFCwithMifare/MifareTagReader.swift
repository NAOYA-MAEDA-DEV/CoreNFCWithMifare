//
//  MifareTagReader.swift
//
//
//  Created by Naoya Maeda on 2024/04/20
//
//

import Foundation
import CoreNFC

final class MifareTagReader: NSObject, ObservableObject {
  private var session: NFCTagReaderSession?
  
  private let writeBlockCommand: UInt8 = 0xA2
  private let readBlockCommand: UInt8 = 0x30
  private let dataOffset: UInt8 = 5
  private let blockSize = 4
  private let successCode: UInt8 = 0x0A
  
  var writeMesage = "test"
  let readingAvailable: Bool
  
  private var readBlock: [UInt8] = []
  private var responseData: Data?
  
  @Published var sessionType = SessionType.read
  @Published var readMessage: String?
  
  override init() {
    readingAvailable = NFCTagReaderSession.readingAvailable
    readBlock = [readBlockCommand, dataOffset]
  }
  
  func beginScanning() {
    guard readingAvailable else {
      print("This iPhone is not NFC-enabled.")
      return
    }
    session = NFCTagReaderSession(pollingOption: .iso14443, delegate: self, queue: nil)
    session?.alertMessage = "Please bring your iPhone close to the NFC tag."
    session?.begin()
  }
}

extension MifareTagReader: NFCTagReaderSessionDelegate {
  func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
    print("Reader session is active.")
  }
  
  func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
    print("error:\(error.localizedDescription)")
  }
  
  func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
    var tag: NFCTag?
    
    for nfcTag in tags {
      if case let .miFare(mifareTag) = nfcTag {
        if mifareTag.mifareFamily == .ultralight {
          tag = nfcTag
          break
        }
      }
    }
    
    if tag == nil {
      session.invalidate(errorMessage: "No valid found.")
      return
    }
    
    session.connect(to: tag!) { (error: Error?) in
      if error != nil {
        session.invalidate(errorMessage: "Connection error. Please try again.")
        return
      }
      
      let mifareTag = tag
      Task { [weak self] in
        guard let self else {
          session.invalidate(errorMessage: "No valid found.")
          return
        }
        if sessionType == .read {
          await read(from: mifareTag!, with: session)
        } else {
          await writeString(from: mifareTag!, with: session)
        }
      }
    }
  }
  
  private func read(from tag: NFCTag, with session: NFCTagReaderSession) async {
    guard case let .miFare(mifareTag) = tag else {
      session.invalidate(errorMessage: "No valid found.")
      return
    }
    
    do {
      responseData = try await mifareTag.sendMiFareCommand(commandPacket: Data(readBlock))
      
      DispatchQueue.main.async { [weak self] in
        guard let self, let responseData else {
          session.invalidate(errorMessage: "No valid found.")
          return
        }
        readMessage = (String(data: responseData, encoding: .utf8) ?? "empty")
      }
      
      session.alertMessage = "The tag reading has been completed."
      session.invalidate()
    } catch(let error) {
      session.invalidate(errorMessage: error.localizedDescription)
    }
  }
  
  private func writeString(from tag: NFCTag, with session: NFCTagReaderSession) async {
    guard case let .miFare(mifareTag) = tag else {
      session.invalidate(errorMessage: "No valid found.")
      return
    }
    
    let writeData = writeMesage.data(using: .ascii)!
    await write(writeData, to: mifareTag, offset: dataOffset, with: session)
  }
  
  private func write(_ data: Data, to tag: NFCMiFareTag, offset: UInt8, with session: NFCTagReaderSession) async {
    var blockData: Data = data.prefix(blockSize)
    
    if blockData.count < blockSize {
      blockData += Data(count: blockSize - blockData.count)
    }
    
    let writeCommand = Data([0xA2, 5]) + blockData
    
    do {
      let result = try await tag.sendMiFareCommand(commandPacket: writeCommand)
      if result[0] != successCode {
        session.invalidate(errorMessage: "Write tag error.")
        return
      } else {
        session.alertMessage = "Write data successful."
        session.invalidate()
      }
    } catch(let error) {
      session.invalidate(errorMessage: "Write tag error: \(error.localizedDescription). Please try again.")
    }
  }
}
