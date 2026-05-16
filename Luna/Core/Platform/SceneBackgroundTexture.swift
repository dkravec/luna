import Foundation

#if os(iOS)
import UIKit
typealias SceneBackgroundTextureImage = UIImage
#elseif os(macOS)
import AppKit
typealias SceneBackgroundTextureImage = NSImage
#endif

enum SceneBackgroundTexture {
    enum Resolution {
        case full
        case mini

        var resourceName: String {
            switch self {
            case .full:
                return "milkyway_2020_8k"
            case .mini:
                return "milkyway_2020_2k"
            }
        }
    }

    static func image(for resolution: Resolution, bundle: Bundle = .main) -> SceneBackgroundTextureImage? {
        guard let url = bundle.url(
            forResource: resolution.resourceName,
            withExtension: "jpg",
            subdirectory: "Backgrounds"
        ) else {
            return nil
        }

#if os(iOS)
        return SceneBackgroundTextureImage(contentsOfFile: url.path)
#elseif os(macOS)
        return SceneBackgroundTextureImage(contentsOf: url)
#endif
    }
}
