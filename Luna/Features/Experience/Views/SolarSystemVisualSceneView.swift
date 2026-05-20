import SceneKit
import SwiftUI
import simd

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
    var simulationDate: Date = Date()
    var focusedBodyID: String?
    var onSelectBody: (CelestialBody) -> Void = { _ in }

    var body: some View {
        VisualSceneContainer(
            snapshot: ExperienceSceneEngine.snapshot(
                for: bodies,
                settings: settings,
                content: content,
                simulationTimeDays: simulationTimeDays,
                simulationDate: simulationDate
            ),
            settings: settings,
            showsLabels: settings.showLabels,
            focusedBodyID: focusedBodyID,
            onSelectBody: onSelectBody
        )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Radii.card, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                sceneCaption
            }
    }

    private var sceneCaption: some View {
        Text("\(settings.sceneScaleProfile.title) · \(simulationDate.formatted(.dateTime.year().month(.abbreviated).day()))")
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
    let settings: ExperienceSceneSettings
    let showsLabels: Bool
    let focusedBodyID: String?
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
    let settings: ExperienceSceneSettings
    let showsLabels: Bool
    let focusedBodyID: String?
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
            coordinator.apply(snapshot: snapshot, settings: settings, showsLabels: showsLabels, focusedBodyID: focusedBodyID, to: view)
        }
    }
}

private final class VisualSceneCameraCoordinator: NSObject, SCNSceneRendererDelegate {
    private var cameraLimit = SceneCameraLimit.default
    private var structureKey: String?
    private var activeFocusID: String?
    private var snapshot = ExperienceSceneSnapshot(bodies: [], orbitPaths: [], bounds: .empty)
    private var bodyNodes: [String: SCNNode] = [:]
    private var bodyTiltNodes: [String: SCNNode] = [:]
    private var bodySpinNodes: [String: SCNNode] = [:]
    private var orbitNodes: [String: SCNNode] = [:]
    private var labelNodes: [String: SCNNode] = [:]
    private var bodyLookup: [String: CelestialBody] = [:]
    private var focusState: CameraFocusState?
    private var lastOrbitThicknessKey: String?
    var onSelectBody: (CelestialBody) -> Void = { _ in }

    func renderer(_ renderer: any SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let pointOfView = renderer.pointOfView,
              let camera = pointOfView.camera,
              camera.usesOrthographicProjection else {
            return
        }

        camera.orthographicScale = max(camera.orthographicScale, cameraLimit.minimumOrthographicScale)
        camera.orthographicScale = min(camera.orthographicScale, cameraLimit.maximumOrthographicScale)

        let target = activeFocusID.flatMap { bodyNodes[$0]?.presentation.convertPosition(SCNVector3Zero, to: nil) } ?? cameraLimit.subjectCenter
        let offset = pointOfView.position - target
        let distance = offset.length
        if distance > cameraLimit.maximumCameraDistance, distance > 0 {
            pointOfView.position = target + offset.normalized * cameraLimit.maximumCameraDistance
        }

        updateOrbitAndLabelScale(for: renderer)
    }

    func update(_ cameraLimit: SceneCameraLimit) {
        self.cameraLimit = cameraLimit
    }

    func apply(snapshot: ExperienceSceneSnapshot, settings: ExperienceSceneSettings, showsLabels: Bool, focusedBodyID: String?, to view: SCNView) {
        let nextStructureKey = Self.structureKey(for: snapshot, settings: settings, showsLabels: showsLabels)
        let nextCameraLimit = SceneCameraLimit(snapshot: snapshot, settings: settings)
        bodyLookup = Dictionary(uniqueKeysWithValues: snapshot.bodies.map { ($0.id, $0.body) })
        self.snapshot = snapshot

        if view.scene == nil || structureKey != nextStructureKey {
            let scene = SolarSystemSceneFactory.scene(
                for: snapshot,
                settings: settings,
                showsLabels: showsLabels
            )
            view.scene = scene
            view.pointOfView = scene.rootNode.childNode(withName: "sceneCamera", recursively: false)
            view.defaultCameraController.target = nextCameraLimit.subjectCenter
            captureNodes(from: scene)
            structureKey = nextStructureKey
            lastOrbitThicknessKey = nil
        } else {
            updateExistingNodes(with: snapshot, cameraScale: view.pointOfView?.camera?.orthographicScale ?? nextCameraLimit.preferredOrthographicScale)
        }

        update(nextCameraLimit)
        applyCameraFocus(focusedBodyID, cameraLimit: nextCameraLimit, to: view)
    }

    private func updateExistingNodes(with snapshot: ExperienceSceneSnapshot, cameraScale: Double) {
        SCNTransaction.begin()
        SCNTransaction.disableActions = true

        for placement in snapshot.bodies {
            bodyNodes[placement.id]?.position = SCNVector3(
                placement.position.x,
                placement.position.y,
                placement.position.z
            )
            bodyTiltNodes[placement.id]?.eulerAngles = SolarSystemSceneRotation.tiltEuler(for: placement)
            bodySpinNodes[placement.id]?.eulerAngles = SolarSystemSceneRotation.spinEuler(for: placement)
            if let labelNode = labelNodes[placement.id] {
                labelNode.position = SolarSystemSceneFactory.labelPosition(for: placement.displayRadius)
                labelNode.scale = SolarSystemSceneLabelScale.scaleVector(
                    for: cameraScale
                )
            }
        }

        for orbitPath in snapshot.orbitPaths {
            orbitNodes[orbitPath.id]?.geometry = SolarSystemSceneFactory.orbitGeometry(
                path: orbitPath,
                cameraScale: cameraScale,
                viewportHeight: 800
            )
        }

        SCNTransaction.commit()
    }

    private func captureNodes(from scene: SCNScene) {
        bodyNodes.removeAll()
        bodyTiltNodes.removeAll()
        bodySpinNodes.removeAll()
        orbitNodes.removeAll()
        labelNodes.removeAll()

        scene.rootNode.enumerateChildNodes { node, _ in
            guard let name = node.name else { return }

            if name.hasPrefix("body:") {
                bodyNodes[String(name.dropFirst(5))] = node
            } else if name.hasPrefix("bodyTilt:") {
                bodyTiltNodes[String(name.dropFirst(9))] = node
            } else if name.hasPrefix("bodySpin:") {
                bodySpinNodes[String(name.dropFirst(9))] = node
            } else if name.hasPrefix("orbit:") {
                orbitNodes[String(name.dropFirst(6))] = node
            } else if name.hasPrefix("label:") {
                labelNodes[String(name.dropFirst(6))] = node
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
        let selectedBodyID = nearestBodyID(to: point, in: view)
            ?? hits.compactMap { bodyID(from: $0.node) }.first
            ?? nearestOrbitBodyID(to: point, in: view)

        guard let selectedBodyID,
              let body = bodyLookup[selectedBodyID] else {
            return
        }

        onSelectBody(body)
    }

    private func bodyID(from node: SCNNode) -> String? {
        var currentNode: SCNNode? = node
        while let node = currentNode {
            if let name = node.name {
                if name.hasPrefix("label:") {
                    return nil
                }
                if name.hasPrefix("body:") {
                    return String(name.dropFirst(5))
                }
                if name.hasPrefix("bodyVisual:") {
                    return String(name.dropFirst(11))
                }
                if name.hasPrefix("bodyHit:") {
                    return String(name.dropFirst(8))
                }
                if name.hasPrefix("orbit:") {
                    return orbitBodyID(from: String(name.dropFirst(6)))
                }
                if name.hasPrefix("orbitHit:") {
                    return String(name.dropFirst(9))
                }
            }
            currentNode = node.parent
        }
        return nil
    }

    private func nearestBodyID(to point: CGPoint, in view: SCNView) -> String? {
        snapshot.bodies
            .compactMap { placement -> (bodyID: String, distance: CGFloat)? in
                guard let node = bodyNodes[placement.id]?.presentation else { return nil }

                let worldPoint = node.convertPosition(SCNVector3Zero, to: nil)
                let projected = view.projectPoint(worldPoint)
                guard projected.z >= 0, projected.z <= 1 else { return nil }

                let center = CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
                let edgeWorld = node.convertPosition(SCNVector3(placement.interactionRadius, 0, 0), to: nil)
                let edgeProjected = view.projectPoint(edgeWorld)
                let projectedRadius = hypot(CGFloat(edgeProjected.x) - center.x, CGFloat(edgeProjected.y) - center.y)
                let threshold = max(CGFloat(14), min(CGFloat(54), projectedRadius + 8))
                let distance = hypot(center.x - point.x, center.y - point.y)

                return distance <= threshold ? (placement.id, distance) : nil
            }
            .min { $0.distance < $1.distance }?
            .bodyID
    }

    private func nearestOrbitBodyID(to point: CGPoint, in view: SCNView) -> String? {
        let threshold: CGFloat = 12

        return snapshot.orbitPaths
            .compactMap { path -> (bodyID: String, distance: CGFloat)? in
                let orbitNode = orbitNodes[path.id]?.presentation
                let distance = path.points
                    .map { scenePoint in
                        let localPoint = SCNVector3(scenePoint.x, scenePoint.y, scenePoint.z)
                        let worldPoint = orbitNode?.convertPosition(localPoint, to: nil) ?? localPoint
                        let projected = view.projectPoint(worldPoint)
                        return hypot(CGFloat(projected.x) - point.x, CGFloat(projected.y) - point.y)
                    }
                    .min() ?? .greatestFiniteMagnitude

                return distance <= threshold ? (path.bodyId, distance) : nil
            }
            .min { $0.distance < $1.distance }?
            .bodyID
    }

    private func orbitBodyID(from orbitID: String) -> String {
        orbitID.hasSuffix("-orbit") ? String(orbitID.dropLast(6)) : orbitID
    }

    private func applyCameraFocus(_ focusedBodyID: String?, cameraLimit: SceneCameraLimit, to view: SCNView) {
        guard let pointOfView = view.pointOfView else { return }

        guard let focusedBodyID else {
            restoreCameraFocusIfNeeded(to: view)
            return
        }

        guard let focusCenter = bodyNodes[focusedBodyID]?.presentation.convertPosition(SCNVector3Zero, to: nil) else {
            return
        }

        let focusChanged = activeFocusID != focusedBodyID
        let previousTarget = focusState?.target ?? view.defaultCameraController.target
        let currentOffset = pointOfView.position - previousTarget
        let minimumDistance = max(Float(focusedOrthographicScale(for: focusedBodyID) * 1.25), 2.2)
        let nextOffset = currentOffset.length < minimumDistance ? currentOffset.normalizedOrDefault * minimumDistance : currentOffset
        let desiredScale = focusChanged
            ? focusedOrthographicScale(for: focusedBodyID)
            : min(max(pointOfView.camera?.orthographicScale ?? focusedOrthographicScale(for: focusedBodyID), cameraLimit.minimumOrthographicScale), cameraLimit.maximumOrthographicScale)

        SCNTransaction.begin()
        SCNTransaction.animationDuration = focusChanged ? 0.26 : 0
        pointOfView.position = focusCenter + nextOffset
        pointOfView.camera?.orthographicScale = desiredScale
        SCNTransaction.commit()

        view.defaultCameraController.target = focusCenter
        focusState = CameraFocusState(
            target: focusCenter,
            cameraOffset: nextOffset,
            orthographicScale: desiredScale
        )
        activeFocusID = focusedBodyID
    }

    private func restoreCameraFocusIfNeeded(to view: SCNView) {
        guard activeFocusID != nil || focusState != nil else {
            return
        }

        guard let pointOfView = view.pointOfView else {
            activeFocusID = nil
            focusState = nil
            return
        }

        let restoreTarget = cameraLimit.subjectCenter
        let offset = focusState?.cameraOffset ?? (pointOfView.position - view.defaultCameraController.target)
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.22
        pointOfView.position = restoreTarget + offset
        pointOfView.camera?.orthographicScale = cameraLimit.preferredOrthographicScale
        SCNTransaction.commit()

        view.defaultCameraController.target = restoreTarget
        focusState = nil
        activeFocusID = nil
    }

    private func focusedOrthographicScale(for bodyID: String) -> Double {
        SolarSystemSceneFocusMetrics.focusedOrthographicScale(for: bodyID, in: snapshot)
    }

    private func updateOrbitAndLabelScale(for renderer: any SCNSceneRenderer) {
        guard let cameraScale = renderer.pointOfView?.camera?.orthographicScale else { return }
        let viewportHeight = max(Double(renderer.currentViewport.height), 1)
        let orbitThicknessKey = "\(Int((cameraScale * 100).rounded())):\(Int(viewportHeight.rounded()))"

        if orbitThicknessKey != lastOrbitThicknessKey {
            for orbitPath in snapshot.orbitPaths {
                guard let node = orbitNodes[orbitPath.id] else { continue }
                node.geometry = SolarSystemSceneFactory.orbitGeometry(
                    path: orbitPath,
                    cameraScale: cameraScale,
                    viewportHeight: viewportHeight
                )
            }
            lastOrbitThicknessKey = orbitThicknessKey
        }

        let labelScale = SolarSystemSceneLabelScale.scaleVector(
            for: cameraScale
        )
        for node in labelNodes.values {
            node.scale = labelScale
        }
    }

    private static func structureKey(for snapshot: ExperienceSceneSnapshot, settings: ExperienceSceneSettings, showsLabels: Bool) -> String {
        let bodyKey = snapshot.bodies
            .map { body in
                let radius = Int((body.displayRadius * 1_000).rounded())
                return "\(body.id):\(body.body.type.rawValue):\(radius):\(body.body.textureName ?? ""):\(body.body.modelName ?? ""):\(body.body.thumbnailName ?? "")"
            }
            .joined(separator: "|")
        let orbitKey = snapshot.orbitPaths
            .map { "\($0.id):\($0.points.count)" }
            .joined(separator: "|")

        return "\(showsLabels)-\(settings.renderDetail.rawValue)-\(bodyKey)-\(orbitKey)"
    }
}

private struct CameraFocusState {
    let target: SCNVector3
    let cameraOffset: SCNVector3
    let orthographicScale: Double
}

private enum SolarSystemSceneFactory {
    static func scene(for snapshot: ExperienceSceneSnapshot, settings: ExperienceSceneSettings, showsLabels: Bool) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = SceneBackgroundTexture.image(for: settings.renderDetail.usesFullBackgroundTexture ? .full : .mini)
            ?? platformColor(red: 0.015, green: 0.016, blue: 0.024, alpha: 1)

        scene.rootNode.addChildNode(cameraNode(for: snapshot, settings: settings))
        scene.rootNode.addChildNode(ambientLightNode())
        scene.rootNode.addChildNode(keyLightNode())

        let root = SCNNode()
        root.eulerAngles.x = -.pi / 10
        scene.rootNode.addChildNode(root)

        for orbitPath in snapshot.orbitPaths {
            root.addChildNode(orbitNode(path: orbitPath, cameraScale: SolarSystemSceneCameraMetrics(snapshot: snapshot, settings: settings).orthographicScale))
        }

        for placement in snapshot.bodies {
            let bodyNode = node(
                for: placement,
                renderDetail: settings.renderDetail,
                isObjectSnapshot: SolarSystemSceneCameraMetrics.isArtifactObjectSnapshot(snapshot)
            )
            root.addChildNode(bodyNode)

            if showsLabels {
                bodyNode.addChildNode(labelNode(
                    for: placement.body,
                    radius: placement.displayRadius,
                    cameraScale: SolarSystemSceneCameraMetrics(snapshot: snapshot, settings: settings).orthographicScale
                ))
            }
        }

        return scene
    }

    private static func node(
        for placement: ExperienceSceneBody,
        renderDetail: SceneRenderDetail,
        isObjectSnapshot: Bool
    ) -> SCNNode {
        let root = SCNNode()
        root.name = "body:\(placement.id)"
        root.position = SCNVector3(placement.position.x, placement.position.y, placement.position.z)

        let tiltNode = SCNNode()
        tiltNode.name = "bodyTilt:\(placement.id)"
        tiltNode.eulerAngles = SolarSystemSceneRotation.tiltEuler(for: placement)

        let spinNode = SCNNode()
        spinNode.name = "bodySpin:\(placement.id)"
        spinNode.eulerAngles = SolarSystemSceneRotation.spinEuler(for: placement)

        let visualNode: SCNNode

        let modelTargetAxis = bundledModelTargetAxis(for: placement, isObjectSnapshot: isObjectSnapshot)
        switch resolvedAsset(for: placement.body, isObjectSnapshot: isObjectSnapshot) {
        case .model:
            if let modelNode = BundledSceneModelLoader.fittedNode(
                named: placement.body.modelName,
                targetLongestAxis: modelTargetAxis
            ) {
                visualNode = modelNode
            } else {
                visualNode = fallbackNode(for: placement, renderDetail: renderDetail)
            }
        case .thumbnail, .fallback:
            visualNode = fallbackNode(for: placement, renderDetail: renderDetail)
        }

        visualNode.name = "bodyVisual:\(placement.id)"
        spinNode.addChildNode(visualNode)
        tiltNode.addChildNode(spinNode)
        root.addChildNode(tiltNode)

        if placement.interactionRadius > placement.displayRadius {
            root.addChildNode(interactionNode(for: placement))
        }
        return root
    }

    private static func fallbackNode(for placement: ExperienceSceneBody, renderDetail: SceneRenderDetail) -> SCNNode {
        if placement.body.type == .satellite {
            let visualNode = satelliteNode()
            let satelliteScale = max(0.22, placement.displayRadius * 5.5)
            visualNode.scale = SCNVector3(
                satelliteScale,
                satelliteScale,
                satelliteScale
            )
            return visualNode
        } else {
            let sphere = SCNSphere(radius: CGFloat(max(placement.displayRadius, 0.0001)))
            sphere.segmentCount = placement.body.type == .star ? renderDetail.starSegmentCount : renderDetail.planetSegmentCount
            sphere.firstMaterial = material(for: placement.body)
            return SCNNode(geometry: sphere)
        }
    }

    private static func bundledModelTargetAxis(for placement: ExperienceSceneBody, isObjectSnapshot: Bool) -> Float {
        if isObjectSnapshot {
            return max(1.24, placement.displayRadius * 10.5)
        }

        return max(0.82, placement.displayRadius * 7.2)
    }

    private static func resolvedAsset(for body: CelestialBody, isObjectSnapshot: Bool) -> SceneObjectAsset {
        guard isObjectSnapshot || body.usesObjectAssetResolver else {
            return .fallback
        }

        return SceneObjectAssetResolver.resolve(for: body)
    }

    private static func interactionNode(for placement: ExperienceSceneBody) -> SCNNode {
        let sphere = SCNSphere(radius: CGFloat(placement.interactionRadius))
        sphere.segmentCount = 12
        let material = SCNMaterial()
        material.diffuse.contents = platformColor(red: 1, green: 1, blue: 1, alpha: 0.01)
        material.transparency = 0.01
        material.lightingModel = .constant
        sphere.firstMaterial = material
        let node = SCNNode(geometry: sphere)
        node.name = "bodyHit:\(placement.id)"
        return node
    }

    static func rotationEuler(for placement: ExperienceSceneBody) -> SCNVector3 {
        SolarSystemSceneRotation.combinedEuler(for: placement)
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

    static func labelPosition(for radius: Float) -> SCNVector3 {
        SCNVector3(0, radius + max(0.30, min(0.54, radius * 0.55)), 0)
    }

    private static func labelNode(for body: CelestialBody, radius: Float, cameraScale: Double) -> SCNNode {
        let text = SCNText(string: body.name, extrusionDepth: 0.006)
        text.font = .systemFont(ofSize: 1.0, weight: .bold)
        text.flatness = 0.02
        text.firstMaterial?.diffuse.contents = platformColor(red: 1, green: 1, blue: 1, alpha: 0.92)
        text.firstMaterial?.emission.contents = platformColor(red: 1, green: 1, blue: 1, alpha: 0.18)
        text.alignmentMode = CATextLayerAlignmentMode.center.rawValue

        let node = SCNNode(geometry: text)
        node.name = "label:\(body.id)"
        node.scale = SolarSystemSceneLabelScale.scaleVector(for: cameraScale)
        node.position = labelPosition(for: radius)
        node.constraints = [SCNBillboardConstraint()]

        let (minVector, maxVector) = text.boundingBox
        node.pivot = SCNMatrix4MakeTranslation(
            (maxVector.x - minVector.x) / 2,
            minVector.y,
            0
        )

        return node
    }

    private static func orbitNode(path: ExperienceOrbitPath, cameraScale: Double) -> SCNNode {
        let node = SCNNode(geometry: orbitGeometry(path: path, cameraScale: cameraScale, viewportHeight: 800))
        node.name = "orbit:\(path.id)"

        for point in path.points.enumerated() where point.offset.isMultiple(of: 8) {
            let hitNode = SCNNode(geometry: orbitHitGeometry())
            hitNode.name = "orbitHit:\(path.bodyId)"
            hitNode.position = SCNVector3(point.element.x, point.element.y, point.element.z)
            node.addChildNode(hitNode)
        }

        return node
    }

    static func orbitGeometry(path: ExperienceOrbitPath, cameraScale: Double, viewportHeight: Double) -> SCNGeometry {
        let thickness = SolarSystemSceneOrbitRibbon.thickness(cameraScale: cameraScale, viewportHeight: viewportHeight, isMoon: path.bodyId == "moon")
        let mesh = SolarSystemSceneOrbitRibbon.mesh(points: path.points, thickness: thickness)
        let source = SCNGeometrySource(vertices: mesh.vertices.map { SCNVector3($0.x, $0.y, $0.z) })
        let element = SCNGeometryElement(indices: mesh.indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: [source], elements: [element])
        geometry.firstMaterial?.diffuse.contents = platformColor(red: 1, green: 1, blue: 1, alpha: path.bodyId == "moon" ? 0.22 : 0.13)
        geometry.firstMaterial?.emission.contents = platformColor(red: 1, green: 1, blue: 1, alpha: 0.10)
        geometry.firstMaterial?.lightingModel = .constant
        geometry.firstMaterial?.isDoubleSided = true
        return geometry
    }

    private static func orbitHitGeometry() -> SCNGeometry {
        let sphere = SCNSphere(radius: 0.09)
        sphere.segmentCount = 8
        let material = SCNMaterial()
        material.diffuse.contents = platformColor(red: 1, green: 1, blue: 1, alpha: 0.01)
        material.transparency = 0.01
        material.lightingModel = .constant
        sphere.firstMaterial = material
        return sphere
    }

    private static func cameraNode(for snapshot: ExperienceSceneSnapshot, settings: ExperienceSceneSettings) -> SCNNode {
        let metrics = SolarSystemSceneCameraMetrics(snapshot: snapshot, settings: settings)
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = metrics.orthographicScale
        camera.zNear = metrics.zNear
        camera.zFar = metrics.zFar

        let node = SCNNode()
        node.name = "sceneCamera"
        node.camera = camera
        node.position = metrics.position
        node.look(at: metrics.subjectCenter)
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

struct SolarSystemSceneFocusMetrics {
    static func focusedOrthographicScale(for bodyID: String, in snapshot: ExperienceSceneSnapshot) -> Double {
        guard let placement = snapshot.bodies.first(where: { $0.id == bodyID }) else {
            return 2.2
        }

        let childEnvelope = snapshot.bodies
            .filter { $0.body.parentBodyId == bodyID }
            .map { child in
                length(child.position - placement.position) + child.displayRadius
            }
            .max() ?? 0
        let subjectRadius = max(placement.displayRadius, childEnvelope, placement.interactionRadius, 0.22)
        return max(0.85, Double(subjectRadius * 4.8))
    }
}

struct SolarSystemSceneOrbitRibbon {
    struct Mesh {
        let vertices: [SIMD3<Float>]
        let indices: [Int32]
    }

    static func thickness(cameraScale: Double, viewportHeight: Double, isMoon: Bool = false) -> Float {
        let pixels = isMoon ? 2.4 : 1.8
        let worldPerPixel = cameraScale / max(viewportHeight, 1)
        return Float(min(max(worldPerPixel * pixels, 0.006), isMoon ? 0.06 : 0.045))
    }

    static func mesh(points: [SIMD3<Float>], thickness: Float) -> Mesh {
        guard points.count > 2 else {
            return Mesh(vertices: [], indices: [])
        }

        let halfThickness = thickness / 2
        var vertices: [SIMD3<Float>] = []
        var indices: [Int32] = []

        for index in points.indices {
            let side = sideVector(for: points, at: index, halfThickness: halfThickness)
            vertices.append(points[index] - side)
            vertices.append(points[index] + side)
        }

        for index in points.indices {
            let current = Int32(index * 2)
            let next = Int32(((index + 1) % points.count) * 2)
            indices.append(contentsOf: [
                current, current + 1, next,
                current + 1, next + 1, next
            ])
        }

        return Mesh(vertices: vertices, indices: indices)
    }

    static func sideVector(for points: [SIMD3<Float>], at index: Int, halfThickness: Float) -> SIMD3<Float> {
        guard points.count > 2, points.indices.contains(index) else {
            return SIMD3<Float>(halfThickness, 0, 0)
        }

        let previous = points[(index - 1 + points.count) % points.count]
        let next = points[(index + 1) % points.count]
        var tangent = next - previous
        if simd_length_squared(tangent) < 0.000_001 {
            tangent = SIMD3<Float>(1, 0, 0)
        }
        tangent = simd_normalize(tangent)

        let referenceAxes = [
            SIMD3<Float>(0, 1, 0),
            SIMD3<Float>(0, 0, 1),
            SIMD3<Float>(1, 0, 0)
        ]

        for axis in referenceAxes {
            let side = simd_cross(tangent, axis)
            if simd_length_squared(side) >= 0.000_001 {
                return simd_normalize(side) * halfThickness
            }
        }

        return SIMD3<Float>(halfThickness, 0, 0)
    }
}

struct SolarSystemSceneLabelScale {
    static func scale(for cameraScale: Double) -> Float {
        let scale = cameraScale * 0.028
        return Float(min(max(scale, 0.055), 0.28))
    }

    static func scaleVector(for cameraScale: Double) -> SCNVector3 {
        let value = scale(for: cameraScale)
        return SCNVector3(value, value, value)
    }
}

struct SolarSystemSceneRotation {
    static let axialTiltAxis = SIMD3<Float>(0, 0, 1)

    static func tiltEuler(for placement: ExperienceSceneBody) -> SCNVector3 {
        SCNVector3(0, 0, placement.axialTiltRadians)
    }

    static func spinEuler(for placement: ExperienceSceneBody) -> SCNVector3 {
        SCNVector3(0, placement.rotationAngleRadians, 0)
    }

    static func combinedEuler(for placement: ExperienceSceneBody) -> SCNVector3 {
        SCNVector3(0, placement.rotationAngleRadians, placement.axialTiltRadians)
    }
}

struct SolarSystemSceneCameraMetrics {
    let position: SCNVector3
    let orthographicScale: Double
    let zNear: Double
    let zFar: Double
    let cameraDistance: Double
    let subjectCenter: SCNVector3

    init(snapshot: ExperienceSceneSnapshot, settings: ExperienceSceneSettings = .defaults) {
        let center = Self.initialSubjectCenter(for: snapshot)
        let objectSnapshot = Self.isArtifactObjectSnapshot(snapshot)
        let trueScaleScene = settings.distanceScaleMode == .trueScale || settings.sceneScaleProfile == .trueSize
        let span = objectSnapshot
            ? Double(max(snapshot.bounds.span, 0.2))
            : Double(max(snapshot.bounds.span, 1))
        subjectCenter = center
        orthographicScale = Self.initialOrthographicScale(for: snapshot, settings: settings)
        cameraDistance = objectSnapshot
            ? max(6, span * 4.0 + 6)
            : max(22, span * 1.8 + 28)
        zNear = 0.001
        zFar = objectSnapshot
            ? max(80, cameraDistance + span * 8.0 + 40)
            : max(trueScaleScene ? 900 : 250, cameraDistance + span * (trueScaleScene ? 7.0 : 4.8) + (trueScaleScene ? 260 : 140))
        position = objectSnapshot
            ? center + SCNVector3(0, 0, Float(cameraDistance))
            : center + SCNVector3(6, 9, Float(cameraDistance))
    }

    private static func initialSubjectCenter(for snapshot: ExperienceSceneSnapshot) -> SCNVector3 {
        if let sun = snapshot.bodies.first(where: { $0.id == "sun" }) {
            return SCNVector3(sun.position.x, sun.position.y, sun.position.z)
        }

        return SCNVector3(snapshot.bounds.center.x, snapshot.bounds.center.y, snapshot.bounds.center.z)
    }

    private static func initialOrthographicScale(for snapshot: ExperienceSceneSnapshot, settings: ExperienceSceneSettings) -> Double {
        if isArtifactObjectSnapshot(snapshot) {
            let largestBodyRadius = snapshot.bodies.map(\.displayRadius).max() ?? 0.16
            let largestInteractionRadius = snapshot.bodies.map(\.interactionRadius).max() ?? largestBodyRadius
            let subjectRadius = max(largestBodyRadius, largestInteractionRadius, 0.16)
            return max(0.95, Double(subjectRadius) * 5.8)
        }

        let span = Double(max(snapshot.bounds.span, 1))

        switch settings.sceneScaleProfile {
        case .scaledRecommended:
            return max(7, min(16, span * 0.78 + 2.2))
        case .uniform:
            return max(7, min(18, span * 0.86 + 2.4))
        case .trueSize:
            return max(7, span + 2.6)
        case .custom:
            switch settings.distanceScaleMode {
            case .trueScale:
                return max(7, span + 2.6)
            case .educational:
                return max(7, min(18, span * 0.88 + 2.4))
            case .compressed:
                return max(7, min(22, span * 0.95 + 2.4))
            }
        }
    }

    static func isArtifactObjectSnapshot(_ snapshot: ExperienceSceneSnapshot) -> Bool {
        guard snapshot.bodies.count == 1,
              snapshot.orbitPaths.isEmpty,
              let body = snapshot.bodies.first?.body else {
            return false
        }

        switch body.type {
        case .satellite, .rocket, .spacecraft, .station, .astronaut:
            return true
        case .star, .planet, .moon, .asteroid, .dwarfPlanet:
            return false
        }
    }
}

struct SceneCameraLimit {
    static let `default` = SceneCameraLimit(
        subjectCenter: SCNVector3Zero,
        preferredOrthographicScale: 7,
        maximumOrthographicScale: 14,
        maximumCameraDistance: 34
    )

    let subjectCenter: SCNVector3
    let minimumOrthographicScale: Double
    let preferredOrthographicScale: Double
    let maximumOrthographicScale: Double
    let maximumCameraDistance: Float

    init(snapshot: ExperienceSceneSnapshot, settings: ExperienceSceneSettings = .defaults) {
        let placements = snapshot.bodies
        guard !placements.isEmpty else {
            self = .default
            return
        }

        let cameraMetrics = SolarSystemSceneCameraMetrics(snapshot: snapshot, settings: settings)
        let center = cameraMetrics.subjectCenter
        let sceneSpan = snapshot.bounds.span
        let subjectRadius = max(4, sceneSpan / 2 + 2)
        let largestBodyRadius = placements.map(\.displayRadius).max() ?? 1
        let initialCameraDistance = (cameraMetrics.position - center).length
        let initialOrthographicScale = cameraMetrics.orthographicScale

        self.init(
            subjectCenter: center,
            minimumOrthographicScale: max(0.65, Double(largestBodyRadius) * 2.25),
            preferredOrthographicScale: initialOrthographicScale,
            maximumOrthographicScale: initialOrthographicScale * 2.1,
            maximumCameraDistance: max(initialCameraDistance * 2.5, subjectRadius * 7.0)
        )
    }

    private init(
        subjectCenter: SCNVector3,
        minimumOrthographicScale: Double = 0.7,
        preferredOrthographicScale: Double,
        maximumOrthographicScale: Double,
        maximumCameraDistance: Float
    ) {
        self.subjectCenter = subjectCenter
        self.minimumOrthographicScale = minimumOrthographicScale
        self.preferredOrthographicScale = preferredOrthographicScale
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
        SCNVector3(Float(lhs.x) * rhs, Float(lhs.y) * rhs, Float(lhs.z) * rhs)
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
        return SCNVector3(Float(x) / vectorLength, Float(y) / vectorLength, Float(z) / vectorLength)
    }

    var normalizedOrDefault: SCNVector3 {
        length > 0 ? normalized : SCNVector3(0, 0, 1)
    }
}

private func platformColor(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) -> PlatformColor {
#if os(iOS)
    PlatformColor(red: red, green: green, blue: blue, alpha: alpha)
#elseif os(macOS)
    PlatformColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
#endif
}
