//
//  MessagePackRPCTests.swift
//  MessagePackRPCTests
//
//  Created by 阿部慎太郎 on 9/22/15.
//  Copyright © 2015 dictav. All rights reserved.
//

import XCTest
import MessagePack
import MessagePackRPC

class MessagePackRPCTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testNeoVim() {
        let task = NSTask()
        task.launchPath = "/usr/local/bin/nvim"
        task.arguments = ["-u", "NONE", "-N", "--embed"]
        
        let pipeA = NSPipe(), pipeB = NSPipe()
        let writer = pipeA.fileHandleForWriting
        let reader = pipeB.fileHandleForReading
        task.standardInput  = pipeA
        task.standardOutput = pipeB
        task.launch()
        defer {
            task.terminate()
        }
        
        let value = MessagePackValue.Array([
            .UInt(0),
            .UInt(1),
            .String("vim_get_api_info"),
            .Array([])
            ])
        let bytes = MessagePack.pack(value)
        let data = NSData(bytes: bytes, length: bytes.count)
        XCTAssertEqual(data.length, 21)
        
        writer.writeData(data)
        let eof = NSData(bytes: [0xff], length: 1)
        writer.writeData(eof) //send EOF
        writer.closeFile() //send EOF
        
        let receivedData = reader.readDataToEndOfFile()
        XCTAssert(receivedData.length > 0)
        
        let receivedValue = try? MessagePack.unpack(receivedData)
        XCTAssertNotNil(receivedValue)
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    
}
