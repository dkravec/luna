import SceneKit
import SwiftUI

#if os(iOS)
import UIKit
private typealias PreviewImage = UIImage
private typealias PreviewColor = UIColor
#elseif os(macOS)
import AppKit
private typealias PreviewImage = NSImage
private typealias PreviewColor = NSColor
#endif

struct BodyPreviewSceneView: View {
    let celestialBody: CelestialBody

    var body: some View {
        BodyPreviewSceneContainer(celestialBody: celestialBody)
            .clipShape(RoundedRectangle(cornerRadius: Radii.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radii.card, style: .continuous)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)
            }
            .accessibilityLabel("\(celestialBody.name) interactive preview")
    }
}

#if os(iOS)
private struct BodyPreviewSceneContainer: UIViewRepresentable {
    let celestialBody: CelestialBody

    func makeCoordinator() -> BodyPreviewCameraCoordinator {
        BodyPreviewCameraCoordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        makeSceneView(coordinator: context.coordinator)
    }

    func updateUIView(_ view: SCNView, context: Context) {
        configure(view)
    }
}
#elseif os(macOS)
private struct BodyPreviewSceneContainer: NSViewRepresentable {
    let celestialBody: CelestialBody

    func makeCoordinator() -> BodyPreviewCameraCoordinator {
        BodyPreviewCameraCoordinator()
    }

    func makeNSView(context: Context) -> SCNView {
        makeSceneView(coordinator: context.coordinator)
    }

    func updateNSView(_ view: SCNView, context: Context) {
        configure(view)
    }
}
#endif

private extension BodyPreviewSceneContainer {
    func makeSceneView(coordinator: BodyPreviewCameraCoordinator) -> SCNView {
        let view = SCNView()
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.delegate = coordinator
        view.defaultCameraController.target = SCNVector3Zero
        view.backgroundColor = previewColor(red: 0.015, green: 0.016, blue: 0.024, alpha: 1)
        configure(view)
        return view
    }

    func configure(_ view: SCNView) {
        let coordinator = view.delegate as? BodyPreviewCameraCoordinator
        if view.scene == nil || coordinator?.currentBodyID != celestialBody.id {
            view.scene = BodyPreviewSceneFactory.scene(for: celestialBody)
            coordinator?.attach(
                body: celestialBody,
                subjectNode: view.scene?.rootNode.childNode(withName: BodyPreviewSceneFactory.subjectNodeName, recursively: true)
            )
        }

        coordinator?.update(subjectRadius: BodyPreviewSceneFactory.subjectRadius(for: celestialBody))
    }
}

private final class BodyPreviewCameraCoordinator: NSObject, SCNSceneRendererDelegate {
    private var minimumOrthographicScale: Double = 1.1
    private var maximumOrthographicScale: Double = 3.0
    private let maximumCameraDistance: Float = 8.0
    private weak var subjectNode: SCNNode?
    private var body: CelestialBody?
    private var rotationAngle: Float = 0
    private var lastUpdateTime: TimeInterval?
    private var lastInteractionTime: TimeInterval = -5
    private var lastCameraPosition: SCNVector3?
    private var lastCameraEulerAngles: SCNVector3?

    private(set) var currentBodyID: String?

    func renderer(_ renderer: any SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let pointOfView = renderer.pointOfView,
              let camera = pointOfView.camera,
              camera.usesOrthographicProjection else {
            return
        }

        camera.orthographicScale = max(camera.orthographicScale, minimumOrthographicScale)
        camera.orthographicScale = min(camera.orthographicScale, maximumOrthographicScale)

        let offset = pointOfView.position
        let distance = offset.length
        if distance > maximumCameraDistance, distance > 0 {
            pointOfView.position = offset.normalized * maximumCameraDistance
        }

        if didCameraMove(pointOfView) {
            lastInteractionTime = time
        }

        defer {
            lastUpdateTime = time
            lastCameraPosition = pointOfView.position
            lastCameraEulerAngles = pointOfView.eulerAngles
        }

        guard let body, let subjectNode else { return }
        let deltaTime = lastUpdateTime.map { max(0, time - $0) } ?? 0

        if time - lastInteractionTime >= 5 {
            rotationAngle += Float(deltaTime) * previewRotationSpeed(for: body)
        }

        subjectNode.eulerAngles = SCNVector3(
            ExperienceSceneEngine.axialTiltRadians(for: body),
            rotationAngle,
            0
        )
    }

    func update(subjectRadius: CGFloat) {
        minimumOrthographicScale = max(0.72, Double(subjectRadius) * 1.35)
        maximumOrthographicScale = max(2.2, Double(subjectRadius) * 3.5)
    }

    func attach(body: CelestialBody, subjectNode: SCNNode?) {
        self.body = body
        self.subjectNode = subjectNode
        currentBodyID = body.id
        rotationAngle = 0
        lastUpdateTime = nil
        lastInteractionTime = -5
        lastCameraPosition = nil
        lastCameraEulerAngles = nil
    }

    private func didCameraMove(_ cameraNode: SCNNode) -> Bool {
        defer {
            lastCameraPosition = cameraNode.position
            lastCameraEulerAngles = cameraNode.eulerAngles
        }

        guard let lastCameraPosition, let lastCameraEulerAngles else {
            return false
        }

        let positionDelta = (cameraNode.position - lastCameraPosition).length
        let angleDelta = (cameraNode.eulerAngles - lastCameraEulerAngles).length
        return positionDelta > 0.002 || angleDelta > 0.002
    }

    private func previewRotationSpeed(for body: CelestialBody) -> Float {
        let direction: Float = (body.rotationPeriodHours ?? 1) < 0 ? -1 : 1
        let baseSpeed: Float = body.id == "neptune" ? 0.18 : 0.22
        return baseSpeed * direction
    }
}

private enum BodyPreviewSceneFactory {
    static let subjectNodeName = "previewSubject"

    static func subjectRadius(for body: CelestialBody) -> CGFloat {
        body.type == .star ? 0.95 : 0.82
    }

    static func scene(for body: CelestialBody) -> SCNScene {
        let scene = SCNScene()
        scene.rootNode.addChildNode(cameraNode())
        scene.rootNode.addChildNode(ambientLightNode())
        scene.rootNode.addChildNode(keyLightNode())

        let subjectNode = SCNNode()
        subjectNode.name = subjectNodeName
        subjectNode.addChildNode(previewNode(for: body))

        if body.id == "saturn" {
            subjectNode.addChildNode(ringNode())
        }

        scene.rootNode.addChildNode(subjectNode)
        return scene
    }

    private static func previewNode(for body: CelestialBody) -> SCNNode {
        if body.type == .satellite {
            return satelliteNode()
        }

        let sphere = SCNSphere(radius: subjectRadius(for: body))
        sphere.segmentCount = 64
        sphere.firstMaterial = material(for: body)
        return SCNNode(geometry: sphere)
    }

    private static func satelliteNode() -> SCNNode {
        let root = SCNNode()

        let body = SCNBox(width: 0.46, height: 0.30, length: 0.30, chamferRadius: 0.03)
        body.firstMaterial?.diffuse.contents = previewColor(red: 0.82, green: 0.84, blue: 0.88, alpha: 1)
        root.addChildNode(SCNNode(geometry: body))

        let panelMaterial = SCNMaterial()
        panelMaterial.diffuse.contents = previewColor(red: 0.10, green: 0.22, blue: 0.50, alpha: 1)
        panelMaterial.emission.contents = previewColor(red: 0.03, green: 0.08, blue: 0.18, alpha: 1)

        let leftPanel = SCNBox(width: 0.78, height: 0.028, length: 0.28, chamferRadius: 0.006)
        leftPanel.firstMaterial = panelMaterial
        let leftNode = SCNNode(geometry: leftPanel)
        leftNode.position.x = -0.68
        root.addChildNode(leftNode)

        let rightPanel = SCNBox(width: 0.78, height: 0.028, length: 0.28, chamferRadius: 0.006)
        rightPanel.firstMaterial = panelMaterial
        let rightNode = SCNNode(geometry: rightPanel)
        rightNode.position.x = 0.68
        root.addChildNode(rightNode)

        root.eulerAngles = SCNVector3(-0.18, 0.42, 0)
        return root
    }

    private static func material(for body: CelestialBody) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = textureImage(for: body) ?? fallbackColor(for: body)
        material.roughness.contents = 0.86

        if body.type == .star {
            material.emission.contents = fallbackColor(for: body)
        }

        return material
    }

    private static func textureImage(for body: CelestialBody) -> PreviewImage? {
        guard let textureName = body.textureName,
              let url = Bundle.main.url(
                forResource: textureName,
                withExtension: "jpg",
                subdirectory: "Planets"
              ) else {
            return nil
        }

#if os(iOS)
        return PreviewImage(contentsOfFile: url.path)
#elseif os(macOS)
        return PreviewImage(contentsOf: url)
#endif
    }

    private static func ringNode() -> SCNNode {
        let ring = SCNTorus(ringRadius: 1.08, pipeRadius: 0.018)
        ring.firstMaterial?.diffuse.contents = previewColor(red: 0.80, green: 0.70, blue: 0.52, alpha: 0.76)
        let node = SCNNode(geometry: ring)
        node.eulerAngles.x = .pi / 2.7
        return node
    }

    private static func cameraNode() -> SCNNode {
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 2.45
        camera.zFar = 50

        let node = SCNNode()
        node.camera = camera
        node.position = SCNVector3(0, 0, 5)
        return node
    }

    private static func ambientLightNode() -> SCNNode {
        let light = SCNLight()
        light.type = .ambient
        light.intensity = 520
        light.color = previewColor(red: 0.60, green: 0.64, blue: 0.72, alpha: 1)

        let node = SCNNode()
        node.light = light
        return node
    }

    private static func keyLightNode() -> SCNNode {
        let light = SCNLight()
        light.type = .omni
        light.intensity = 840

        let node = SCNNode()
        node.light = light
        node.position = SCNVector3(-2, 3, 4)
        return node
    }

    private static func fallbackColor(for body: CelestialBody) -> PreviewColor {
        switch body.id {
        case "sun":
            return previewColor(red: 1, green: 0.74, blue: 0.20, alpha: 1)
        case "mercury", "moon":
            return previewColor(red: 0.55, green: 0.54, blue: 0.52, alpha: 1)
        case "venus":
            return previewColor(red: 0.86, green: 0.67, blue: 0.38, alpha: 1)
        case "earth":
            return previewColor(red: 0.16, green: 0.38, blue: 0.84, alpha: 1)
        case "mars":
            return previewColor(red: 0.78, green: 0.32, blue: 0.18, alpha: 1)
        case "jupiter", "saturn":
            return previewColor(red: 0.73, green: 0.58, blue: 0.42, alpha: 1)
        case "uranus", "neptune":
            return previewColor(red: 0.28, green: 0.62, blue: 0.84, alpha: 1)
        default:
            return previewColor(red: 0.78, green: 0.80, blue: 0.84, alpha: 1)
        }
    }
}

private func previewColor(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) -> PreviewColor {
#if os(iOS)
    PreviewColor(red: red, green: green, blue: blue, alpha: alpha)
#elseif os(macOS)
    PreviewColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
#endif
}

private extension SCNVector3 {
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
