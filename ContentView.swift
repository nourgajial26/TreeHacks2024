//
//  ContentView.swift
//  VisionOS_API
//
//  Created by Nour Gajial on 2/17/24.
//

import SwiftUI
import RealityKit
import Combine


struct ContentView: View {
    @StateObject private var viewModel = ImageViewModel()

    var body: some View {
        VStack {
            if let image = viewModel.image {
                image
                    .resizable()
                    .scaledToFit()
            } else {
                Text("Loading image...")
                    .padding()
            }
            
            Button(action: {
                Task {
                    await viewModel.loadImage()
                }
            }) {
                Text("Generate")
                    .padding()
                    .background(.black)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
    }
}



import Foundation

enum ImgError: Error {
    case badURL, invalidResponse, invalidData, serverError(String), generationFailed(String), timeout
}

struct ImageObj: Codable {
    let status: String
    let fileUrl: String?
    let id: Int?
    let errorMessage: String?
}

struct ImageRequestStatus: Codable {
    var request:  ImageObj
}

// Function to initiate the skybox generation request and check its status
func checkImgStatus() async throws -> ImageObj {
    print("Firing off image request.")
    let imageObj = try await imgPostReq()
//    print("Initial status check")

    guard let requestId = imageObj.id else {
        throw ImgError.invalidData
    }
    print("got requestID")
    var currentStatus = imageObj.status

    // Polling interval in seconds
    let pollingInterval = 5.0
    // Timeout in seconds
    let timeoutInterval = 300.0
    var elapsedTime = 0.0
    print("before while loop")
    while currentStatus == "pending" || currentStatus == "dispatched" || currentStatus == "processing" {
        // Wait for the polling interval
        try await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
        elapsedTime += pollingInterval
        
        // Check for timeout
        if elapsedTime >= timeoutInterval {
            throw ImgError.timeout
        }
        print("after if statement")
        // Check the status again
        let newStatusObj = try await imgGetReq(requestId: requestId)
        currentStatus = newStatusObj.request.status
        
        print("Current status: \(currentStatus)")

        if currentStatus == "complete" {
            return newStatusObj.request
        } else if currentStatus == "abort" || currentStatus == "error" {
            if let errorMessage = newStatusObj.request.errorMessage {
                throw ImgError.generationFailed(errorMessage)
            } else {
                throw ImgError.generationFailed("Generation was aborted or encountered an error without a specific message.")
            }
        }
    }

    // If the loop exits because the status is 'complete', return the final status object
    return try await imgGetReq(requestId: requestId).request
}

// Function to make the POST request
func imgPostReq() async throws -> ImageObj {
    guard let url = URL(string: "https://backend.blockadelabs.com/api/v1/skybox") else {
        throw ImgError.badURL
    }
    print("in Post rn")
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("cOnB3oc5RWGLAWt57gO80v6o5tNGN3xoCWSeXC2bxvRhUvwytGCs4T8uKkcp", forHTTPHeaderField: "x-api-key")
    print("middle of forming request")
    let json = ["prompt": "A beach in Santa Monica magical"]
    guard let jsonData = try? JSONSerialization.data(withJSONObject: json) else {
        throw ImgError.invalidData
    }
    request.httpBody = jsonData
    print("get data/response")
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        throw ImgError.invalidResponse
    }
    print("decoder")
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    print("converted to snakecase")
    let imageObj = try decoder.decode(ImageObj.self, from: data)
    print("about to return")
    print(imageObj)
    return imageObj
}

// Function to make the GET request
func imgGetReq(requestId: Int) async throws -> ImageRequestStatus {
    print("entered get")
    guard let url = URL(string: "https://backend.blockadelabs.com/api/v1/imagine/requests/\(requestId)") else {
        throw ImgError.badURL
    }
    print("in Get rn")
    var request = URLRequest(url: url)
    request.addValue("cOnB3oc5RWGLAWt57gO80v6o5tNGN3xoCWSeXC2bxvRhUvwytGCs4T8uKkcp", forHTTPHeaderField: "x-api-key")
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        throw ImgError.invalidResponse
    }
    print(data)
    print("get decoder")
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let statusObj = try decoder.decode(ImageRequestStatus.self, from: data)
    print(statusObj)
    return statusObj
}

#Preview(windowStyle: .automatic) {
    ContentView()
}
