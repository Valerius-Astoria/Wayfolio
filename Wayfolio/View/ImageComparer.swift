//
//  ImageComparer.swift
//  Wayfolio
//
//  Created by ZAKA on 11/20/26.
//

//
//  ImageComparer.swift
//  Wayfolio
//
//  Created by ZAKA on 11/20/26.
//

import SwiftUI
import PhotosUI
import Vision

struct ImageComparer: View {
    @State private var selectedSourceItem: PhotosPickerItem?
    @State private var selectedSourceImage: UIImage?
    @State private var selectedNewItem: PhotosPickerItem?
    @State private var selectedNewImage: UIImage?
    
    private let similarityComparer = SimilarityComparer()
    
    var body: some View {
        Form {
            Section("Source") {
                if let selectedSourceImage {
                    Image(uiImage: selectedSourceImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                PhotosPicker(
                    selectedSourceImage == nil ? "Select an image" : "Change image",
                    selection: $selectedSourceItem,
                    matching: .images
                )
            }
            .onChange(of: selectedSourceItem) {
                Task {
                    if let data = try? await selectedSourceItem?.loadTransferable(type: Data.self) {
                        selectedSourceImage = UIImage(data: data)
                    }
                }
            }
            
            Section("New") {
                if let selectedNewImage {
                    Image(uiImage: selectedNewImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                PhotosPicker(
                    selectedNewImage == nil ? "Select an image" : "Change image",
                    selection: $selectedNewItem,
                    matching: .images
                )
            }
            .onChange(of: selectedNewItem) {
                Task {
                    if let data = try? await selectedNewItem?.loadTransferable(type: Data.self) {
                        selectedNewImage = UIImage(data: data)
                    }
                }
            }
            
            Section("Similarity") {
                if let source = selectedSourceImage, let new = selectedNewImage {
                    if let distance = similarityComparer.compare(source: source, new: new) {
                        Text(String(format: "Distance: %.4f", distance))
                    } else {
                        Text("Could not compute similarity")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Select both images to compare")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct SimilarityComparer {
    func compare(source: UIImage, new: UIImage) -> Float? {
        guard let sourcePrint = featurePrint(from: source),
              let newPrint = featurePrint(from: new) else {
            return nil
        }
        
        var distance: Float = 0
        do {
            try sourcePrint.computeDistance(&distance, to: newPrint)
            return distance
        } catch {
            print("Distance computation failed: \(error)")
            return nil
        }
    }
    
    private func featurePrint(from image: UIImage) -> VNFeaturePrintObservation? {
        guard let cgImage = image.cgImage else { return nil }
        
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            return request.results?.first
        } catch {
            print("Feature print failed: \(error)")
            return nil
        }
    }
}

#Preview {
    ImageComparer()
}
