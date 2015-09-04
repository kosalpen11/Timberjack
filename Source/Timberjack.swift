import Foundation

let TimberjackRequestHandledKey = "Timberjack"
let TimberjackRequestTimeKey = "TimberjackRequestTime"

public enum Style {
    case Verbose
    case Light
}

public class Timberjack: NSURLProtocol {
    var connection: NSURLConnection?
    var data: NSMutableData?
    var response: NSURLResponse?
    
    public static var logStyle: Style = .Verbose
    
    public class func register() {
        self.registerClass(self)
    }
    
    public class func unregister() {
        self.unregisterClass(self)
    }
    
    //MARK: - NSURLProtocol
    
    public override class func canInitWithRequest(request: NSURLRequest) -> Bool {
        guard self.propertyForKey(TimberjackRequestHandledKey, inRequest: request) != nil else {
            return false
        }
        
        return true
    }
    
    public override class func canonicalRequestForRequest(request: NSURLRequest) -> NSURLRequest {
        return request
    }
    
    public override class func requestIsCacheEquivalent(a: NSURLRequest, toRequest b: NSURLRequest) -> Bool {
        return super.requestIsCacheEquivalent(a, toRequest: b)
    }

    public override func startLoading() {
        guard let newRequest = request.mutableCopy() as? NSMutableURLRequest else { return }
        
        Timberjack.setProperty(true, forKey: TimberjackRequestHandledKey, inRequest: newRequest)
        Timberjack.setProperty(NSDate(), forKey: TimberjackRequestTimeKey, inRequest: newRequest)
        
        connection = NSURLConnection(request: newRequest, delegate: self)
        
        logRequest(newRequest)
    }
    
    public override func stopLoading() {
        connection?.cancel()
        connection = nil
    }
    
    // MARK: NSURLConnectionDelegate
    
    func connection(connection: NSURLConnection!, didReceiveResponse response: NSURLResponse!) {
        let policy = NSURLCacheStoragePolicy(rawValue: request.cachePolicy.rawValue) ?? .NotAllowed
        client?.URLProtocol(self, didReceiveResponse: response, cacheStoragePolicy: policy)
        
        self.response = response
        self.data = NSMutableData()
    }
    
    func connection(connection: NSURLConnection!, didReceiveData data: NSData!) {
        client?.URLProtocol(self, didLoadData: data)
        self.data?.appendData(data)
    }
    
    func connectionDidFinishLoading(connection: NSURLConnection!) {
        client?.URLProtocolDidFinishLoading(self)
        
        if let response = response {
            logResponse(response, data: data)
        }
    }
    
    func connection(connection: NSURLConnection!, didFailWithError error: NSError!) {
        client?.URLProtocol(self, didFailWithError: error)
        logError(error)
    }
    
    //MARK: - Logging
    
    public func logDivider() {
        print("---------------------")
    }
    
    public func logError(error: NSError) {
        logDivider()
        
        print("Error: \(error.localizedDescription)")
        
        if Timberjack.logStyle == .Verbose {
            if let reason = error.localizedFailureReason {
                print("Reason: \(reason)")
            }
            
            if let suggestion = error.localizedRecoverySuggestion {
                print("Suggestion: \(suggestion)")
            }
        }
    }
    
    public func logRequest(request: NSURLRequest) {
        logDivider()
        
        if let url = request.URL?.absoluteString {
            print("Request: \(request.HTTPMethod) \(url)")
        }
        
        if Timberjack.logStyle == .Verbose {
            if let headers = request.allHTTPHeaderFields {
                self.logHeaders(headers)
            }
        }
    }
    
    public func logResponse(response: NSURLResponse, data: NSData? = nil) {
        logDivider()
        
        if let url = response.URL?.absoluteString {
            print("Response: \(url)")
        }
        
        if let httpResponse = response as? NSHTTPURLResponse {
            let localisedStatus = NSHTTPURLResponse.localizedStringForStatusCode(httpResponse.statusCode).capitalizedString
            print("Status: \(httpResponse.statusCode) - \(localisedStatus)")
        }
        
        if Timberjack.logStyle == .Verbose {
            if let headers = (response as? NSHTTPURLResponse)?.allHeaderFields as? [String: AnyObject] {
                self.logHeaders(headers)
            }
            
            if let startDate = Timberjack.propertyForKey(TimberjackRequestTimeKey, inRequest: request) as? NSDate {
                let difference = startDate.timeIntervalSinceNow
                print("Duration: \(difference) secs")
            }
            
            guard let data = data else { return }
            
            do {
                let json = try NSJSONSerialization.JSONObjectWithData(data, options: .MutableContainers)
                let pretty = try NSJSONSerialization.dataWithJSONObject(json, options: .PrettyPrinted)
                
                if let string = NSString(data: pretty, encoding: NSUTF8StringEncoding) {
                    print("JSON: \(string)")
                }
            }
                
            catch {
                if let string = NSString(data: data, encoding: NSUTF8StringEncoding) {
                    print("Data: \(string)")
                }
            }
        }
    }
    
    public func logHeaders(headers: [String: AnyObject]) {
        print("Headers: [")
        for (key, value) in headers {
            print("  \(key) : \(value)")
        }
        print("]")
    }
}
