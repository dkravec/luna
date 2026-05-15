#if os(iOS)
import ARKit
import RealityKit
import SwiftUI
import UIKit

struct LunaARSceneView: UIViewRepresentable {
    let bodies: [CelestialBody]
    let settings: SolarSystemSceneSettings

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        view.automaticallyConfigureSession = false

        if ARWorldTrackingConfiguration.isSupported {
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal]
            configuration.environmentTexturing = .automatic
            view.session.run(configuration)
        }

        populate(view)
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {
        populate(view)
    }

    private func populate(_ view: ARView) {
        view.scene.anchors.removeAll()

        let anchor = AnchorEntity(world: SIMD3<Float>(0, -0.35, -1.2))
        let placements = ExperienceSceneLayout.placements(for: bodies, settings: settings)

        for placement in placements {
            let entity = entity(for: placement)
            entity.position = SIMD3<Float>(
                placement.position.x * 0.11,
                placement.position.y * 0.11,
                placement.position.z * 0.11
            )
            anchor.addChild(entity)
        }

        view.scene.addAnchor(anchor)
    }

    private func entity(for placement: SceneBodyPlacement) -> Entity {
        if placement.body.type == .satellite {
            return satelliteEntity(scale: placement.displayRadius)
        }

        let mesh = MeshResource.generateSphere(radius: max(0.015, placement.displayRadius * 0.11))
        let material = SimpleMaterial(
            color: UIColor(sceneColor(for: placement.body)),
            roughness: 0.55,
            isMetallic: false
        )
        return ModelEntity(mesh: mesh, materials: [material])
    }

    private func satelliteEntity(scale: Float) -> Entity {
        let root = Entity()
        let body = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(0.035, 0.024, 0.024)),
            materials: [SimpleMaterial(color: .lightGray, roughness: 0.5, isMetallic: false)]
        )
        root.addChild(body)

        let panelMaterial = SimpleMaterial(color: UIColor(red: 0.10, green: 0.22, blue: 0.50, alpha: 1), roughness: 0.4, isMetallic: false)
        let leftPanel = ModelEntity(mesh: .generateBox(size: SIMD3<Float>(0.055, 0.006, 0.024)), materials: [panelMaterial])
        leftPanel.position.x = -0.046
        root.addChild(leftPanel)

        let rightPanel = ModelEntity(mesh: .generateBox(size: SIMD3<Float>(0.055, 0.006, 0.024)), materials: [panelMaterial])
        rightPanel.position.x = 0.046
        root.addChild(rightPanel)

        root.scale = SIMD3<Float>(repeating: max(1, scale * 8))
        return root
    }

    private func sceneColor(for body: CelestialBody) -> Color {
        switch body.id {
        case "sun":
            return Color(red: 1, green: 0.74, blue: 0.20)
        case "mercury", "moon":
            return Color(red: 0.55, green: 0.54, blue: 0.52)
        case "venus":
            return Color(red: 0.86, green: 0.67, blue: 0.38)
        case "earth":
            return Color(red: 0.16, green: 0.38, blue: 0.84)
        case "mars":
            return Color(red: 0.78, green: 0.32, blue: 0.18)
        case "jupiter", "saturn":
            return Color(red: 0.73, green: 0.58, blue: 0.42)
        case "uranus", "neptune":
            return Color(red: 0.28, green: 0.62, blue: 0.84)
        default:
            return Color(red: 0.78, green: 0.80, blue: 0.84)
        }
    }
}
#endif
