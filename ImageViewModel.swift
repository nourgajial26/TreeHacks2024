import SwiftUI
import Foundation

class ImageViewModel: ObservableObject {
    @Published var image: Image? = nil

    // Function to load the image by initiating the generation and then fetching the image if successful
    func loadImage() async {
        do {
            // Replace `checkImgStatus` with your actual function to initiate and check the image status
            // Assume `checkImgStatus` returns an `ImageObj` with a status and optionally a fileUrl and errorMessage
            let imageObj = try await checkImgStatus() // Assuming this is your corrected function

            print("in loadImage rn")
            if imageObj.status == "complete", let urlString = imageObj.fileUrl {
                // Fetch and display the image
                await fetchImage(from: urlString)
            } else {
                // Handle error message if available, else print a generic message
                if let errorMessage = imageObj.errorMessage {
                    print("Error during image generation: \(errorMessage)")
                } else {
                    print("Image generation in progress or failed without an error message.")
                }
            }
        } catch {
            print("Error loading image: \(error)")
        }
    }

    // Function to fetch and update the UI with the image from the given URL
    private func fetchImage(from urlString: String) async {
        guard let url = URL(string: urlString) else {
            print("Invalid URL for image")
            return
        }
        print("in fetch rn")

        do {
            let (data, _) = try await URLSession.shared.data(from: url) // Only interested in data, not response
            guard let uiImage = UIImage(data: data) else {
                print("Failed to convert data into UIImage")
                return
            }
            // Update the UI on the main thread
            await MainActor.run {
                self.image = Image(uiImage: uiImage)
            }
        } catch {
            print("Error fetching image: \(error)")
        }
    }
}
