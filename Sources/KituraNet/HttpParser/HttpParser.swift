/**
 * Copyright IBM Corporation 2016
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import KituraSys
import http_parser_helper
import Foundation

// MARK: HttpParser

class HttpParser {

    ///
    /// A Handle to the HttpParser C-library
    ///
    var parser: http_parser

    ///
    /// Settings used for HttpParser
    ///
    var settings: http_parser_settings

    ///
    /// Delegate used for the parsing
    ///
    var delegate: HttpParserDelegate? {

        didSet {
            if let _ = delegate {
                withUnsafeMutablePointer(&delegate) {
                    ptr in
                    self.parser.data = UnsafeMutablePointer<Void>(ptr)
                }
            }
        }
        
    }
    
    ///
    /// Whether to upgrade the HTTP connection to HTTP 1.1
    ///
    var upgrade = 1

    ///
    /// Initializes a HttpParser instance
    ///
    /// - Parameter isRequest: whether or not this HTTP message is a request
    ///
    /// - Returns: an HttpParser instance
    ///
    init(isRequest: Bool) {
        
        parser = http_parser()
        settings = http_parser_settings()

        settings.on_url = { (parser, chunk, length) -> Int32 in
            let p = UnsafePointer<HttpParserDelegate?>(parser.memory.data)
            let data = NSData(bytes: chunk, length: length)
            p.memory?.onUrl(data)
            return 0
        }
        
        settings.on_header_field = { (parser, chunk, length) -> Int32 in
            let data = NSData(bytes: chunk, length: length)
            let p = UnsafePointer<HttpParserDelegate?>(parser.memory.data)
            p.memory?.onHeaderField(data)
            return 0
        }
        
        settings.on_header_value = { (parser, chunk, length) -> Int32 in
            let data = NSData(bytes: chunk, length: length)
            let p = UnsafePointer<HttpParserDelegate?>(parser.memory.data)
            p.memory?.onHeaderValue(data)
            return 0
        }
        
        settings.on_body = { (parser, chunk, length) -> Int32 in
            let p = UnsafePointer<HttpParserDelegate?>(parser.memory.data)
            let data = NSData(bytes: chunk, length: length)
            p.memory?.onBody(data)
           
            return 0
        }
        
        settings.on_headers_complete = { (parser) -> Int32 in
            let p = UnsafePointer<HttpParserDelegate?>(parser.memory.data)
            // TODO: Clean and refactor
            //let method = String( get_method(parser))
            let po =  get_method(parser)
            var message = ""
            var i = 0
            while((po+i).memory != Int8(0)) {
                message += String(UnicodeScalar(UInt8((po+i).memory)))
                i += 1
            }
            p.memory?.onHeadersComplete(message, versionMajor: parser.memory.http_major,
                versionMinor: parser.memory.http_minor)
            
            return 0
        }
        
        settings.on_message_begin = { (parser) -> Int32 in
            let p = UnsafePointer<HttpParserDelegate?>(parser.memory.data)
            p.memory?.onMessageBegin()
            
            return 0
        }
        
        settings.on_message_complete = { (parser) -> Int32 in
            let p = UnsafePointer<HttpParserDelegate?>(parser.memory.data)
            if get_status_code(parser) == 100 {
                p.memory?.reset()
            }
            else {
                p.memory?.onMessageComplete()
            }
            
            return 0
        }
        
        http_parser_init(&parser, isRequest ? HTTP_REQUEST : HTTP_RESPONSE)

    }
    
    ///
    /// Executes the parsing on the byte array
    ///
    /// - Parameter data: pointer to a byte array
    /// - Parameter length: length of the byte array
    ///
    /// - Returns: ???
    ///
    func execute (data: UnsafePointer<Int8>, length: Int) -> (Int, UInt32) {
        let nparsed = http_parser_execute(&parser, &settings, data, length)
        let upgrade = get_upgrade_value(&parser)
        return (nparsed, upgrade)
    }    
}

///
/// Delegate protocol for HTTP parsing stages
///
protocol HttpParserDelegate: class {
    
    func onUrl(url:NSData)
    func onHeaderField(data: NSData)
    func onHeaderValue(data: NSData)
    func onHeadersComplete(method: String, versionMajor: UInt16, versionMinor: UInt16)
    func onMessageBegin()
    func onMessageComplete()
    func onBody(body: NSData)
    func reset()
    
}
