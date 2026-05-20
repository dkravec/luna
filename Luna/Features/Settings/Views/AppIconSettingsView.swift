import SwiftUI
import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum AppIconChoice: String, CaseIterable, Identifiable {
    case current
    case legacy2019

    var id: String { rawValue }

    var title: String {
        switch self {
        case .current:
            return "Current"
        case .legacy2019:
            return "2019"
        }
    }

    var subtitle: String {
        switch self {
        case .current:
            return "The default Luna app icon"
        case .legacy2019:
            return "The classic Luna icon from the existing resource set"
        }
    }

    var alternateIconName: String? {
        switch self {
        case .current:
            return nil
        case .legacy2019:
            return "LunaLegacy"
        }
    }

    init(iconName: String?) {
        self = Self.allCases.first { $0.alternateIconName == iconName } ?? .current
    }
}

struct AppIconSettingsView: View {
    let selectedChoice: AppIconChoice
    let onSelect: (AppIconChoice) -> Void

    @State private var currentChoice: AppIconChoice

    init(selectedChoice: AppIconChoice, onSelect: @escaping (AppIconChoice) -> Void) {
        self.selectedChoice = selectedChoice
        self.onSelect = onSelect
        _currentChoice = State(initialValue: selectedChoice)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.section) {
                PageHeader(
                    title: "Choose App Icon",
                    subtitle: appIconSupportSubtitle
                )

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(AppIconChoice.allCases) { choice in
                        Button {
                            currentChoice = choice
                            onSelect(choice)
                            Haptics.selection()
                        } label: {
                            AppIconChoiceCard(choice: choice, isSelected: choice == currentChoice)
                        }
                        .buttonStyle(.plain)
#if os(iOS)
                        .disabled(!UIApplication.shared.supportsAlternateIcons)
#else
                        .disabled(choice != .current)
#endif
                    }
                }
            }
            .screenContentPadding()
        }
        .navigationTitle("App Icon")
    }

    private var appIconSupportSubtitle: String {
#if os(iOS)
        UIApplication.shared.supportsAlternateIcons
            ? "Pick the icon Luna uses on your Home Screen."
            : "Alternate icons are unavailable on this device."
#else
        "macOS uses the bundled app icon."
#endif
    }
}

private struct AppIconChoiceCard: View {
    let choice: AppIconChoice
    let isSelected: Bool

    var body: some View {
        Card(isSelected: isSelected) {
            VStack(alignment: .center, spacing: 10) {
                Text(isSelected ? "Selected" : " ")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.clear)
                    .frame(height: 16)

                iconPreview
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)

                Text(choice.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(choice.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 170, alignment: .top)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(choice.title), \(choice.subtitle)\(isSelected ? ", selected" : "")")
    }

    @ViewBuilder
    private var iconPreview: some View {
        switch choice {
        case .current:
            LunaCurrentIconPreview()
        case .legacy2019:
            Image("LunaLegacyIcon")
                .resizable()
                .scaledToFit()
        }
    }
}

private struct LunaCurrentIconPreview: View {
    @State private var document = LunaIconDocument.loadCurrent()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: document.gradientColors,
                    startPoint: document.gradientStart,
                    endPoint: document.gradientEnd
                )

                ForEach(document.layers) { layer in
                    LunaIconLayerView(layer: layer)
                        .scaleEffect(layer.scale)
                        .offset(
                            x: layer.translation.width * geometry.size.width / document.canvasSize.width,
                            y: layer.translation.height * geometry.size.height / document.canvasSize.height
                        )
                        .opacity(layer.opacity)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct LunaIconLayerView: View {
    let layer: LunaIconLayer

    var body: some View {
        GeometryReader { geometry in
            switch layer.content {
            case .paths(let paths):
                ZStack {
                    ForEach(paths.indices, id: \.self) { index in
                        LunaSVGPathShape(commands: paths[index].commands, viewBox: paths[index].viewBox)
                            .fill(paths[index].fill)
                    }
                }
            case .embeddedImage(let image):
                image.image
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: geometry.size.width * image.frame.width / image.viewBox.width,
                        height: geometry.size.height * image.frame.height / image.viewBox.height
                    )
                    .offset(
                        x: geometry.size.width * image.frame.minX / image.viewBox.width,
                        y: geometry.size.height * image.frame.minY / image.viewBox.height
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }
}

private struct LunaSVGPathShape: Shape {
    let commands: [LunaSVGPathCommand]
    let viewBox: CGSize

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let scaleX = rect.width / viewBox.width
        let scaleY = rect.height / viewBox.height

        for command in commands {
            switch command {
            case .move(let point):
                path.move(to: CGPoint(x: point.x * scaleX, y: point.y * scaleY))
            case .line(let point):
                path.addLine(to: CGPoint(x: point.x * scaleX, y: point.y * scaleY))
            case .close:
                path.closeSubpath()
            }
        }

        return path
    }
}

private struct LunaIconDocument {
    var gradientColors: [Color]
    var gradientStart: UnitPoint
    var gradientEnd: UnitPoint
    var layers: [LunaIconLayer]
    var canvasSize: CGSize

    static func loadCurrent() -> LunaIconDocument {
        guard
            let iconURL = Bundle.main.url(forResource: "Luna", withExtension: "icon"),
            let data = try? Data(contentsOf: iconURL.appendingPathComponent("icon.json")),
            let source = try? JSONDecoder().decode(LunaIconSource.self, from: data)
        else {
            return fallback
        }

        let layers = source.groups
            .flatMap(\.layers)
            .compactMap { layer -> LunaIconLayer? in
                let assetURL = iconURL.appendingPathComponent("Assets").appendingPathComponent(layer.imageName)

                if let image = LunaEmbeddedSVGImage.load(from: assetURL) {
                    return LunaIconLayer(
                        content: .embeddedImage(image),
                        opacity: layer.opacity ?? 1,
                        scale: layer.position?.scale ?? 1,
                        translation: layer.position?.translation ?? .zero
                    )
                }

                let paths = LunaSVGPathLayer.load(from: assetURL)
                guard !paths.isEmpty else { return nil }

                return LunaIconLayer(
                    content: .paths(paths),
                    opacity: layer.opacity ?? 1,
                    scale: layer.position?.scale ?? 1,
                    translation: layer.position?.translation ?? .zero
                )
            }

        return LunaIconDocument(
            gradientColors: source.fill.linearGradient.map(Color.init(iconColorString:)),
            gradientStart: UnitPoint(x: source.fill.orientation.start.x, y: source.fill.orientation.start.y),
            gradientEnd: UnitPoint(x: source.fill.orientation.stop.x, y: source.fill.orientation.stop.y),
            layers: layers.isEmpty ? fallback.layers : layers,
            canvasSize: CGSize(width: 1080, height: 1080)
        )
    }

    private static let fallback = LunaIconDocument(
        gradientColors: [
            Color(red: 0.06889, green: 0.06889, blue: 0.06889),
            Color(red: 0.10154, green: 0.23721, blue: 0.44371)
        ],
        gradientStart: UnitPoint(x: 0.5, y: 0),
        gradientEnd: UnitPoint(x: 0.5, y: 0.7),
        layers: [],
        canvasSize: CGSize(width: 1080, height: 1080)
    )
}

private struct LunaIconLayer: Identifiable {
    let id = UUID()
    let content: LunaIconLayerContent
    let opacity: Double
    let scale: CGFloat
    let translation: CGSize
}

private enum LunaIconLayerContent {
    case paths([LunaSVGPathLayer])
    case embeddedImage(LunaEmbeddedSVGImage)
}

private struct LunaSVGPathLayer {
    let fill: Color
    let viewBox: CGSize
    let commands: [LunaSVGPathCommand]

    static func load(from url: URL) -> [LunaSVGPathLayer] {
        guard
            let svg = try? String(contentsOf: url),
            let viewBox = svg.viewBoxSize
        else {
            return []
        }

        return svg.matches(pattern: #"<path[^>]*fill="([^"]+)"[^>]*d="([^"]+)""#).compactMap { match in
            guard match.count == 3 else { return nil }
            return LunaSVGPathLayer(
                fill: Color(hexString: match[1]),
                viewBox: viewBox,
                commands: LunaSVGPathCommand.parse(match[2])
            )
        }
    }
}

private struct LunaEmbeddedSVGImage {
    let image: Image
    let viewBox: CGSize
    let frame: CGRect

    static func load(from url: URL) -> LunaEmbeddedSVGImage? {
        guard
            let svg = try? String(contentsOf: url),
            let viewBox = svg.viewBoxSize,
            let match = svg.matches(pattern: #"<image[^>]*x="([^"]+)"[^>]*y="([^"]+)"[^>]*width="([^"]+)"[^>]*height="([^"]+)"[^>]*href="data:image/png;base64,\s*([^"]+)""#).first,
            match.count == 6,
            let x = Double(match[1]),
            let y = Double(match[2]),
            let width = Double(match[3]),
            let height = Double(match[4]),
            let data = Data(base64Encoded: match[5].replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)),
            let image = Image(platformImageData: data)
        else {
            return nil
        }

        return LunaEmbeddedSVGImage(
            image: image,
            viewBox: viewBox,
            frame: CGRect(x: x, y: y, width: width, height: height)
        )
    }
}

private enum LunaSVGPathCommand {
    case move(CGPoint)
    case line(CGPoint)
    case close

    static func parse(_ pathData: String) -> [LunaSVGPathCommand] {
        var tokens: [String] = []
        var current = ""

        for character in pathData {
            if character.isLetter {
                if !current.isEmpty {
                    tokens.append(current)
                    current.removeAll()
                }
                tokens.append(String(character))
            } else if character.isWhitespace || character == "," {
                if !current.isEmpty {
                    tokens.append(current)
                    current.removeAll()
                }
            } else {
                current.append(character)
            }
        }

        if !current.isEmpty {
            tokens.append(current)
        }

        var commands: [LunaSVGPathCommand] = []
        var index = 0
        var activeCommand: String?

        while index < tokens.count {
            let token = tokens[index]
            if token == "M" || token == "L" || token == "Z" {
                activeCommand = token
                index += 1
                if token == "Z" {
                    commands.append(.close)
                }
                continue
            }

            guard
                let command = activeCommand,
                index + 1 < tokens.count,
                let x = Double(tokens[index]),
                let y = Double(tokens[index + 1])
            else {
                index += 1
                continue
            }

            let point = CGPoint(x: x, y: y)
            commands.append(command == "M" ? .move(point) : .line(point))
            activeCommand = command == "M" ? "L" : command
            index += 2
        }

        return commands
    }
}

private struct LunaIconSource: Decodable {
    let fill: Fill
    let groups: [Group]

    struct Fill: Decodable {
        let linearGradient: [String]
        let orientation: Orientation

        enum CodingKeys: String, CodingKey {
            case linearGradient = "linear-gradient"
            case orientation
        }
    }

    struct Orientation: Decodable {
        let start: Point
        let stop: Point
    }

    struct Point: Decodable {
        let x: Double
        let y: Double
    }

    struct Group: Decodable {
        let layers: [Layer]
    }

    struct Layer: Decodable {
        let imageName: String
        let opacity: Double?
        let position: Position?

        enum CodingKeys: String, CodingKey {
            case imageName = "image-name"
            case opacity
            case position
        }
    }

    struct Position: Decodable {
        let scale: CGFloat?
        private let translationInPoints: [CGFloat]?

        var translation: CGSize {
            CGSize(
                width: translationInPoints?.first ?? 0,
                height: translationInPoints?.dropFirst().first ?? 0
            )
        }

        enum CodingKeys: String, CodingKey {
            case scale
            case translationInPoints = "translation-in-points"
        }
    }
}

private extension Image {
    init?(platformImageData data: Data) {
#if os(iOS)
        guard let image = UIImage(data: data) else { return nil }
        self.init(uiImage: image)
#elseif os(macOS)
        guard let image = NSImage(data: data) else { return nil }
        self.init(nsImage: image)
#else
        return nil
#endif
    }
}

private extension String {
    var viewBoxSize: CGSize? {
        guard
            let match = matches(pattern: #"viewBox="[^"]*?([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)""#).first,
            match.count == 5,
            let width = Double(match[3]),
            let height = Double(match[4])
        else {
            return nil
        }

        return CGSize(width: width, height: height)
    }

    func matches(pattern: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(startIndex..., in: self)

        return regex.matches(in: self, range: range).map { result in
            (0..<result.numberOfRanges).compactMap { index in
                guard let range = Range(result.range(at: index), in: self) else { return nil }
                return String(self[range])
            }
        }
    }
}

private extension Color {
    init(iconColorString: String) {
        let components = iconColorString
            .replacingOccurrences(of: "display-p3:", with: "")
            .split(separator: ",")
            .compactMap { Double($0) }

        self.init(
            red: components.indices.contains(0) ? components[0] : 0,
            green: components.indices.contains(1) ? components[1] : 0,
            blue: components.indices.contains(2) ? components[2] : 0,
            opacity: components.indices.contains(3) ? components[3] : 1
        )
    }

    init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard let value = Int(hex, radix: 16) else {
            self = .white
            return
        }

        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
