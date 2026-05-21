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

    static func dismantleUIView(_ view: SCNView, coordinator: VisualSceneCameraCoordinator) {
        coordinator.teardown(view)
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

    static func dismantleNSView(_ view: SCNView, coordinator: VisualSceneCameraCoordinator) {
        coordinator.teardown(view)
    }
}
#endif

private extension VisualSceneContainer {
    func makeSceneView(coordinator: VisualSceneCameraCoordinator) -> SCNView {
        let view = SCNView()
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.isPlaying = false
        view.preferredFramesPerSecond = 30
        view.delegate = coordinator
        view.backgroundColor = platformColor(red: 0.015, green: 0.016, blue: 0.024, alpha: 1)
        view.defaultCameraController.automaticTarget = false
        view.defaultCameraController.inertiaEnabled = false
        view.defaultCameraController.worldUp = SCNVector3(0, 1, 0)
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
    private let stateLock = NSLock()
    private var cameraLimit = SceneCameraLimit.default
    private var structureKey: String?
    private var activeFocusID: String?
    private var snapshot = ExperienceSceneSnapshot(bodies: [], orbitPaths: [], bounds: .empty)
    private var settings = ExperienceSceneSettings.defaults
    private var bodyNodes: [String: SCNNode] = [:]
    private var bodyTiltNodes: [String: SCNNode] = [:]
    private var bodySpinNodes: [String: SCNNode] = [:]
    private var orbitNodes: [String: SCNNode] = [:]
    private var labelNodes: [String: SCNNode] = [:]
    private var bodyLookup: [String: CelestialBody] = [:]
    private var focusState: CameraFocusState?
    private var lastOrbitThicknessKey: String?
    private var pendingOrbitThicknessKey: String?
    var onSelectBody: (CelestialBody) -> Void = { _ in }

    func renderer(_ renderer: any SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let pointOfView = renderer.pointOfView,
              let camera = pointOfView.camera,
              camera.usesOrthographicProjection else {
            return
        }

        let state = lockedState()

        camera.orthographicScale = max(camera.orthographicScale, state.cameraLimit.minimumOrthographicScale)
        camera.orthographicScale = min(camera.orthographicScale, state.cameraLimit.maximumOrthographicScale)

        let target = state.activeFocusID.flatMap { state.focusTargets[$0] } ?? state.cameraLimit.subjectCenter
        let offset = pointOfView.position - target
        let distance = offset.length
        if distance > state.cameraLimit.maximumCameraDistance, distance > 0 {
            pointOfView.position = target + offset.normalized * state.cameraLimit.maximumCameraDistance
        }
        SolarSystemSceneCameraMetrics.updateClippingPlanes(
            for: camera,
            snapshot: state.snapshot,
            settings: state.settings,
            cameraPosition: pointOfView.position
        )

        updateOrbitAndLabelScale(for: renderer)
    }

    func update(_ cameraLimit: SceneCameraLimit) {
        stateLock.lock()
        self.cameraLimit = cameraLimit
        stateLock.unlock()
    }

    func teardown(_ view: SCNView) {
        view.delegate = nil
        view.isPlaying = false
        view.scene?.rootNode.childNodes.forEach { $0.removeFromParentNode() }
        view.scene = nil

        stateLock.lock()
        snapshot = ExperienceSceneSnapshot(bodies: [], orbitPaths: [], bounds: .empty)
        bodyNodes.removeAll()
        bodyTiltNodes.removeAll()
        bodySpinNodes.removeAll()
        orbitNodes.removeAll()
        labelNodes.removeAll()
        bodyLookup.removeAll()
        activeFocusID = nil
        lastOrbitThicknessKey = nil
        pendingOrbitThicknessKey = nil
        stateLock.unlock()

        focusState = nil
        structureKey = nil
    }

    func apply(snapshot: ExperienceSceneSnapshot, settings: ExperienceSceneSettings, showsLabels: Bool, focusedBodyID: String?, to view: SCNView) {
        let nextStructureKey = Self.structureKey(for: snapshot, settings: settings, showsLabels: showsLabels)
        let nextCameraLimit = SceneCameraLimit(snapshot: snapshot, settings: settings)
        stateLock.lock()
        bodyLookup = Dictionary(uniqueKeysWithValues: snapshot.bodies.map { ($0.id, $0.body) })
        self.snapshot = snapshot
        self.settings = settings
        stateLock.unlock()

        if view.scene == nil || structureKey != nextStructureKey {
            let scene = SolarSystemSceneFactory.scene(
                for: snapshot,
                settings: settings,
                showsLabels: showsLabels
            )
            view.scene = scene
            view.pointOfView = scene.rootNode.childNode(withName: "sceneCamera", recursively: false)
            view.defaultCameraController.automaticTarget = false
            view.defaultCameraController.inertiaEnabled = false
            view.defaultCameraController.stopInertia()
            view.defaultCameraController.target = nextCameraLimit.subjectCenter
            captureNodes(from: scene)
            structureKey = nextStructureKey
            stateLock.lock()
            lastOrbitThicknessKey = nil
            pendingOrbitThicknessKey = nil
            stateLock.unlock()
        } else {
            updateExistingNodes(
                with: snapshot,
                cameraScale: view.pointOfView?.camera?.orthographicScale ?? nextCameraLimit.preferredOrthographicScale,
                cameraPosition: view.pointOfView?.presentation.position
            )
        }

        update(nextCameraLimit)
        applyCameraFocus(focusedBodyID, cameraLimit: nextCameraLimit, to: view)
    }

    private func updateExistingNodes(with snapshot: ExperienceSceneSnapshot, cameraScale: Double, cameraPosition: SCNVector3?) {
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
                viewportHeight: 800,
                cameraPosition: cameraPosition
            )
        }

        SCNTransaction.commit()
    }

    private func captureNodes(from scene: SCNScene) {
        var nextBodyNodes: [String: SCNNode] = [:]
        var nextBodyTiltNodes: [String: SCNNode] = [:]
        var nextBodySpinNodes: [String: SCNNode] = [:]
        var nextOrbitNodes: [String: SCNNode] = [:]
        var nextLabelNodes: [String: SCNNode] = [:]

        scene.rootNode.enumerateChildNodes { node, _ in
            guard let name = node.name else { return }

            if name.hasPrefix("body:") {
                nextBodyNodes[String(name.dropFirst(5))] = node
            } else if name.hasPrefix("bodyTilt:") {
                nextBodyTiltNodes[String(name.dropFirst(9))] = node
            } else if name.hasPrefix("bodySpin:") {
                nextBodySpinNodes[String(name.dropFirst(9))] = node
            } else if name.hasPrefix("orbit:") {
                nextOrbitNodes[String(name.dropFirst(6))] = node
            } else if name.hasPrefix("label:") {
                nextLabelNodes[String(name.dropFirst(6))] = node
            }
        }

        stateLock.lock()
        bodyNodes = nextBodyNodes
        bodyTiltNodes = nextBodyTiltNodes
        bodySpinNodes = nextBodySpinNodes
        orbitNodes = nextOrbitNodes
        labelNodes = nextLabelNodes
        stateLock.unlock()
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

        guard let focusCenter = focusTarget(for: focusedBodyID) else {
            return
        }

        let focusChanged = activeFocusID != focusedBodyID
        let desiredFocusScale = focusedOrthographicScale(for: focusedBodyID)
        let idealOffset = SolarSystemSceneFocusMetrics.cameraOffset(for: focusedBodyID, in: snapshot)
        let currentScale = pointOfView.camera?.orthographicScale ?? desiredFocusScale
        let desiredScale = focusChanged
            ? desiredFocusScale
            : min(max(currentScale, cameraLimit.minimumOrthographicScale), cameraLimit.maximumOrthographicScale)

        let nextPosition: SCNVector3
        if focusChanged {
            let minimumDistance = max(Float(desiredFocusScale * 0.88), 1.25)
            let maximumDistance = max(Float(desiredFocusScale * 1.55), minimumDistance + 0.2)
            let nextOffset = clampedFocusOffset(
                idealOffset,
                idealOffset: idealOffset,
                minimumDistance: minimumDistance,
                maximumDistance: maximumDistance,
                shouldResetToIdeal: true
            )
            nextPosition = focusCenter + nextOffset
            stopCameraAnimations(pointOfView)
            view.defaultCameraController.stopInertia()
        } else {
            let previousTarget = focusState?.target ?? focusCenter
            let targetDelta = focusCenter - previousTarget
            let translatedPosition = pointOfView.position + targetDelta
            nextPosition = clampedCameraPosition(
                translatedPosition,
                target: focusCenter,
                maximumDistance: cameraLimit.maximumCameraDistance
            )
        }

        view.defaultCameraController.automaticTarget = false
        view.defaultCameraController.target = focusCenter
        SCNTransaction.begin()
        SCNTransaction.animationDuration = focusChanged ? 0.26 : 0
        if focusChanged || focusCenter.distance(to: focusState?.target ?? focusCenter) > 0.0005 {
            pointOfView.position = nextPosition
        }
        if focusChanged {
            pointOfView.look(at: focusCenter)
        }
        pointOfView.camera?.orthographicScale = desiredScale
        if let camera = pointOfView.camera {
            SolarSystemSceneCameraMetrics.updateClippingPlanes(
                for: camera,
                snapshot: snapshot,
                settings: settings,
                cameraPosition: nextPosition
            )
            widenFocusedClippingPlanes(
                for: camera,
                cameraPosition: nextPosition,
                focusCenter: focusCenter,
                focusScale: desiredScale
            )
        }
        SCNTransaction.commit()

        view.defaultCameraController.target = focusCenter
        focusState = CameraFocusState(
            target: focusCenter,
            cameraOffset: nextPosition - focusCenter,
            orthographicScale: desiredScale
        )
        stateLock.lock()
        activeFocusID = focusedBodyID
        stateLock.unlock()
    }

    private func clampedFocusOffset(
        _ offset: SCNVector3,
        idealOffset: SCNVector3,
        minimumDistance: Float,
        maximumDistance: Float,
        shouldResetToIdeal: Bool
    ) -> SCNVector3 {
        if shouldResetToIdeal {
            return idealOffset.normalizedOrDefault * min(max(idealOffset.length, minimumDistance), maximumDistance)
        }

        let distance = offset.length
        if distance < minimumDistance {
            return offset.normalizedOrDefault * minimumDistance
        }
        if distance > maximumDistance {
            return offset.normalizedOrDefault * maximumDistance
        }
        return offset
    }

    private func clampedCameraPosition(
        _ position: SCNVector3,
        target: SCNVector3,
        maximumDistance: Float
    ) -> SCNVector3 {
        let offset = position - target
        let distance = offset.length
        guard distance > maximumDistance, distance > 0 else {
            return position
        }

        return target + offset.normalized * maximumDistance
    }

    private func widenFocusedClippingPlanes(
        for camera: SCNCamera,
        cameraPosition: SCNVector3,
        focusCenter: SCNVector3,
        focusScale: Double
    ) {
        let focusDistance = Double((cameraPosition - focusCenter).length)
        camera.zNear = min(camera.zNear, 0.001)
        camera.zFar = max(camera.zFar, focusDistance + focusScale * 8.0 + 80)
    }

    private func stopCameraAnimations(_ pointOfView: SCNNode) {
        pointOfView.removeAllActions()
        pointOfView.removeAllAnimations()
        pointOfView.camera?.removeAllAnimations()
    }

    private func restoreCameraFocusIfNeeded(to view: SCNView) {
        guard activeFocusID != nil || focusState != nil else {
            return
        }

        guard let pointOfView = view.pointOfView else {
            stateLock.lock()
            activeFocusID = nil
            stateLock.unlock()
            focusState = nil
            return
        }

        let restoreTarget = cameraLimit.subjectCenter
        let offset = SolarSystemSceneCameraMetrics.defaultCameraOffset(
            for: cameraLimit.preferredOrthographicScale
        )
        stopCameraAnimations(pointOfView)
        view.defaultCameraController.stopInertia()
        view.defaultCameraController.automaticTarget = false
        view.defaultCameraController.inertiaEnabled = false
        view.defaultCameraController.target = restoreTarget
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.22
        pointOfView.position = restoreTarget + offset
        pointOfView.look(at: restoreTarget)
        pointOfView.camera?.orthographicScale = cameraLimit.preferredOrthographicScale
        if let camera = pointOfView.camera {
            SolarSystemSceneCameraMetrics.updateClippingPlanes(
                for: camera,
                snapshot: snapshot,
                settings: settings,
                cameraPosition: restoreTarget + offset
            )
        }
        SCNTransaction.commit()

        view.defaultCameraController.target = restoreTarget
        focusState = nil
        stateLock.lock()
        activeFocusID = nil
        stateLock.unlock()
    }

    private func focusedOrthographicScale(for bodyID: String) -> Double {
        SolarSystemSceneFocusMetrics.focusedOrthographicScale(for: bodyID, in: snapshot)
    }

    private func focusTarget(for bodyID: String) -> SCNVector3? {
        guard let node = bodyNodes[bodyID]?.presentation else { return nil }
        if let visualNode = node.childNode(withName: "bodyVisual:\(bodyID)", recursively: true)?.presentation {
            return visualNode.worldBoundingBoxCenter() ?? visualNode.convertPosition(SCNVector3Zero, to: nil)
        }
        return node.worldBoundingBoxCenter() ?? node.convertPosition(SCNVector3Zero, to: nil)
    }

    private func updateOrbitAndLabelScale(for renderer: any SCNSceneRenderer) {
        guard let pointOfView = renderer.pointOfView,
              let cameraScale = pointOfView.camera?.orthographicScale else { return }
        let cameraPosition = pointOfView.presentation.position
        let viewportHeight = max(Double(renderer.currentViewport.height), 1)
        let distanceBucket = Int((cameraPosition.length * 10).rounded())
        let orbitThicknessKey = "\(Int((cameraScale * 100).rounded())):\(distanceBucket):\(Int(viewportHeight.rounded()))"

        let refresh: (orbitPaths: [ExperienceOrbitPath], orbitNodes: [String: SCNNode], labelNodes: [SCNNode])? = stateLock.withLock {
            guard orbitThicknessKey != lastOrbitThicknessKey,
                  orbitThicknessKey != pendingOrbitThicknessKey else {
                return nil
            }

            pendingOrbitThicknessKey = orbitThicknessKey
            return (snapshot.orbitPaths, orbitNodes, Array(labelNodes.values))
        }

        guard let refresh else { return }

        let labelScale = SolarSystemSceneLabelScale.scaleVector(
            for: cameraScale
        )

        DispatchQueue.main.async { [weak self] in
            SCNTransaction.begin()
            SCNTransaction.disableActions = true
            for orbitPath in refresh.orbitPaths {
                guard let node = refresh.orbitNodes[orbitPath.id] else { continue }
                node.geometry = SolarSystemSceneFactory.orbitGeometry(
                    path: orbitPath,
                    cameraScale: cameraScale,
                    viewportHeight: viewportHeight,
                    cameraPosition: cameraPosition
                )
            }

            for node in refresh.labelNodes {
                node.scale = labelScale
            }
            SCNTransaction.commit()

            self?.stateLock.withLock {
                self?.lastOrbitThicknessKey = orbitThicknessKey
                self?.pendingOrbitThicknessKey = nil
            }
        }
    }

    private func lockedState() -> (
        cameraLimit: SceneCameraLimit,
        activeFocusID: String?,
        bodyNodes: [String: SCNNode],
        focusTargets: [String: SCNVector3],
        snapshot: ExperienceSceneSnapshot,
        settings: ExperienceSceneSettings
    ) {
        stateLock.lock()
        defer { stateLock.unlock() }

        return (
            cameraLimit,
            activeFocusID,
            bodyNodes,
            Dictionary(uniqueKeysWithValues: bodyNodes.map { id, node in
                let presentationNode = node.presentation
                let center = presentationNode.worldBoundingBoxCenter()
                    ?? presentationNode.convertPosition(SCNVector3Zero, to: nil)
                return (id, center)
            }),
            snapshot,
            settings
        )
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

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
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

        let cameraMetrics = SolarSystemSceneCameraMetrics(snapshot: snapshot, settings: settings)

        for orbitPath in snapshot.orbitPaths {
            root.addChildNode(orbitNode(
                path: orbitPath,
                cameraScale: cameraMetrics.orthographicScale,
                cameraPosition: cameraMetrics.position
            ))
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
                    cameraScale: cameraMetrics.orthographicScale
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

    private static func orbitNode(path: ExperienceOrbitPath, cameraScale: Double, cameraPosition: SCNVector3) -> SCNNode {
        let node = SCNNode(geometry: orbitGeometry(
            path: path,
            cameraScale: cameraScale,
            viewportHeight: 800,
            cameraPosition: cameraPosition
        ))
        node.name = "orbit:\(path.id)"

        for point in path.points.enumerated() where point.offset.isMultiple(of: 8) {
            let hitNode = SCNNode(geometry: orbitHitGeometry())
            hitNode.name = "orbitHit:\(path.bodyId)"
            hitNode.position = SCNVector3(point.element.x, point.element.y, point.element.z)
            node.addChildNode(hitNode)
        }

        return node
    }

    static func orbitGeometry(
        path: ExperienceOrbitPath,
        cameraScale: Double,
        viewportHeight: Double,
        cameraPosition: SCNVector3? = nil
    ) -> SCNGeometry {
        let mesh = SolarSystemSceneOrbitRibbon.mesh(
            points: path.points,
            cameraScale: cameraScale,
            viewportHeight: viewportHeight,
            cameraPosition: cameraPosition.map(SIMD3<Float>.init),
            isMoon: path.bodyId == "moon"
        )
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
        let cappedChildEnvelope = min(childEnvelope, placement.displayRadius * 1.05)
        let cappedInteractionRadius = min(placement.interactionRadius * 0.45, placement.displayRadius * 1.05)
        let subjectRadius = max(placement.displayRadius, cappedChildEnvelope, cappedInteractionRadius, 0.20)
        return max(0.82, Double(subjectRadius * 4.3))
    }

    static func cameraOffset(for bodyID: String, in snapshot: ExperienceSceneSnapshot) -> SCNVector3 {
        let scale = Float(focusedOrthographicScale(for: bodyID, in: snapshot))
        let bodyPosition = snapshot.bodies.first { $0.id == bodyID }?.position ?? .zero
        let sunPosition = snapshot.bodies.first { $0.id == "sun" }?.position ?? .zero
        var radial = bodyPosition - sunPosition
        radial.y = 0
        if simd_length_squared(radial) > 0.000_001 {
            radial = simd_normalize(radial)
        } else {
            radial = SIMD3<Float>(1, 0, 0)
        }

        return SCNVector3(
            radial.x * scale * 0.16,
            max(scale * 0.58, 0.86),
            max(scale * 1.18, 1.45) + radial.z * scale * 0.18
        )
    }
}

struct SolarSystemSceneOrbitRibbon {
    struct Mesh {
        let vertices: [SIMD3<Float>]
        let indices: [Int32]
    }

    static func thickness(
        cameraScale: Double,
        viewportHeight: Double,
        cameraDistance: Double? = nil,
        isMoon: Bool = false
    ) -> Float {
        let pixels = isMoon ? 2.4 : 1.8
        let worldPerPixel = cameraScale / max(viewportHeight, 1)
        let referenceDistance = max(cameraScale * 1.6, 1)
        let distanceFactor = cameraDistance.map { distance in
            min(max(distance / referenceDistance, 0.78), isMoon ? 2.6 : 2.15)
        } ?? 1
        let maximum = isMoon ? 0.075 : 0.058
        return Float(min(max(worldPerPixel * pixels * distanceFactor, 0.006), maximum))
    }

    static func mesh(points: [SIMD3<Float>], thickness: Float) -> Mesh {
        mesh(points: points, thicknesses: Array(repeating: thickness, count: points.count))
    }

    static func mesh(
        points: [SIMD3<Float>],
        cameraScale: Double,
        viewportHeight: Double,
        cameraPosition: SIMD3<Float>?,
        isMoon: Bool = false
    ) -> Mesh {
        let thicknesses = points.map { point in
            thickness(
                cameraScale: cameraScale,
                viewportHeight: viewportHeight,
                cameraDistance: cameraPosition.map { Double(simd_distance($0, point)) },
                isMoon: isMoon
            )
        }
        return mesh(points: points, thicknesses: thicknesses)
    }

    private static func mesh(points: [SIMD3<Float>], thicknesses: [Float]) -> Mesh {
        guard points.count > 2 else {
            return Mesh(vertices: [], indices: [])
        }

        var vertices: [SIMD3<Float>] = []
        var indices: [Int32] = []

        for index in points.indices {
            let halfThickness = (thicknesses.indices.contains(index) ? thicknesses[index] : 0.006) / 2
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
            : center + Self.defaultCameraOffset(for: orthographicScale, cameraDistance: cameraDistance)
    }

    static func updateClippingPlanes(
        for camera: SCNCamera,
        snapshot: ExperienceSceneSnapshot,
        settings: ExperienceSceneSettings,
        cameraPosition: SCNVector3
    ) {
        let metrics = SolarSystemSceneCameraMetrics(snapshot: snapshot, settings: settings)
        let cameraDistanceFromCenter = Double((cameraPosition - metrics.subjectCenter).length)
        let span = Double(max(snapshot.bounds.span, 1))
        let objectSnapshot = isArtifactObjectSnapshot(snapshot)
        let margin = objectSnapshot ? span * 8 + 40 : span * 7 + 220

        camera.zNear = objectSnapshot ? 0.001 : 0.01
        camera.zFar = max(metrics.zFar, cameraDistanceFromCenter + margin)
    }

    static func defaultCameraOffset(for orthographicScale: Double, cameraDistance: Double? = nil) -> SCNVector3 {
        let distance = Float(cameraDistance ?? max(22, orthographicScale * 1.8 + 28))
        let scale = Float(orthographicScale)
        return SCNVector3(
            max(3.5, scale * 0.18),
            max(distance * 0.64, scale * 1.12),
            max(distance * 0.52, scale * 0.82)
        )
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
            return max(7, min(19, span * 0.90 + 2.8))
        case .uniform:
            return max(7, min(21, span * 0.96 + 3.0))
        case .trueSize:
            return max(7, span + 2.6)
        case .custom:
            switch settings.distanceScaleMode {
            case .trueScale:
                return max(7, span + 2.6)
            case .educational:
                return max(7, min(21, span * 0.98 + 3.0))
            case .compressed:
                return max(7, min(25, span * 1.05 + 3.2))
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
        let trueScaleScene = settings.distanceScaleMode == .trueScale || settings.sceneScaleProfile == .trueSize
        let minimumOrthographicScale = trueScaleScene
            ? max(0.12, min(Double(largestBodyRadius) * 0.55, initialOrthographicScale * 0.08))
            : max(0.65, Double(largestBodyRadius) * 2.25)

        self.init(
            subjectCenter: center,
            minimumOrthographicScale: minimumOrthographicScale,
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

private extension SCNNode {
    func worldBoundingBoxCenter() -> SCNVector3? {
        var minimum: SCNVector3?
        var maximum: SCNVector3?

        func include(_ point: SCNVector3) {
            if let currentMinimum = minimum, let currentMaximum = maximum {
                minimum = SCNVector3(
                    min(currentMinimum.x, point.x),
                    min(currentMinimum.y, point.y),
                    min(currentMinimum.z, point.z)
                )
                maximum = SCNVector3(
                    max(currentMaximum.x, point.x),
                    max(currentMaximum.y, point.y),
                    max(currentMaximum.z, point.z)
                )
            } else {
                minimum = point
                maximum = point
            }
        }

        func includeGeometry(from sourceNode: SCNNode) {
            guard let geometry = sourceNode.geometry else { return }
            let bounds = geometry.boundingBox
            let minVector = bounds.min
            let maxVector = bounds.max
            let corners = [
                SCNVector3(minVector.x, minVector.y, minVector.z),
                SCNVector3(minVector.x, minVector.y, maxVector.z),
                SCNVector3(minVector.x, maxVector.y, minVector.z),
                SCNVector3(minVector.x, maxVector.y, maxVector.z),
                SCNVector3(maxVector.x, minVector.y, minVector.z),
                SCNVector3(maxVector.x, minVector.y, maxVector.z),
                SCNVector3(maxVector.x, maxVector.y, minVector.z),
                SCNVector3(maxVector.x, maxVector.y, maxVector.z)
            ]
            corners
                .map { sourceNode.convertPosition($0, to: nil) }
                .forEach(include)
        }

        includeGeometry(from: self)
        enumerateChildNodes { node, _ in
            includeGeometry(from: node.presentation)
        }

        guard let minimum, let maximum else { return nil }
        return SCNVector3(
            (minimum.x + maximum.x) / 2,
            (minimum.y + maximum.y) / 2,
            (minimum.z + maximum.z) / 2
        )
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

    func distance(to other: SCNVector3) -> Float {
        (self - other).length
    }
}

private extension SIMD3<Float> {
    init(_ vector: SCNVector3) {
        self.init(Float(vector.x), Float(vector.y), Float(vector.z))
    }
}

private func platformColor(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) -> PlatformColor {
#if os(iOS)
    PlatformColor(red: red, green: green, blue: blue, alpha: alpha)
#elseif os(macOS)
    PlatformColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
#endif
}
