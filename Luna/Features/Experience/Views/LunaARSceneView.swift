#if os(iOS)
import ARKit
import RealityKit
import SwiftUI
import UIKit

struct LunaARSceneView: UIViewRepresentable {
    let bodies: [CelestialBody]
    let settings: SolarSystemSceneSettings
    let recenterTrigger: Int
    let placementOffset: SIMD3<Float>
    let contentScale: Float

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

        let anchor = AnchorEntity(world: anchorTransform(for: view))
        anchor.scale = SIMD3<Float>(repeating: max(0.25, contentScale))
        let placements = ExperienceSceneLayout.placements(for: bodies, settings: settings)

        for placement in placements {
            let entity = entity(for: placement)
            entity.position = SIMD3<Float>(
                placement.position.x * 0.11,
                placement.position.y * 0.11,
                placement.position.z * 0.11
            ) + placementOffset
            anchor.addChild(entity)
        }

        view.scene.addAnchor(anchor)
    }

    private func anchorTransform(for view: ARView) -> simd_float4x4 {
        var translation = matrix_identity_float4x4
        translation.columns.3.y = -0.28
        translation.columns.3.z = -1.25
        return simd_mul(view.cameraTransform.matrix, translation)
    }

    private func entity(for placement: SceneBodyPlacement) -> Entity {
        if placement.body.type == .satellite {
            return satelliteEntity(scale: placement.displayRadius)
        }

        let mesh = MeshResource.generateSphere(radius: max(0.015, placement.displayRadius * 0.11))
        let material = material(for: placement.body)
        return ModelEntity(mesh: mesh, materials: [material])
    }

    private func material(for body: CelestialBody) -> UnlitMaterial {
        var material = UnlitMaterial(color: fallbackColor(for: body))

        if let texture = textureResource(for: body) {
            material.color = .init(tint: .white, texture: .init(texture))
        }

        return material
    }

    private func textureResource(for body: CelestialBody) -> TextureResource? {
        guard let textureName = body.textureName,
              let url = Bundle.main.url(
                forResource: textureName,
                withExtension: "jpg",
                subdirectory: "Planets"
              ) else {
            return nil
        }

        return try? TextureResource.load(contentsOf: url)
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

    private func fallbackColor(for body: CelestialBody) -> UIColor {
        switch body.id {
        case "sun":
            return UIColor(red: 1, green: 0.74, blue: 0.20, alpha: 1)
        case "mercury", "moon":
            return UIColor(red: 0.55, green: 0.54, blue: 0.52, alpha: 1)
        case "venus":
            return UIColor(red: 0.86, green: 0.67, blue: 0.38, alpha: 1)
        case "earth":
            return UIColor(red: 0.16, green: 0.38, blue: 0.84, alpha: 1)
        case "mars":
            return UIColor(red: 0.78, green: 0.32, blue: 0.18, alpha: 1)
        case "jupiter", "saturn":
            return UIColor(red: 0.73, green: 0.58, blue: 0.42, alpha: 1)
        case "uranus", "neptune":
            return UIColor(red: 0.28, green: 0.62, blue: 0.84, alpha: 1)
        default:
            return UIColor(red: 0.78, green: 0.80, blue: 0.84, alpha: 1)
        }
    }
}
#endif
