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
    let settings: ExperienceSceneSettings
    var content: ExperienceSceneContent = .solarSystem
    var simulationTimeDays: Double = 0
    var onSelectBody: (CelestialBody) -> Void = { _ in }

    var body: some View {
        VisualSceneContainer(
            snapshot: ExperienceSceneEngine.snapshot(
                for: bodies,
                settings: settings,
                content: content,
                simulationTimeDays: simulationTimeDays
            ),
            showsLabels: settings.showLabels,
            onSelectBody: onSelectBody
        )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Radii.card, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                sceneCaption
            }
    }

    private var sceneCaption: some View {
        Text(settings.distanceScaleMode == .compressed ? "Compressed distance view" : settings.distanceScaleMode.title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.90))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.black.opacity(0.42), in: Capsule(style: .continuous))
            .padding(12)
    }
}

#if os(iOS)
private struct VisualSceneContainer: UIViewRepresentable {
    let snapshot: ExperienceSceneSnapshot
    let showsLabels: Bool
    let onSelectBody: (CelestialBody) -> Void

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
    let snapshot: ExperienceSceneSnapshot
    let showsLabels: Bool
    let onSelectBody: (CelestialBody) -> Void

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
#if os(iOS)
        let tapRecognizer = UITapGestureRecognizer(target: coordinator, action: #selector(VisualSceneCameraCoordinator.handleTap(_:)))
        tapRecognizer.cancelsTouchesInView = false
        view.addGestureRecognizer(tapRecognizer)
#elseif os(macOS)
        let clickRecognizer = NSClickGestureRecognizer(target: coordinator, action: #selector(VisualSceneCameraCoordinator.handleClick(_:)))
        view.addGestureRecognizer(clickRecognizer)
#endif
        configure(view)
        return view
    }

    func configure(_ view: SCNView) {
        if let coordinator = view.delegate as? VisualSceneCameraCoordinator {
            coordinator.onSelectBody = onSelectBody
            coordinator.apply(snapshot: snapshot, showsLabels: showsLabels, to: view)
        }
    }
}

private final class VisualSceneCameraCoordinator: NSObject, SCNSceneRendererDelegate {
    private var cameraLimit = SceneCameraLimit.default
    private var structureKey: String?
    private var bodyNodes: [String: SCNNode] = [:]
    private var bodyVisualNodes: [String: SCNNode] = [:]
    private var orbitNodes: [String: SCNNode] = [:]
    private var bodyLookup: [String: CelestialBody] = [:]
    var onSelectBody: (CelestialBody) -> Void = { _ in }

    func renderer(_ renderer: any SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let pointOfView = renderer.pointOfView,
              let camera = pointOfView.camera,
              camera.usesOrthographicProjection else {
            return
        }

        camera.orthographicScale = max(camera.orthographicScale, cameraLimit.minimumOrthographicScale)
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

    func apply(snapshot: ExperienceSceneSnapshot, showsLabels: Bool, to view: SCNView) {
        let nextStructureKey = Self.structureKey(for: snapshot, showsLabels: showsLabels)
        let nextCameraLimit = SceneCameraLimit(snapshot: snapshot)
        bodyLookup = Dictionary(uniqueKeysWithValues: snapshot.bodies.map { ($0.id, $0.body) })

        if view.scene == nil || structureKey != nextStructureKey {
            let scene = SolarSystemSceneFactory.scene(
                for: snapshot,
                showsLabels: showsLabels
            )
            view.scene = scene
            captureNodes(from: scene)
            view.defaultCameraController.target = nextCameraLimit.subjectCenter
            structureKey = nextStructureKey
        } else {
            updateExistingNodes(with: snapshot)
        }

        update(nextCameraLimit)
    }

    private func updateExistingNodes(with snapshot: ExperienceSceneSnapshot) {
        SCNTransaction.begin()
        SCNTransaction.disableActions = true

        for placement in snapshot.bodies {
            bodyNodes[placement.id]?.position = SCNVector3(
                placement.position.x,
                placement.position.y,
                placement.position.z
            )
            bodyVisualNodes[placement.id]?.eulerAngles = SolarSystemSceneFactory.rotationEuler(for: placement)
        }

        for orbitPath in snapshot.orbitPaths {
            orbitNodes[orbitPath.id]?.geometry = SolarSystemSceneFactory.orbitGeometry(path: orbitPath)
        }

        SCNTransaction.commit()
    }

    private func captureNodes(from scene: SCNScene) {
        bodyNodes.removeAll()
        bodyVisualNodes.removeAll()
        orbitNodes.removeAll()

        scene.rootNode.enumerateChildNodes { node, _ in
            guard let name = node.name else { return }

            if name.hasPrefix("body:") {
                bodyNodes[String(name.dropFirst(5))] = node
            } else if name.hasPrefix("bodyVisual:") {
                bodyVisualNodes[String(name.dropFirst(11))] = node
            } else if name.hasPrefix("orbit:") {
                orbitNodes[String(name.dropFirst(6))] = node
            }
        }
    }

#if os(iOS)
    @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let view = recognizer.view as? SCNView else { return }
        selectBody(at: recognizer.location(in: view), in: view)
    }
#elseif os(macOS)
    @objc func handleClick(_ recognizer: NSClickGestureRecognizer) {
        guard let view = recognizer.view as? SCNView else { return }
        selectBody(at: recognizer.location(in: view), in: view)
    }
#endif

    private func selectBody(at point: CGPoint, in view: SCNView) {
        let hits = view.hitTest(point, options: [.boundingBoxOnly: false])
        guard let bodyID = hits.compactMap({ bodyID(from: $0.node) }).first,
              let body = bodyLookup[bodyID] else {
            return
        }

        onSelectBody(body)
    }

    private func bodyID(from node: SCNNode) -> String? {
        var currentNode: SCNNode? = node
        while let node = currentNode {
            if let name = node.name {
                if name.hasPrefix("body:") {
                    return String(name.dropFirst(5))
                }
                if name.hasPrefix("bodyVisual:") {
                    return String(name.dropFirst(11))
                }
            }
            currentNode = node.parent
        }
        return nil
    }

    private static func structureKey(for snapshot: ExperienceSceneSnapshot, showsLabels: Bool) -> String {
        let bodyKey = snapshot.bodies
            .map { body in
                let radius = Int((body.displayRadius * 1_000).rounded())
                return "\(body.id):\(body.body.type.rawValue):\(radius):\(body.body.textureName ?? ""):\(body.body.modelName ?? "")"
            }
            .joined(separator: "|")
        let orbitKey = snapshot.orbitPaths
            .map { "\($0.id):\($0.points.count)" }
            .joined(separator: "|")

        return "\(showsLabels)-\(bodyKey)-\(orbitKey)"
    }
}

private enum SolarSystemSceneFactory {
    static func scene(for snapshot: ExperienceSceneSnapshot, showsLabels: Bool) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = backgroundImage()
            ?? platformColor(red: 0.015, green: 0.016, blue: 0.024, alpha: 1)

        scene.rootNode.addChildNode(cameraNode(for: snapshot))
        scene.rootNode.addChildNode(ambientLightNode())
        scene.rootNode.addChildNode(keyLightNode())

        let root = SCNNode()
        root.eulerAngles.x = -.pi / 10
        scene.rootNode.addChildNode(root)

        for orbitPath in snapshot.orbitPaths {
            root.addChildNode(orbitNode(path: orbitPath))
        }

        for placement in snapshot.bodies {
            let bodyNode = node(for: placement)
            root.addChildNode(bodyNode)

            if showsLabels {
                bodyNode.addChildNode(labelNode(for: placement.body, radius: placement.displayRadius))
            }
        }

        return scene
    }

    private static func node(for placement: ExperienceSceneBody) -> SCNNode {
        let root = SCNNode()
        root.name = "body:\(placement.id)"
        root.position = SCNVector3(placement.position.x, placement.position.y, placement.position.z)

        let visualNode: SCNNode

        if placement.body.type == .satellite {
            visualNode = satelliteNode()
            let satelliteScale = max(0.22, placement.displayRadius * 5.5)
            visualNode.scale = SCNVector3(
                satelliteScale,
                satelliteScale,
                satelliteScale
            )
        } else {
            let sphere = SCNSphere(radius: CGFloat(placement.displayRadius))
            sphere.segmentCount = placement.body.type == .star ? 64 : 48
            sphere.firstMaterial = material(for: placement.body)
            visualNode = SCNNode(geometry: sphere)
        }

        visualNode.name = "bodyVisual:\(placement.id)"
        visualNode.eulerAngles = rotationEuler(for: placement)
        root.addChildNode(visualNode)
        return root
    }

    static func rotationEuler(for placement: ExperienceSceneBody) -> SCNVector3 {
        SCNVector3(
            placement.axialTiltRadians,
            placement.rotationAngleRadians,
            0
        )
    }

    private static func satelliteNode() -> SCNNode {
        let root = SCNNode()

        let body = SCNBox(width: 0.12, height: 0.08, length: 0.08, chamferRadius: 0.01)
        body.firstMaterial?.diffuse.contents = platformColor(red: 0.82, green: 0.84, blue: 0.88, alpha: 1)
        root.addChildNode(SCNNode(geometry: body))

        let panelMaterial = SCNMaterial()
        panelMaterial.diffuse.contents = platformColor(red: 0.12, green: 0.28, blue: 0.58, alpha: 1)
        panelMaterial.emission.contents = platformColor(red: 0.03, green: 0.08, blue: 0.18, alpha: 1)

        let leftPanel = SCNBox(width: 0.22, height: 0.008, length: 0.08, chamferRadius: 0.002)
        leftPanel.firstMaterial = panelMaterial
        let leftNode = SCNNode(geometry: leftPanel)
        leftNode.position.x = -0.18
        root.addChildNode(leftNode)

        let rightPanel = SCNBox(width: 0.22, height: 0.008, length: 0.08, chamferRadius: 0.002)
        rightPanel.firstMaterial = panelMaterial
        let rightNode = SCNNode(geometry: rightPanel)
        rightNode.position.x = 0.18
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

    private static func backgroundImage() -> PlatformImage? {
        guard let url = Bundle.main.url(
            forResource: "milkyway_2020_8k",
            withExtension: "jpg",
            subdirectory: "Backgrounds"
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
        let text = SCNText(string: body.name, extrusionDepth: 0.006)
        text.font = .systemFont(ofSize: 1.35, weight: .bold)
        text.flatness = 0.02
        text.firstMaterial?.diffuse.contents = platformColor(red: 1, green: 1, blue: 1, alpha: 0.92)
        text.firstMaterial?.emission.contents = platformColor(red: 1, green: 1, blue: 1, alpha: 0.18)
        text.alignmentMode = CATextLayerAlignmentMode.center.rawValue

        let node = SCNNode(geometry: text)
        node.scale = SCNVector3(0.42, 0.42, 0.42)
        node.position = SCNVector3(0, radius + max(0.54, radius * 0.55), 0)
        node.constraints = [SCNBillboardConstraint()]

        let (minVector, maxVector) = text.boundingBox
        node.pivot = SCNMatrix4MakeTranslation(
            (maxVector.x - minVector.x) / 2,
            minVector.y,
            0
        )

        return node
    }

    private static func orbitNode(path: ExperienceOrbitPath) -> SCNNode {
        let node = SCNNode(geometry: orbitGeometry(path: path))
        node.name = "orbit:\(path.id)"
        return node
    }

    static func orbitGeometry(path: ExperienceOrbitPath) -> SCNGeometry {
        let vertices = path.points.map { SCNVector3($0.x, $0.y, $0.z) }
        let source = SCNGeometrySource(vertices: vertices)
        var indices: [Int32] = []

        for index in vertices.indices {
            indices.append(Int32(index))
            indices.append(Int32((index + 1) % vertices.count))
        }

        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        let geometry = SCNGeometry(sources: [source], elements: [element])
        geometry.firstMaterial?.diffuse.contents = platformColor(red: 1, green: 1, blue: 1, alpha: path.bodyId == "moon" ? 0.22 : 0.13)
        geometry.firstMaterial?.emission.contents = platformColor(red: 1, green: 1, blue: 1, alpha: 0.10)
        geometry.firstMaterial?.lightingModel = .constant
        return geometry
    }

    private static func cameraNode(for snapshot: ExperienceSceneSnapshot) -> SCNNode {
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = max(7, Double(snapshot.bounds.span + 2.6))
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
    let minimumOrthographicScale: Double
    let maximumOrthographicScale: Double
    let maximumCameraDistance: Float

    init(snapshot: ExperienceSceneSnapshot) {
        let placements = snapshot.bodies
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
        let largestBodyRadius = placements.map(\.displayRadius).max() ?? 1
        let initialCameraDistance = (SCNVector3(6, 9, 22) - center).length
        let initialOrthographicScale = max(7, Double(snapshot.bounds.span + 2.6))

        subjectCenter = center
        minimumOrthographicScale = max(0.65, Double(largestBodyRadius) * 2.25)
        maximumOrthographicScale = initialOrthographicScale * 1.35
        maximumCameraDistance = max(initialCameraDistance * 1.35, subjectRadius * 2.4)
    }

    private init(
        subjectCenter: SCNVector3,
        minimumOrthographicScale: Double = 0.7,
        maximumOrthographicScale: Double,
        maximumCameraDistance: Float
    ) {
        self.subjectCenter = subjectCenter
        self.minimumOrthographicScale = minimumOrthographicScale
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
