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
public typealias RequestMethod = Alamofire.Method
public typealias RequestParameterEncoding = Alamofire.ParameterEncoding

/**
    An API Route
*/
public protocol APIRoute {
    /**
        The HTTP Method for the route.
    */
    var method: RequestMethod { get }
    
    /**
        The encoding to use for parameters.
    */
    var encoding: RequestParameterEncoding { get }
    
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
    var requestConvertible: URLRequestConvertible? { get }
}

/**
    Struct which represents a request to an APIRoute
 */
public struct APIRouteRequest: APIRoute {
    public var method: RequestMethod
    public var encoding: RequestParameterEncoding
    public var path: String
    public var parameters: [String: AnyObject]?
    public var additionalHeaders: [String: String]?
    
    public init(method: RequestMethod, encoding: RequestParameterEncoding, path: String, parameters: [String: AnyObject]? = nil, additionalHeaders: [String: String]? = nil) {
        self.method = method
        self.encoding = encoding
        self.path = path
        self.parameters = parameters
        self.additionalHeaders = additionalHeaders
    }
}

/**
    Provides automatic URL request serialization with a provided url and APIRoute
 */
public struct APIRequestConvertible: URLRequestConvertible {
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

