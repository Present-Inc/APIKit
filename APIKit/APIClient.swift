//
//  APIClient.swift
//  APIKit
//
//  Created by Justin Makaila on 4/22/15.
//  Copyright (c) 2015 Present, Inc. All rights reserved.
//

import Foundation
import Alamofire

private var acceptableStatusCodeRange = 200..<400

public struct APIClient {
    public static var cookieStore = NSHTTPCookieStorage.sharedHTTPCookieStorage()
    
    public static var sharedHeaders: [NSObject: AnyObject] = {
        return Manager.sharedInstance.session.configuration.HTTPAdditionalHeaders ?? [:]
    }()
    
    public static func request(url: NSURL, route: APIRoute) -> Alamofire.Request? {
        let requestConvertible = APIRequestConvertible(requestUrl: url, route: route)
        return self.request(requestConvertible)
    }
    
    public static func request(request: APIRequest) -> Alamofire.Request? {
        return self.request(request.requestConvertible)
    }
    
    public static func request(requestConvertible: URLRequestConvertible?) -> Alamofire.Request? {
        if let requestConvertible = requestConvertible {
            let request = APIClient()
                .request(requestConvertible)
                .validate(statusCode: acceptableStatusCodeRange)
            
            // TODO: Add a logger
            println(request)
            
            return request
        }
        
        return nil
    }
    
    public var manager: Alamofire.Manager
    
    public init() {
        self.init(headers: APIClient.sharedHeaders, cookiePolicy: .Always)
    }
    
    public init(headers: [NSObject: AnyObject], cookiePolicy: NSHTTPCookieAcceptPolicy) {
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        configuration.HTTPAdditionalHeaders = headers
        configuration.HTTPCookieAcceptPolicy = cookiePolicy
        configuration.HTTPCookieStorage = APIClient.cookieStore
        
        manager = Alamofire.Manager(configuration: configuration)
    }
    
    public func request(requestConvertible: URLRequestConvertible) -> Alamofire.Request {
        return manager.request(requestConvertible)
    }
}

// MARK: - Alamofire.Request Extensions

/**
    Parses JSON using JSONParser
 */
func parseJSONResponse<T, P: JSONParser where P.T == T>(json: JSON, parser: P) -> T? {
    if parser.isValid(json) {
        return parser.parseJSON(json)
    }
    
    return nil
}

// MARK: - Serializer for Swifty JSON

extension Alamofire.Request {
    
    /**
    Adds a handler to be called once the request has finished.
    
    :param: completionHandler A closure to be executed once the request has finished. The closure takes 4 arguments: the URL request, the URL response, if one was received, the SwiftyJSON enum, if one could be created from the URL response and data, and any error produced while creating the SwiftyJSON enum.
    
    :returns: The request.
    */
    internal func responseSwiftyJSON(completionHandler: (NSURLRequest, NSHTTPURLResponse?, JSON, NSError?) -> Void) -> Self {
        return responseSwiftyJSON(queue: nil, options: NSJSONReadingOptions.AllowFragments, completionHandler: completionHandler)
    }
    
    /**
    Adds a handler to be called once the request has finished.
    
    :param: queue The queue on which the completion handler is dispatched.
    :param: options The JSON serialization reading options. `.AllowFragments` by default.
    :param: completionHandler A closure to be executed once the request has finished. The closure takes 4 arguments: the URL request, the URL response, if one was received, the SwiftyJSON enum, if one could be created from the URL response and data, and any error produced while creating the SwiftyJSON enum.
    
    :returns: The request.
    */
    internal func responseSwiftyJSON(queue: dispatch_queue_t? = nil, options: NSJSONReadingOptions = .AllowFragments, completionHandler: (NSURLRequest, NSHTTPURLResponse?, JSON, NSError?) -> Void) -> Self {
        
        return response(queue: queue, serializer: Request.JSONResponseSerializer(options: options), completionHandler: { (request, response, object, error) -> Void in
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                
                let responseJSON = (object == nil) ? JSON.nullJSON : JSON(object!)
                
                dispatch_async(queue ?? dispatch_get_main_queue(), {
                    completionHandler(self.request, self.response, responseJSON, error)
                })
            })
        })
    }
    
    internal func responseJSONParser<T, P: JSONParser where T == P.T>(parser: P, completionHandler: (NSURLRequest, NSHTTPURLResponse?, T?, NSError?) -> Void) -> Self {
        return responseSwiftyJSON({ request, response, json, error in
            completionHandler(request, response, parseJSONResponse(json, parser), error)
        })
    }
}