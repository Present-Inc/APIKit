//
//  APITypes.swift
//  APIKit
//
//  Created by Justin Makaila on 4/22/15.
//  Copyright (c) 2015 Present, Inc. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

public typealias JSON = SwiftyJSON.JSON
public typealias APIRequestMethod = Alamofire.Method
public typealias APIRequestParameterEncoding = Alamofire.ParameterEncoding
public typealias APIRequestURLConvertible = Alamofire.URLRequestConvertible

/**
    An API Route
*/
public protocol APIRoute {
    /**
        The HTTP Method for the route.
    */
    var method: APIRequestMethod { get }
    
    /**
        The encoding to use for parameters.
    */
    var encoding: APIRequestParameterEncoding { get }
    
    /**
        The path of the route.
    */
    var path: String { get }
    
    /**
        The parameters for the route.
    */
    var parameters: [String: AnyObject]? { get }
    
    /**
        Additional headers to be applied for the route
     */
    var additionalHeaders: [String: String]? { get }
}

/**
    Adds support for URLRequestConvertible within an APIRoute
 */
public protocol APIRequest: APIRoute {
    var requestConvertible: APIRequestURLConvertible? { get }
}

/**
    Struct which represents a request to an APIRoute
 */
public struct APIRouteRequest: APIRoute {
    public var method: APIRequestMethod
    public var encoding: APIRequestParameterEncoding
    public var path: String
    public var parameters: [String: AnyObject]?
    public var additionalHeaders: [String: String]?
    
    public init(method: APIRequestMethod, encoding: APIRequestParameterEncoding, path: String, parameters: [String: AnyObject]? = nil, additionalHeaders: [String: String]? = nil) {
        self.method = method
        self.encoding = encoding
        self.path = path
        self.parameters = parameters
        self.additionalHeaders = additionalHeaders
    }
}

extension APIRouteRequest: Printable {
    public var description: String {
        var description: String = "\(method.rawValue) /\(path)\n"
        
        if let headers = additionalHeaders {
            for (key, value) in headers {
                description += "\(key): \(value)"
            }
            
            description += "\n"
        }
        
        if let parameters = parameters {
            description += "\(parameters)"
        }
        
        return description
    }
}

/**
    Provides automatic URL request serialization with a provided url and APIRoute
 */
public struct APIRequestConvertible: APIRequestURLConvertible {
    let requestUrl: NSURL
    let route: APIRoute
    
    public init(requestUrl: NSURL, route: APIRoute) {
        self.requestUrl = requestUrl
        self.route = route
    }
    
    public var URLRequest: NSURLRequest {
        let url = requestUrl.URLByAppendingPathComponent(route.path)
        
        // Create a request with `requestUrl`, returning cached data if available, with a 15 second timeout.
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = route.method.rawValue
        
        if let additionalHeaders = route.additionalHeaders {
            for (key, value) in additionalHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        return route.encoding.encode(request, parameters: route.parameters).0
    }
}

// MARK: - JSON Types

// MARK: JSON Parsing

public protocol JSONParserType {
    typealias T
    
    func parseJSON(json: JSON) -> T
}

// MARK: JSON Validation

public protocol JSONValidatorType {
    func isValid(json: JSON) -> Bool
}

public protocol JSONParser: JSONValidatorType, JSONParserType { }

// MARK: JSON Serialization

public protocol JSONSerializerType {
    func serializeJSON() -> JSON
}

