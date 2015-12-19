//
//  Session.swift
//  MessagePackRPC
//
//  Created by 阿部慎太郎 on 9/21/15.
//  Copyright © 2015 dictav. All rights reserved.
//

import Foundation
import MessagePack
import Result

// https://github.com/msgpack-rpc/msgpack-rpc/blob/master/spec.md

struct Response {
    let encoder: NSFileHandle
    let requestId: UInt32
    var didSend = false
}

enum MessageType: Int {
    case Response
    case Request
    case Notify
}


extension Response {
    mutating func send(data: MessagePackValue, isError: Bool) throws {
        if (didSend) {
            throw NSError(domain: "MessagePackRPC", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Response to id \(requestId) already sent"
                ])
        }
        
        // Response Message: [type, msgid, error, result]
        // msgid must be a uint 32. But MessagePack.framework don't have packing small uint 32.
        // However, common receivers, like neovim, don't restrict this.
        let value: MessagePackValue
        if (isError) {
            value = MessagePackValue([ .Int(1), .Int(1), data, .Nil ])
        } else {
            value = MessagePackValue([ .Int(1), .Int(1), .Nil, data ])
        }
        
        let buf = MessagePack.pack(value)
        encoder.writeData(NSData(bytes: buf, length: buf.count))
        encoder.writeData(NSData(bytes: [0xff], length: 1)) //send EOF
        
        didSend = true
    }
}

class Session: NSObject {
    let _pipeA = NSPipe()
    let _pipeB = NSPipe()
    
    var requestHandler: ((id: Int, method: String, args: [MessagePackValue]) -> ())?
    var notifyHandler: ((method: String, args: [MessagePackValue]) -> ())?
    
    var writer: NSFileHandle {
        return _pipeA.fileHandleForWriting
    }
    
    var reader: NSFileHandle {
        return _pipeB.fileHandleForReading
    }
    
    init(types: [String: Any]) {
        
        super.init()
        
        reader.readToEndOfFileInBackgroundAndNotify()
        NSNotificationCenter.defaultCenter().addObserver( self,
            selector: "hoge:",
            name: NSFileHandleDataAvailableNotification,
            object: reader
        )
    }
    
    func attach() {
        
    }
    
    func dettach() {
        
    }
    
    private func hoge(not: NSNotification) {
        let data = reader.readDataToEndOfFile()
        if let value = try? MessagePack.unpack(data),
            case .Array(let array) = value where array.count >= 3,
            case .Int(let val) = array[0],
            let type = MessageType(rawValue: Int(val))
        {
            switch type {
            case .Request:
                
                guard array.count == 4,
                    case .Int(let id) = array[1],
                    case .String(let method) = array[2],
                    case .Array(let args) = array[3]
                    else {
                        fatalError("invalid format")
                }
                
                requestHandler?(id: Int(id), method: method, args: args)
                
            case .Notify:
                
                guard array.count == 3,
                    case .String(let method) = array[1],
                    case .Array(let args) = array[2]
                    else {
                        fatalError("invalid format")
                }
                
                notifyHandler?(method: method, args: args)
            case .Response:
                fatalError("Response を受け取ることってないよね？")
            }
        } else {
            // ??? throw error?
            print("parse error")
        }
    }
}

extension Session {
    func request(method: String, args: [MessagePackValue], callback: (Result<MessagePackValue, NSError>) -> ()) {
        let value = MessagePackValue([ .Int(0), .Int(1), .String(method), .Array(args) ])
        
        let buf = MessagePack.pack(value)
        writer.writeData(NSData(bytes: buf, length: buf.count))
        writer.writeData(NSData(bytes: [0xff], length: 1)) //send EOF
    }
}