//
//  Server.swift
//  ReflektorKitSwift
//
//  Created by Alex Usbergo on 15/01/16.
//  Copyright © 2016 Alex Usbergo. All rights reserved.
//
//  Forked from https://github.com/glock45/swifter/tree/master/Sources
//

import Foundation

public class HttpHandlers {
    
    private static let rangePrefix = "bytes="
    
    public class func directory(dir: String) -> (HttpRequest -> HttpResponse) {
        return { request in
            
            guard let localPath = request.params.first else {
                return HttpResponse.NotFound
            }
            
            let filesPath = dir + "/" + localPath.1
            
            guard let fileBody = NSData(contentsOfFile: filesPath) else {
                return HttpResponse.NotFound
            }
            
            if let rangeHeader = request.headers["range"] {
                
                guard rangeHeader.hasPrefix(HttpHandlers.rangePrefix) else {
                    return HttpResponse.BadRequest
                }
                
                #if os(Linux)
                    let rangeString = rangeHeader.substringFromIndex(HttpHandlers.rangePrefix.characters.count)
                #else
                    let rangeString = rangeHeader.substringFromIndex(rangeHeader.startIndex.advancedBy(HttpHandlers.rangePrefix.characters.count))
                #endif
                let rangeStringExploded = rangeString.split("-")
                guard rangeStringExploded.count == 2 else {
                    return HttpResponse.BadRequest
                }
                
                let startStr = rangeStringExploded[0]
                let endStr   = rangeStringExploded[1]
                
                guard let start = Int(startStr), end = Int(endStr) else {
                    var array = [UInt8](count: fileBody.length, repeatedValue: 0)
                    fileBody.getBytes(&array, length: fileBody.length)
                    return HttpResponse.RAW(200, "OK", nil, { $0.write(array) })
                }
                
                let length = end - start
                let range = NSRange(location: start, length: length + 1)
                
                guard range.location + range.length <= fileBody.length else {
                    return HttpResponse.RAW(416, "Requested range not satisfiable", nil, nil)
                }
                
                let subData = fileBody.subdataWithRange(range)
                
                let headers = [
                    "Content-Range" : "bytes \(startStr)-\(endStr)/\(fileBody.length)"
                ]
                
                var array = [UInt8](count: subData.length, repeatedValue: 0)
                subData.getBytes(&array, length: subData.length)
                return HttpResponse.RAW(206, "Partial Content", headers, { $0.write(array) })
                
            } else {
                var array = [UInt8](count: fileBody.length, repeatedValue: 0)
                fileBody.getBytes(&array, length: fileBody.length)
                return HttpResponse.RAW(200, "OK", nil, { $0.write(array) })
            }
            
        }
    }
    
    public class func directoryBrowser(dir: String) -> ( HttpRequest -> HttpResponse ) {
        return { r in
            if let (_, value) = r.params.first {
                let filePath = dir + "/" + value
                let fileManager = NSFileManager.defaultManager()
                var isDir: ObjCBool = false
                if fileManager.fileExistsAtPath(filePath, isDirectory: &isDir) {
                    if isDir {
                        do {
                            let files = try fileManager.contentsOfDirectoryAtPath(filePath)
                            var response = "<h3>\(filePath)</h3></br><table>"
                            response += files.map({ "<tr><td><a href=\"\(r.path)/\($0)\">\($0)</a></td></tr>"}).joinWithSeparator("")
                            response += "</table>"
                            return HttpResponse.OK(.Html(response))
                        } catch {
                            return HttpResponse.NotFound
                        }
                    } else {
                        if let fileBody = NSData(contentsOfFile: filePath) {
                            var array = [UInt8](count: fileBody.length, repeatedValue: 0)
                            fileBody.getBytes(&array, length: fileBody.length)
                            return HttpResponse.RAW(200, "OK", nil, { $0.write(array) })
                        }
                    }
                }
            }
            return HttpResponse.NotFound
        }
    }
}


#if os(Linux)
    import Glibc
#else
    import Foundation
#endif

enum HttpParserError: ErrorType {
    case InvalidStatusLine(String)
}

class HttpParser {
    
    func readHttpRequest(socket: Socket) throws -> HttpRequest {
        let statusLine = try socket.readLine()
        let statusLineTokens = statusLine.split(" ")
        if statusLineTokens.count < 3 {
            throw HttpParserError.InvalidStatusLine(statusLine)
        }
        let request = HttpRequest()
        request.method = statusLineTokens[0]
        request.path = statusLineTokens[1]
        request.queryParams = extractQueryParams(request.path)
        request.headers = try readHeaders(socket)
        if let contentLength = request.headers["content-length"], let contentLengthValue = Int(contentLength) {
            request.body = try readBody(socket, size: contentLengthValue)
        }
        return request
    }
    
    private func extractQueryParams(url: String) -> [(String, String)] {
        guard let query = url.split("?").last else {
            return []
        }
        return query.split("&").reduce([(String, String)]()) { (c, s) -> [(String, String)] in
            let tokens = s.split(1, separator: "=")
            if let name = tokens.first, value = tokens.last {
                return c + [(name.removePercentEncoding(), value.removePercentEncoding())]
            }
            return c
        }
    }
    
    private func readBody(socket: Socket, size: Int) throws -> [UInt8] {
        var body = [UInt8]()
        var counter = 0
        while counter < size {
            body.append(try socket.read())
            counter += 1
        }
        return body
    }
    
    private func readHeaders(socket: Socket) throws -> [String: String] {
        var requestHeaders = [String: String]()
        repeat {
            let headerLine = try socket.readLine()
            if headerLine.isEmpty {
                return requestHeaders
            }
            let headerTokens = headerLine.split(1, separator: ":")
            if let name = headerTokens.first, value = headerTokens.last {
                requestHeaders[name.lowercaseString] = value.trim()
            }
        } while true
    }
    
    func supportsKeepAlive(headers: [String: String]) -> Bool {
        if let value = headers["connection"] {
            return "keep-alive" == value.trim()
        }
        return false
    }
}


public class HttpRequest {
    
    public var path: String = ""
    public var queryParams: [(String, String)] = []
    public var method: String = ""
    public var headers: [String: String] = [:]
    public var body: [UInt8] = []
    public var address: String? = ""
    public var params: [String: String] = [:]
    
    public func parseUrlencodedForm() -> [(String, String)] {
        guard let contentTypeHeader = headers["content-type"] else {
            return []
        }
        let contentTypeHeaderTokens = contentTypeHeader.split(";").map { $0.trim() }
        guard let contentType = contentTypeHeaderTokens.first where contentType == "application/x-www-form-urlencoded" else {
            return []
        }
        return String.fromUInt8(body).split("&").map { (param: String) -> (String, String) in
            let tokens = param.split("=")
            if let name = tokens.first, value = tokens.last where tokens.count == 2 {
                return (name.replace("+", new: " ").removePercentEncoding(),
                    value.replace("+", new: " ").removePercentEncoding())
            }
            return ("","")
        }
    }
    
    public struct MultiPart {
        
        public let headers: [String: String]
        public let body: [UInt8]
        
        public var name: String? {
            return valueFor("content-disposition", parameterName: "name")?.unquote()
        }
        
        public var fileName: String? {
            return valueFor("content-disposition", parameterName: "filename")?.unquote()
        }
        
        private func valueFor(headerName: String, parameterName: String) -> String? {
            return headers.reduce([String]()) { (currentResults: [String], header: (key: String, value: String)) -> [String] in
                guard header.key == headerName else {
                    return currentResults
                }
                let headerValueParams = header.value.split(";").map { $0.trim() }
                return headerValueParams.reduce(currentResults, combine: { (results:[ String], token: String) -> [String] in
                    let parameterTokens = token.split(1, separator: "=")
                    if parameterTokens.first == parameterName, let value = parameterTokens.last {
                        return results + [value]
                    }
                    return results
                })
                }.first
        }
    }
    
    public func parseMultiPartFormData() -> [MultiPart] {
        guard let contentTypeHeader = headers["content-type"] else {
            return []
        }
        let contentTypeHeaderTokens = contentTypeHeader.split(";").map { $0.trim() }
        guard let contentType = contentTypeHeaderTokens.first where contentType == "multipart/form-data" else {
            return []
        }
        var boundary: String? = nil
        contentTypeHeaderTokens.forEach({
            let tokens = $0.split("=")
            if let key = tokens.first where key == "boundary" && tokens.count == 2 {
                boundary = tokens.last
            }
        })
        if let boundary = boundary where boundary.utf8.count > 0 {
            return parseMultiPartFormData(body, boundary: "--\(boundary)")
        }
        return []
    }
    
    private func parseMultiPartFormData(data: [UInt8], boundary: String) -> [MultiPart] {
        var generator = data.generate()
        var result = [MultiPart]()
        while let part = nextMultiPart(&generator, boundary: boundary, isFirst: result.isEmpty) {
            result.append(part)
        }
        return result
    }
    
    private func nextMultiPart(inout generator: IndexingGenerator<[UInt8]>, boundary: String, isFirst: Bool) -> MultiPart? {
        if isFirst {
            guard nextMultiPartLine(&generator) == boundary else {
                return nil
            }
        } else {
            nextMultiPartLine(&generator)
        }
        var headers = [String: String]()
        while let line = nextMultiPartLine(&generator) where !line.isEmpty {
            let tokens = line.split(":")
            if let name = tokens.first, value = tokens.last where tokens.count == 2 {
                headers[name.lowercaseString] = value.trim()
            }
        }
        guard let body = nextMultiPartBody(&generator, boundary: boundary) else {
            return nil
        }
        return MultiPart(headers: headers, body: body)
    }
    
    private func nextMultiPartLine(inout generator: IndexingGenerator<[UInt8]>) -> String? {
        var result = String()
        while let value = generator.next() {
            if value > HttpRequest.CR {
                result.append(Character(UnicodeScalar(value)))
            }
            if value == HttpRequest.NL {
                break
            }
        }
        return result
    }
    
    static let CR = UInt8(13)
    static let NL = UInt8(10)
    
    private func nextMultiPartBody(inout generator: IndexingGenerator<[UInt8]>, boundary: String) -> [UInt8]? {
        var body = [UInt8]()
        let boundaryArray = [UInt8](boundary.utf8)
        var matchOffset = 0
        while let x = generator.next() {
            matchOffset = ( x == boundaryArray[matchOffset] ? matchOffset + 1 : 0 )
            body.append(x)
            if matchOffset == boundaryArray.count {
                body.removeRange(Range<Int>(start: body.count-matchOffset, end: body.count))
                if body.last == HttpRequest.NL {
                    body.removeLast()
                    if body.last == HttpRequest.CR {
                        body.removeLast()
                    }
                }
                return body
            }
        }
        return nil
    }
}


public enum SerializationError: ErrorType {
    case InvalidObject
    case NotSupported
}

public protocol HttpResponseBodyWriter {
    func write(data: [UInt8])
}

public enum HttpResponseBody {
    
    case Json(AnyObject)
    case Html(String)
    case Text(String)
    case Custom(Any, (Any) throws -> String)
    
    func content() -> (Int, ((HttpResponseBodyWriter) throws -> Void)?) {
        do {
            switch self {
            case .Json(let object):
                guard NSJSONSerialization.isValidJSONObject(object) else {
                    throw SerializationError.InvalidObject
                }
                let json = try NSJSONSerialization.dataWithJSONObject(object, options: NSJSONWritingOptions.PrettyPrinted)
                let data = Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>(json.bytes), count: json.length))
                return (data.count, {
                    $0.write(data)
                })
            case .Text(let body):
                let data = [UInt8](body.utf8)
                return (data.count, {
                    $0.write(data)
                })
            case .Html(let body):
                let serialised = "<html><meta charset=\"UTF-8\"><body>\(body)</body></html>"
                let data = [UInt8](serialised.utf8)
                return (data.count, {
                    $0.write(data)
                })
            case .Custom(let object, let closure):
                let serialised = try closure(object)
                let data = [UInt8](serialised.utf8)
                return (data.count, {
                    $0.write(data)
                })
            }
        } catch {
            let data = [UInt8]("Serialisation error: \(error)".utf8)
            return (data.count, {
                $0.write(data)
            })
        }
    }
}

public enum HttpResponse {
    
    case OK(HttpResponseBody), Created, Accepted
    case MovedPermanently(String)
    case BadRequest, Unauthorized, Forbidden, NotFound
    case InternalServerError
    case RAW(Int, String, [String:String]?, ((HttpResponseBodyWriter) -> Void)? )
    
    func statusCode() -> Int {
        switch self {
        case .OK(_)                   : return 200
        case .Created                 : return 201
        case .Accepted                : return 202
        case .MovedPermanently        : return 301
        case .BadRequest              : return 400
        case .Unauthorized            : return 401
        case .Forbidden               : return 403
        case .NotFound                : return 404
        case .InternalServerError     : return 500
        case .RAW(let code, _, _, _)  : return code
        }
    }
    
    func reasonPhrase() -> String {
        switch self {
        case .OK(_)                    : return "OK"
        case .Created                  : return "Created"
        case .Accepted                 : return "Accepted"
        case .MovedPermanently         : return "Moved Permanently"
        case .BadRequest               : return "Bad Request"
        case .Unauthorized             : return "Unauthorized"
        case .Forbidden                : return "Forbidden"
        case .NotFound                 : return "Not Found"
        case .InternalServerError      : return "Internal Server Error"
        case .RAW(_, let phrase, _, _) : return phrase
        }
    }
    
    func headers() -> [String: String] {
        var headers = ["Server" : "Swifter \(HttpServer.VERSION)"]
        switch self {
        case .OK(let body):
            switch body {
            case .Json(_)   : headers["Content-Type"] = "application/json"
            case .Html(_)   : headers["Content-Type"] = "text/html"
            default:break
            }
        case .MovedPermanently(let location):
            headers["Location"] = location
        case .RAW(_, _, let rawHeaders, _):
            if let rawHeaders = rawHeaders {
                for (k, v) in rawHeaders {
                    headers.updateValue(v, forKey: k)
                }
            }
        default:break
        }
        return headers
    }
    
    func content() -> (length: Int, writeClosure: ((HttpResponseBodyWriter) throws -> Void)?) {
        switch self {
        case .OK(let body)             : return body.content()
        case .RAW(_, _, _, let writer) : return (-1, writer)
        default                        : return (-1, nil)
        }
    }
}

/**
 Makes it possible to compare handler responses with '==', but
	ignores any associated values. This should generally be what
	you want. E.g.:
	
 let resp = handler(updatedRequest)
 if resp == .NotFound {
 print("Client requested not found: \(request.url)")
 }
 */

func==(inLeft: HttpResponse, inRight: HttpResponse) -> Bool {
    return inLeft.statusCode() == inRight.statusCode()
}


public class HttpRouter {
    
    private class Node {
        var nodes = [String: Node]()
        var handler: (HttpRequest -> HttpResponse)? = nil
    }
    
    private var rootNode = Node()
    
    public func routes() -> [String] {
        var routes = [String]()
        for (_, child) in rootNode.nodes {
            routes.appendContentsOf(routesForNode(child))
        }
        return routes
    }
    
    private func routesForNode(node: Node, prefix: String = "") -> [String] {
        var result = [String]()
        if node.handler != nil {
            result.append(prefix)
        }
        for (key, child) in node.nodes {
            result.appendContentsOf(routesForNode(child, prefix: prefix + "/" + key))
        }
        return result
    }
    
    public func register(method: String?, path: String, handler: (HttpRequest -> HttpResponse)?) {
        var pathSegments = stripQuery(path).split("/")
        if let method = method {
            pathSegments.insert(method, atIndex: 0)
        } else {
            pathSegments.insert("*", atIndex: 0)
        }
        var pathSegmentsGenerator = pathSegments.generate()
        inflate(&rootNode, generator: &pathSegmentsGenerator).handler = handler
    }
    
    public func route(method: String?, path: String) -> ([String: String], HttpRequest -> HttpResponse)? {
        if let method = method {
            let pathSegments = (method + "/" + stripQuery(path)).split("/")
            var pathSegmentsGenerator = pathSegments.generate()
            var params = [String:String]()
            if let handler = findHandler(&rootNode, params: &params, generator: &pathSegmentsGenerator) {
                return (params, handler)
            }
        }
        let pathSegments = ("*/" + stripQuery(path)).split("/")
        var pathSegmentsGenerator = pathSegments.generate()
        var params = [String:String]()
        if let handler = findHandler(&rootNode, params: &params, generator: &pathSegmentsGenerator) {
            return (params, handler)
        }
        return nil
    }
    
    private func inflate(inout node: Node, inout generator: IndexingGenerator<[String]>) -> Node {
        if let pathSegment = generator.next() {
            if let _ = node.nodes[pathSegment] {
                return inflate(&node.nodes[pathSegment]!, generator: &generator)
            }
            var nextNode = Node()
            node.nodes[pathSegment] = nextNode
            return inflate(&nextNode, generator: &generator)
        }
        return node
    }
    
    private func findHandler(inout node: Node, inout params: [String: String], inout generator: IndexingGenerator<[String]>) -> (HttpRequest -> HttpResponse)? {
        guard let pathToken = generator.next() else {
            return node.handler
        }
        let variableNodes = node.nodes.filter { $0.0.characters.first == ":" }
        if let variableNode = variableNodes.first {
            params[variableNode.0] = pathToken
            return findHandler(&node.nodes[variableNode.0]!, params: &params, generator: &generator)
        }
        if let _ = node.nodes[pathToken] {
            return findHandler(&node.nodes[pathToken]!, params: &params, generator: &generator)
        }
        if let _ = node.nodes["*"] {
            return findHandler(&node.nodes["*"]!, params: &params, generator: &generator)
        }
        return nil
    }
    
    private func stripQuery(path: String) -> String {
        if let path = path.split("?").first {
            return path
        }
        return path
    }
}


public class HttpServer: HttpServerIO {
    
    public static let VERSION = "1.0.7"
    
    private let router = HttpRouter()
    
    public override init() {
        self.DELETE = MethodRoute(method: "DELETE", router: router)
        self.UPDATE = MethodRoute(method: "UPDATE", router: router)
        self.HEAD   = MethodRoute(method: "HEAD", router: router)
        self.POST   = MethodRoute(method: "POST", router: router)
        self.GET    = MethodRoute(method: "GET", router: router)
        self.PUT    = MethodRoute(method: "PUT", router: router)
    }
    
    public var DELETE, UPDATE, HEAD, POST, GET, PUT: MethodRoute
    
    public subscript(path: String) -> (HttpRequest -> HttpResponse)? {
        set {
            router.register(nil, path: path, handler: newValue)
        }
        get { return nil }
    }
    
    public var routes: [String] {
        return router.routes()
    }
    
    override public func dispatch(method: String, path: String) -> ([String:String], HttpRequest -> HttpResponse) {
        if let result = router.route(method, path: path) {
            return result
        }
        return super.dispatch(method, path: path)
    }
    
    public struct MethodRoute {
        public let method: String
        public let router: HttpRouter
        public subscript(path: String) -> (HttpRequest -> HttpResponse)? {
            set {
                router.register(method, path: path, handler: newValue)
            }
            get { return nil }
        }
    }
}

#if os(Linux)
    import Glibc
    import NSLinux
#endif

public class HttpServerIO {
    
    private var listenSocket: Socket = Socket(socketFileDescriptor: -1)
    private var clientSockets: Set<Socket> = []
    private let clientSocketsLock = NSLock()
    
    public func start(listenPort: in_port_t = 8080) throws {
        stop()
        listenSocket = try Socket.tcpSocketForListen(listenPort)
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
            while let socket = try? self.listenSocket.acceptClientSocket() {
                self.lock(self.clientSocketsLock) {
                    self.clientSockets.insert(socket)
                }
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), {
                    self.handleConnection(socket)
                    self.lock(self.clientSocketsLock) {
                        self.clientSockets.remove(socket)
                    }
                })
            }
            self.stop()
        }
    }
    
    public func handleConnection(socket: Socket) {
        let address = try? socket.peername()
        let parser = HttpParser()
        while let request = try? parser.readHttpRequest(socket) {
            let request = request
            let (params, handler) = self.dispatch(request.method, path: request.path)
            request.address = address
            request.params = params
            let response = handler(request)
            var keepConnection = parser.supportsKeepAlive(request.headers)
            do {
                keepConnection = try self.respond(socket, response: response, keepAlive: keepConnection)
            } catch {
                print("Failed to send response: \(error)")
                break
            }
            if !keepConnection { break }
        }
        socket.release()
    }
    
    public func dispatch(method: String, path: String) -> ([String: String], HttpRequest -> HttpResponse) {
        return ([:], { _ in HttpResponse.NotFound })
    }
    
    public func stop() {
        listenSocket.release()
        lock(self.clientSocketsLock) {
            for socket in self.clientSockets {
                socket.shutdwn()
            }
            self.clientSockets.removeAll(keepCapacity: true)
        }
    }
    
    private func lock(handle: NSLock, closure: () -> ()) {
        handle.lock()
        closure()
        handle.unlock()
    }
    
    private struct InnerWriteContext: HttpResponseBodyWriter {
        let socket: Socket
        func write(data: [UInt8]) {
            try? socket.writeUInt8(data)
        }
    }
    
    private func respond(socket: Socket, response: HttpResponse, keepAlive: Bool) throws -> Bool {
        try socket.writeUTF8("HTTP/1.1 \(response.statusCode()) \(response.reasonPhrase())\r\n")
        
        let content = response.content()
        
        if content.length >= 0 {
            try socket.writeUTF8("Content-Length: \(content.length)\r\n")
        }
        
        if keepAlive && content.length != -1 {
            try socket.writeUTF8("Connection: keep-alive\r\n")
        }
        
        for (name, value) in response.headers() {
            try socket.writeUTF8("\(name): \(value)\r\n")
        }
        
        try socket.writeUTF8("\r\n")
        
        if let writeClosure = content.writeClosure {
            let context = InnerWriteContext(socket: socket)
            try writeClosure(context)
        }
        
        return keepAlive && content.length != -1
    }
}


#if os(Linux)
    import Glibc
#else
    import Foundation
#endif

/* Low level routines for POSIX sockets */

enum SocketError: ErrorType {
    case SocketCreationFailed(String)
    case SocketSettingReUseAddrFailed(String)
    case BindFailed(String)
    case ListenFailed(String)
    case WriteFailed(String)
    case GetPeerNameFailed(String)
    case ConvertingPeerNameFailed
    case GetNameInfoFailed(String)
    case AcceptFailed(String)
    case RecvFailed(String)
}

public class Socket: Hashable, Equatable {
    
    public class func tcpSocketForListen(port: in_port_t, maxPendingConnection: Int32 = SOMAXCONN) throws -> Socket {
        
        #if os(Linux)
            let socketFileDescriptor = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
        #else
            let socketFileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        #endif
        
        if socketFileDescriptor == -1 {
            throw SocketError.SocketCreationFailed(Socket.descriptionOfLastError())
        }
        
        var value: Int32 = 1
        if setsockopt(socketFileDescriptor, SOL_SOCKET, SO_REUSEADDR, &value, socklen_t(sizeof(Int32))) == -1 {
            let details = Socket.descriptionOfLastError()
            Socket.release(socketFileDescriptor)
            throw SocketError.SocketSettingReUseAddrFailed(details)
        }
        Socket.setNoSigPipe(socketFileDescriptor)
        
        #if os(Linux)
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = Socket.htonsPort(port)
            addr.sin_addr = in_addr(s_addr: in_addr_t(0))
            addr.sin_zero = (0, 0, 0, 0, 0, 0, 0, 0)
        #else
            var addr = sockaddr_in()
            addr.sin_len = __uint8_t(sizeof(sockaddr_in))
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = Socket.htonsPort(port)
            addr.sin_addr = in_addr(s_addr: inet_addr("0.0.0.0"))
            addr.sin_zero = (0, 0, 0, 0, 0, 0, 0, 0)
        #endif
        
        var bind_addr = sockaddr()
        memcpy(&bind_addr, &addr, Int(sizeof(sockaddr_in)))
        
        if bind(socketFileDescriptor, &bind_addr, socklen_t(sizeof(sockaddr_in))) == -1 {
            let details = Socket.descriptionOfLastError()
            Socket.release(socketFileDescriptor)
            throw SocketError.BindFailed(details)
        }
        
        if listen(socketFileDescriptor, maxPendingConnection ) == -1 {
            let details = Socket.descriptionOfLastError()
            Socket.release(socketFileDescriptor)
            throw SocketError.ListenFailed(details)
        }
        return Socket(socketFileDescriptor: socketFileDescriptor)
    }
    
    private let socketFileDescriptor: Int32
    
    init(socketFileDescriptor: Int32) {
        self.socketFileDescriptor = socketFileDescriptor
    }
    
    public var hashValue: Int { return Int(self.socketFileDescriptor) }
    
    public func release() {
        Socket.release(self.socketFileDescriptor)
    }
    
    public func shutdwn() {
        Socket.shutdwn(self.socketFileDescriptor)
    }
    
    public func acceptClientSocket() throws -> Socket {
        var addr = sockaddr()
        var len: socklen_t = 0
        let clientSocket = accept(self.socketFileDescriptor, &addr, &len)
        if clientSocket == -1 {
            throw SocketError.AcceptFailed(Socket.descriptionOfLastError())
        }
        Socket.setNoSigPipe(clientSocket)
        return Socket(socketFileDescriptor: clientSocket)
    }
    
    public func writeUTF8(string: String) throws {
        try writeUInt8([UInt8](string.utf8))
    }
    
    @warn_unused_result
    public func writeUInt8(data: [UInt8]) throws {
        try data.withUnsafeBufferPointer {
            var sent = 0
            while sent < data.count {
                #if os(Linux)
                    let s = send(self.socketFileDescriptor, $0.baseAddress + sent, Int(data.count - sent), Int32(MSG_NOSIGNAL))
                #else
                    let s = write(self.socketFileDescriptor, $0.baseAddress + sent, Int(data.count - sent))
                #endif
                if s <= 0 {
                    throw SocketError.WriteFailed(Socket.descriptionOfLastError())
                }
                sent += s
            }
        }
    }
    
    public func read() throws -> UInt8 {
        var buffer = [UInt8](count: 1, repeatedValue: 0)
        let next = recv(self.socketFileDescriptor as Int32, &buffer, Int(buffer.count), 0)
        if next <= 0 {
            throw SocketError.RecvFailed(Socket.descriptionOfLastError())
        }
        return buffer[0]
    }
    
    private static let CR = UInt8(13)
    private static let NL = UInt8(10)
    
    public func readLine() throws -> String {
        var characters: String = ""
        var n: UInt8 = 0
        repeat {
            n = try self.read()
            if n > Socket.CR { characters.append(Character(UnicodeScalar(n))) }
        } while n != Socket.NL
        return characters
    }
    
    public func peername() throws -> String {
        var addr = sockaddr(), len: socklen_t = socklen_t(sizeof(sockaddr))
        if getpeername(self.socketFileDescriptor, &addr, &len) != 0 {
            throw SocketError.GetPeerNameFailed(Socket.descriptionOfLastError())
        }
        var hostBuffer = [CChar](count: Int(NI_MAXHOST), repeatedValue: 0)
        if getnameinfo(&addr, len, &hostBuffer, socklen_t(hostBuffer.count), nil, 0, NI_NUMERICHOST) != 0 {
            throw SocketError.GetNameInfoFailed(Socket.descriptionOfLastError())
        }
        guard let name = String.fromCString(hostBuffer) else {
            throw SocketError.ConvertingPeerNameFailed
        }
        return name
    }
    
    private class func descriptionOfLastError() -> String {
        return String.fromCString(UnsafePointer(strerror(errno))) ?? "Error: \(errno)"
    }
    
    private class func setNoSigPipe(socket: Int32) {
        #if os(Linux)
            // There is no SO_NOSIGPIPE in Linux (nor some other systems). You can instead use the MSG_NOSIGNAL flag when calling send(),
            // or use signal(SIGPIPE, SIG_IGN) to make your entire application ignore SIGPIPE.
        #else
            // Prevents crashes when blocking calls are pending and the app is paused ( via Home button ).
            var no_sig_pipe: Int32 = 1
            setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, &no_sig_pipe, socklen_t(sizeof(Int32)))
        #endif
    }
    
    private class func shutdwn(socket: Int32) {
        #if os(Linux)
            shutdown(socket, Int32(SHUT_RDWR))
        #else
            Darwin.shutdown(socket, SHUT_RDWR)
        #endif
    }
    
    private class func release(socket: Int32) {
        #if os(Linux)
            shutdown(socket, Int32(SHUT_RDWR))
        #else
            Darwin.shutdown(socket, SHUT_RDWR)
        #endif
        close(socket)
    }
    
    private class func htonsPort(port: in_port_t) -> in_port_t {
        #if os(Linux)
            return htons(port)
        #else
            let isLittleEndian = Int(OSHostByteOrder()) == OSLittleEndian
            return isLittleEndian ? _OSSwapInt16(port) : port
        #endif
    }
}

public func==(socket1: Socket, socket2: Socket) -> Bool {
    return socket1.socketFileDescriptor == socket2.socketFileDescriptor
}


extension String {
    
    public func split(separator: Character) -> [String] {
        return self.characters.split { $0 == separator }.map(String.init)
    }
    
    public func split(maxSplit: Int = Int.max, separator: Character) -> [String] {
        return self.characters.split(maxSplit) { $0 == separator }.map(String.init)
    }
    
    public func replace(old: Character, new: Character) -> String {
        var buffer = [Character]()
        self.characters.forEach { buffer.append($0 == old ? new : $0) }
        return String(buffer)
    }
    
    public func unquote() -> String {
        var scalars = self.unicodeScalars
        if scalars.first == "\"" && scalars.last == "\"" && scalars.count >= 2 {
            scalars.removeFirst()
            scalars.removeLast()
            return String(scalars)
        }
        return self
    }
    
    public func trim() -> String {
        var scalars = self.unicodeScalars
        while let _ = unicodeScalarToUInt32Whitespace(scalars.first) { scalars.removeFirst() }
        while let _ = unicodeScalarToUInt32Whitespace(scalars.last) { scalars.removeLast() }
        return String(scalars)
    }
    
    public static func fromUInt8(array: [UInt8]) -> String {
        #if os(Linux)
            return String(data: NSData(bytes: array, length: array.count), encoding: NSUTF8StringEncoding)
        #else
            if let s = String(data: NSData(bytes: array, length: array.count), encoding: NSUTF8StringEncoding) {
                return s
            }
            return ""
        #endif
    }
    
    public func removePercentEncoding() -> String {
        var scalars = self.unicodeScalars
        var output = ""
        var bytesBuffer = [UInt8]()
        while let scalar = scalars.popFirst() {
            if scalar == "%" {
                let first = scalars.popFirst()
                let secon = scalars.popFirst()
                if let first = unicodeScalarToUInt32Hex(first), secon = unicodeScalarToUInt32Hex(secon) {
                    bytesBuffer.append(first*16+secon)
                } else {
                    if !bytesBuffer.isEmpty {
                        output.appendContentsOf(String.fromUInt8(bytesBuffer))
                        bytesBuffer.removeAll()
                    }
                    if let first = first { output.append(Character(first)) }
                    if let secon = secon { output.append(Character(secon)) }
                }
            } else {
                if !bytesBuffer.isEmpty {
                    output.appendContentsOf(String.fromUInt8(bytesBuffer))
                    bytesBuffer.removeAll()
                }
                output.append(Character(scalar))
            }
        }
        if !bytesBuffer.isEmpty {
            output.appendContentsOf(String.fromUInt8(bytesBuffer))
            bytesBuffer.removeAll()
        }
        return output
    }
    
    private func unicodeScalarToUInt32Whitespace(x: UnicodeScalar?) -> UInt8? {
        if let x = x {
            if x.value >= 9 && x.value <= 13 {
                return UInt8(x.value)
            }
            if x.value == 32 {
                return UInt8(x.value)
            }
        }
        return nil
    }
    
    private func unicodeScalarToUInt32Hex(x: UnicodeScalar?) -> UInt8? {
        if let x = x {
            if x.value >= 48 && x.value <= 57 {
                return UInt8(x.value) - 48
            }
            if x.value >= 97 && x.value <= 102 {
                return UInt8(x.value) - 87
            }
            if x.value >= 65 && x.value <= 70 {
                return UInt8(x.value) - 55
            }
        }
        return nil
    }
}
