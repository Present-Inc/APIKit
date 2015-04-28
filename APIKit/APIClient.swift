//
//  APIClient.swift
//  APIKit
//
//  Created by Justin Makaila on 4/22/15.
//  Copyright (c) 2015 Present, Inc. All rights reserved.
//

import Foundation
import Alamofire
import Result

extension Alamofire.Manager {
    func request(url: NSURL, route: APIRoute) -> Alamofire.Request {
        let requestConvertible = APIRequestConvertible(requestUrl: url, route: route)
        return self.request(requestConvertible)
    }
    
    func request(request: APIRequest) -> Alamofire.Request {
        return self.request(request.requestConvertible)
    }
}

public struct APIClient {
    public static var acceptableStatusCodeRange: Range<Int> = 200..<400
    
    public static var sharedHeaders: [NSObject: AnyObject] = {
        return Manager.sharedInstance.session.configuration.HTTPAdditionalHeaders ?? [:]
    }()
    
    public static func request(url: NSURL, route: APIRoute) -> Alamofire.Request {
        return Manager.sharedInstance.request(url, route: route)
    }
    
    public static func request(request: APIRequest) -> Alamofire.Request {
        return Manager.sharedInstance.request(request)
    }
    
    public static func request(requestConvertible: URLRequestConvertible) -> Alamofire.Request {
        let request = Manager.sharedInstance
            .request(requestConvertible)
            .validate(statusCode: APIClient.acceptableStatusCodeRange)
        
        println(request)
        
        return request
    }
    
    public var manager: Alamofire.Manager
    
    public init(sessionConfiguration: NSURLSessionConfiguration) {
        manager = Alamofire.Manager(configuration: sessionConfiguration)
    }
    
    public init() {
        self.init(headers: APIClient.sharedHeaders,  cookiePolicy: .Always)
    }
    
    public init(headers: [NSObject: AnyObject], cookiePolicy: NSHTTPCookieAcceptPolicy, cookieStorage: NSHTTPCookieStorage? = nil) {
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        configuration.HTTPAdditionalHeaders = headers
        configuration.HTTPCookieAcceptPolicy = cookiePolicy
        configuration.HTTPCookieStorage = cookieStorage
        
        self.init(sessionConfiguration: configuration)
        
    }
    
    public func request(requestConvertible: URLRequestConvertible) -> Alamofire.Request {
        return manager.request(requestConvertible)
    }
    
    public func request(url: NSURL, route: APIRoute) -> Alamofire.Request {
        return manager.request(url, route: route)
    }
    
    public func request(request: APIRequest) -> Alamofire.Request {
        return manager.request(request)
    }
}

// MARK: - Alamofire.Request Extensions

/**
    Parses JSON using JSONParser
 */
public func parseJSONResponse<T, P: JSONParser where P.T == T>(json: JSON, parser: P) -> Result<T, NSError> {
    if parser.isValid(json) {
        return Result.success(parser.parseJSON(json))
    }
    
    let error = NSError(domain: "tv.present.APIKit.parseJSONResponse", code: -1, userInfo: [
        NSLocalizedDescriptionKey: "JSON did not pass validation"
    ])
    
    return Result.failure(error)
}

// MARK: - Response serializers

extension Alamofire.Request {
    /**
        Adds a handler to be called once the request has finished.
        
        :param: completionHandler A closure to be executed once the request has finished. The closure takes 4 arguments: the URL request, the URL response, if one was received, the SwiftyJSON enum, if one could be created from the URL response and data, and any error produced while creating the SwiftyJSON enum.
        
        :returns: The request.
    */
    public func responseSwiftyJSON(completionHandler: (NSURLRequest, NSHTTPURLResponse?, JSON, NSError?) -> Void) -> Self {
        return responseSwiftyJSON(queue: nil, options: NSJSONReadingOptions.AllowFragments, completionHandler: completionHandler)
    }
    
    /**
        Adds a handler to be called once the request has finished.
        
        :param: queue The queue on which the completion handler is dispatched.
        :param: options The JSON serialization reading options. `.AllowFragments` by default.
        :param: completionHandler A closure to be executed once the request has finished. The closure takes 4 arguments: the URL request, the URL response, if one was received, the SwiftyJSON enum, if one could be created from the URL response and data, and any error produced while creating the SwiftyJSON enum.
        
        :returns: The request.
    */
    public func responseSwiftyJSON(queue: dispatch_queue_t? = dispatch_get_main_queue(), options: NSJSONReadingOptions = .AllowFragments, completionHandler: (NSURLRequest, NSHTTPURLResponse?, JSON, NSError?) -> Void) -> Self {
        let serializer = Request.JSONResponseSerializer(options: options)
        return response(
            queue: queue,
            serializer: serializer,
            completionHandler: { (request, response, object, error) -> Void in
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                    let json = (object == nil) ? JSON.nullJSON : JSON(object!)
                    dispatch_async(queue ?? dispatch_get_main_queue()) {
                        completionHandler(self.request, self.response, json, error)
                    }
                }
            }
        )
    }
    
    public func resultSwiftyJSON(queue: dispatch_queue_t? = dispatch_get_main_queue(), options: NSJSONReadingOptions? = .AllowFragments, completionHandler: (Result<JSON, NSError>) -> Void) -> Self {
        let serializer = Request.JSONResponseSerializer(options: options!)
        
        return response(
            queue: queue,
            serializer: serializer,
            completionHandler: { (request, response, object, error) -> Void in
                if let object: AnyObject = object {
                    completionHandler(Result<JSON, NSError>.success(JSON(object)))
                } else if let error = error {
                    completionHandler(Result<JSON, NSError>.failure(error))
                }
            }
        )
    }
    
    public func responseJSONParser<T, P: JSONParser where T == P.T>(parser: P, completionHandler: (NSURLRequest, NSHTTPURLResponse?, T?, NSError?) -> Void) -> Self {
        return responseSwiftyJSON({ (request: NSURLRequest, response: NSHTTPURLResponse?, json: JSON, error: NSError?) -> Void in
            if let error = error {
                completionHandler(request, response, nil, error)
            }
            
            let result = parseJSONResponse(json, parser)
            
            if let object = result.value {
                completionHandler(request, response, object, nil)
            } else if let error = result.error {
                completionHandler(request, response, nil, error)
            } else {
                completionHandler(request, response, nil, nil)
            }
        })
    }
    
    public func resultJSONParser<T, P: JSONParser where T == P.T>(parser: P, completionHandler: (Result<T, NSError>) -> Void) -> Self {
        return resultSwiftyJSON(completionHandler: { result in
            if let value = result.value {
                completionHandler(parseJSONResponse(value, parser))
            } else if let error = result.error {
                completionHandler(Result.failure(error))
            }
        })
    }
}