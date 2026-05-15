import SceneKit
import SwiftUI

#if os(iOS)
import UIKit
private typealias PlatformImage = UIImage
private typealias PlatformColor = UIColor
#elseif os(macOS)
import AppKit
private typealias PlatformImage = NSImage
private typealias PlatformColor = NSColor
#endif

struct SolarSystemVisualSceneView: View {
    let bodies: [CelestialBody]
    let settings: SolarSystemSceneSettings

    var body: some View {
        VisualSceneContainer(bodies: bodies, settings: settings)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Radii.card, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                sceneCaption
            }
    }

    private var sceneCaption: some View {
        Text(settings.scaleMode == .compressedDistance ? "Compressed distance view" : settings.scaleMode.title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.82))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.black.opacity(0.34), in: Capsule(style: .continuous))
            .padding(12)
    }
}

#if os(iOS)
private struct VisualSceneContainer: UIViewRepresentable {
    let bodies: [CelestialBody]
    let settings: SolarSystemSceneSettings

    func makeCoordinator() -> VisualSceneCameraCoordinator {
        VisualSceneCameraCoordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        makeSceneView(coordinator: context.coordinator)
    }

    func updateUIView(_ view: SCNView, context: Context) {
        configure(view)
    }
}
#elseif os(macOS)
private struct VisualSceneContainer: NSViewRepresentable {
    let bodies: [CelestialBody]
    let settings: SolarSystemSceneSettings

    func makeCoordinator() -> VisualSceneCameraCoordinator {
        VisualSceneCameraCoordinator()
    }

    func makeNSView(context: Context) -> SCNView {
        makeSceneView(coordinator: context.coordinator)
    }

    func updateNSView(_ view: SCNView, context: Context) {
        configure(view)
    }
}
#endif

private extension VisualSceneContainer {
    func makeSceneView(coordinator: VisualSceneCameraCoordinator) -> SCNView {
        let view = SCNView()
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.delegate = coordinator
        view.backgroundColor = platformColor(red: 0.015, green: 0.016, blue: 0.024, alpha: 1)
        configure(view)
        return view
    }

    func configure(_ view: SCNView) {
        let placements = ExperienceSceneLayout.placements(for: bodies, settings: settings)
        let cameraLimit = SceneCameraLimit(placements: placements)

        view.scene = SolarSystemSceneFactory.scene(
            for: placements,
            showsLabels: settings.showLabels
        )
        view.defaultCameraController.target = cameraLimit.subjectCenter

        if let coordinator = view.delegate as? VisualSceneCameraCoordinator {
            coordinator.update(cameraLimit)
        }
    }
}

private final class VisualSceneCameraCoordinator: NSObject, SCNSceneRendererDelegate {
    private var cameraLimit = SceneCameraLimit.default

    func renderer(_ renderer: any SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let pointOfView = renderer.pointOfView,
              let camera = pointOfView.camera,
              camera.usesOrthographicProjection else {
            return
        }

        camera.orthographicScale = min(camera.orthographicScale, cameraLimit.maximumOrthographicScale)

        let offset = pointOfView.position - cameraLimit.subjectCenter
        let distance = offset.length
        if distance > cameraLimit.maximumCameraDistance, distance > 0 {
            pointOfView.position = cameraLimit.subjectCenter + offset.normalized * cameraLimit.maximumCameraDistance
        }
    }

    func update(_ cameraLimit: SceneCameraLimit) {
        self.cameraLimit = cameraLimit
    }
}

private enum SolarSystemSceneFactory {
    static func scene(for placements: [SceneBodyPlacement], showsLabels: Bool) -> SCNScene {
        let scene = SCNScene()

        scene.rootNode.addChildNode(cameraNode(for: placements))
        scene.rootNode.addChildNode(ambientLightNode())
        scene.rootNode.addChildNode(keyLightNode())

        let root = SCNNode()
        root.eulerAngles.x = -.pi / 10
        scene.rootNode.addChildNode(root)

        for placement in placements {
            if let orbitRadius = placement.orbitRadius, orbitRadius > 0.2 {
                root.addChildNode(orbitNode(radius: CGFloat(orbitRadius)))
            }

            let bodyNode = node(for: placement)
            root.addChildNode(bodyNode)

            if showsLabels {
                bodyNode.addChildNode(labelNode(for: placement.body, radius: placement.displayRadius))
            }
        }

        return scene
    }

    private static func node(for placement: SceneBodyPlacement) -> SCNNode {
        let node: SCNNode

        if placement.body.type == .satellite {
            node = satelliteNode()
            node.scale = SCNVector3(
                placement.displayRadius * 8,
                placement.displayRadius * 8,
                placement.displayRadius * 8
            )
        } else {
            let sphere = SCNSphere(radius: CGFloat(placement.displayRadius))
            sphere.segmentCount = placement.body.type == .star ? 64 : 48
            sphere.firstMaterial = material(for: placement.body)
            node = SCNNode(geometry: sphere)
        }

        node.position = SCNVector3(placement.position.x, placement.position.y, placement.position.z)
        return node
    }

    private static func satelliteNode() -> SCNNode {
        let root = SCNNode()

        let body = SCNBox(width: 0.12, height: 0.08, length: 0.08, chamferRadius: 0.01)
        body.firstMaterial?.diffuse.contents = platformColor(red: 0.82, green: 0.84, blue: 0.88, alpha: 1)
        root.addChildNode(SCNNode(geometry: body))

        let panelMaterial = SCNMaterial()
        panelMaterial.diffuse.contents = platformColor(red: 0.12, green: 0.28, blue: 0.58, alpha: 1)
        panelMaterial.emission.contents = platformColor(red: 0.03, green: 0.08, blue: 0.18, alpha: 1)

        let leftPanel = SCNPlane(width: 0.22, height: 0.08)
        leftPanel.firstMaterial = panelMaterial
        let leftNode = SCNNode(geometry: leftPanel)
        leftNode.position.x = -0.18
        leftNode.eulerAngles.y = .pi / 2
        root.addChildNode(leftNode)

        let rightPanel = SCNPlane(width: 0.22, height: 0.08)
        rightPanel.firstMaterial = panelMaterial
        let rightNode = SCNNode(geometry: rightPanel)
        rightNode.position.x = 0.18
        rightNode.eulerAngles.y = -.pi / 2
        root.addChildNode(rightNode)

        return root
    }

    private static func material(for body: CelestialBody) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = textureImage(for: body) ?? fallbackColor(for: body)
        material.roughness.contents = 0.85

        if body.type == .star {
            material.emission.contents = fallbackColor(for: body)
        }

        return material
    }

    private static func textureImage(for body: CelestialBody) -> PlatformImage? {
        guard let textureName = body.textureName,
              let url = Bundle.main.url(
                forResource: textureName,
                withExtension: "jpg",
                subdirectory: "Planets"
              ) else {
            return nil
        }

#if os(iOS)
        return PlatformImage(contentsOfFile: url.path)
#elseif os(macOS)
        return PlatformImage(contentsOf: url)
#endif
    }

    private static func fallbackColor(for body: CelestialBody) -> PlatformColor {
        switch body.id {
        case "sun":
            return platformColor(red: 1, green: 0.74, blue: 0.20, alpha: 1)
        case "mercury", "moon":
            return platformColor(red: 0.55, green: 0.54, blue: 0.52, alpha: 1)
        case "venus":
            return platformColor(red: 0.86, green: 0.67, blue: 0.38, alpha: 1)
        case "earth":
            return platformColor(red: 0.16, green: 0.38, blue: 0.84, alpha: 1)
        case "mars":
            return platformColor(red: 0.78, green: 0.32, blue: 0.18, alpha: 1)
        case "jupiter", "saturn":
            return platformColor(red: 0.73, green: 0.58, blue: 0.42, alpha: 1)
        case "uranus", "neptune":
            return platformColor(red: 0.28, green: 0.62, blue: 0.84, alpha: 1)
        default:
            return platformColor(red: 0.78, green: 0.80, blue: 0.84, alpha: 1)
        }
    }

    private static func labelNode(for body: CelestialBody, radius: Float) -> SCNNode {
        let text = SCNText(string: body.name, extrusionDepth: 0.002)
        text.font = .systemFont(ofSize: 0.28, weight: .semibold)
        text.firstMaterial?.diffuse.contents = platformColor(red: 1, green: 1, blue: 1, alpha: 0.86)
        text.alignmentMode = CATextLayerAlignmentMode.center.rawValue

        let node = SCNNode(geometry: text)
        node.scale = SCNVector3(0.025, 0.025, 0.025)
        node.position = SCNVector3(0, radius + 0.28, 0)
        node.constraints = [SCNBillboardConstraint()]

        let (minVector, maxVector) = text.boundingBox
        node.pivot = SCNMatrix4MakeTranslation(
            (maxVector.x - minVector.x) / 2,
            minVector.y,
            0
        )

        return node
    }

    private static func orbitNode(radius: CGFloat) -> SCNNode {
        let orbit = SCNTorus(ringRadius: radius, pipeRadius: 0.003)
        orbit.firstMaterial?.diffuse.contents = platformColor(red: 1, green: 1, blue: 1, alpha: 0.14)
        orbit.firstMaterial?.lightingModel = .constant
        let node = SCNNode(geometry: orbit)
        node.eulerAngles.x = .pi / 2
        return node
    }

    private static func cameraNode(for placements: [SceneBodyPlacement]) -> SCNNode {
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = max(10, Double((placements.map { abs($0.position.x) }.max() ?? 8) + 3))
        camera.zFar = 100

        let node = SCNNode()
        node.camera = camera
        node.position = SCNVector3(6, 9, 22)
        node.eulerAngles = SCNVector3(-0.42, 0.22, 0)
        return node
    }

    private static func ambientLightNode() -> SCNNode {
        let light = SCNLight()
        light.type = .ambient
        light.intensity = 520
        light.color = platformColor(red: 0.60, green: 0.64, blue: 0.72, alpha: 1)

        let node = SCNNode()
        node.light = light
        return node
    }

    private static func keyLightNode() -> SCNNode {
        let light = SCNLight()
        light.type = .omni
        light.intensity = 820

        let node = SCNNode()
        node.light = light
        node.position = SCNVector3(-3, 6, 8)
        return node
    }
}

private struct SceneCameraLimit {
    static let `default` = SceneCameraLimit(
        subjectCenter: SCNVector3Zero,
        maximumOrthographicScale: 14,
        maximumCameraDistance: 34
    )

    let subjectCenter: SCNVector3
    let maximumOrthographicScale: Double
    let maximumCameraDistance: Float

    init(placements: [SceneBodyPlacement]) {
        guard !placements.isEmpty else {
            self = .default
            return
        }

        let minX = placements.map { $0.position.x - $0.displayRadius }.min() ?? -5
        let maxX = placements.map { $0.position.x + $0.displayRadius }.max() ?? 5
        let minY = placements.map { $0.position.y - $0.displayRadius }.min() ?? -2
        let maxY = placements.map { $0.position.y + $0.displayRadius }.max() ?? 2
        let minZ = placements.map { $0.position.z - $0.displayRadius }.min() ?? -2
        let maxZ = placements.map { $0.position.z + $0.displayRadius }.max() ?? 2

        let center = SCNVector3(
            (minX + maxX) / 2,
            (minY + maxY) / 2,
            (minZ + maxZ) / 2
        )
        let sceneSpan = max(maxX - minX, max(maxY - minY, maxZ - minZ))
        let subjectRadius = max(4, sceneSpan / 2 + 2)
        let initialCameraDistance = (SCNVector3(6, 9, 22) - center).length
        let initialOrthographicScale = max(10, Double((placements.map { abs($0.position.x) }.max() ?? 8) + 3))

        subjectCenter = center
        maximumOrthographicScale = initialOrthographicScale * 1.35
        maximumCameraDistance = max(initialCameraDistance * 1.35, subjectRadius * 2.4)
    }

    private init(
        subjectCenter: SCNVector3,
        maximumOrthographicScale: Double,
        maximumCameraDistance: Float
    ) {
        self.subjectCenter = subjectCenter
        self.maximumOrthographicScale = maximumOrthographicScale
        self.maximumCameraDistance = maximumCameraDistance
    }
}

private extension SCNVector3 {
    static func + (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        SCNVector3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }

    static func - (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        SCNVector3(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }

    static func * (lhs: SCNVector3, rhs: Float) -> SCNVector3 {
#if os(macOS)
        let multiplier = CGFloat(rhs)
        return SCNVector3(lhs.x * multiplier, lhs.y * multiplier, lhs.z * multiplier)
#else
        SCNVector3(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
#endif
    }

    var length: Float {
        let xValue = Float(x)
        let yValue = Float(y)
        let zValue = Float(z)
        return sqrtf(xValue * xValue + yValue * yValue + zValue * zValue)
    }

    var normalized: SCNVector3 {
        let vectorLength = length
        guard vectorLength > 0 else { return SCNVector3Zero }
#if os(macOS)
        return SCNVector3(
            CGFloat(Float(x) / vectorLength),
            CGFloat(Float(y) / vectorLength),
            CGFloat(Float(z) / vectorLength)
        )
#else
        return SCNVector3(x / vectorLength, y / vectorLength, z / vectorLength)
#endif
    }
}

private func platformColor(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) -> PlatformColor {
#if os(iOS)
    PlatformColor(red: red, green: green, blue: blue, alpha: alpha)
#elseif os(macOS)
    PlatformColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
#endif
}
