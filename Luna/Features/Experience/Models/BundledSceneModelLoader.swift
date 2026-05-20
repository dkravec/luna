import SceneKit
#if os(iOS)
import UIKit
private typealias LoaderColor = UIColor
private typealias SceneScalar = Float
typealias BundledThumbnailImage = UIImage
#elseif os(macOS)
import AppKit
private typealias LoaderColor = NSColor
private typealias SceneScalar = CGFloat
typealias BundledThumbnailImage = NSImage
#endif

enum SceneObjectAsset: Equatable {
    case model(URL)
    case thumbnail(URL)
    case fallback
}

enum SceneObjectAssetResolver {
    private final class BundleToken {}

    private static let modelSubdirectories = [
        "NASA",
        "Satellites",
        "Moons"
    ]

    private static let thumbnailSubdirectories = [
        "Thumbnails/NASA",
        "NASA"
    ]

    static func resolve(for body: CelestialBody) -> SceneObjectAsset {
        if let modelURL = modelURL(for: body) {
            return .model(modelURL)
        }

        if let thumbnailURL = thumbnailURL(for: body) {
            return .thumbnail(thumbnailURL)
        }

        return .fallback
    }

    static func modelURL(for body: CelestialBody) -> URL? {
        modelURL(named: body.modelName)
    }

    static func thumbnailURL(for body: CelestialBody) -> URL? {
        thumbnailURL(named: body.thumbnailName)
    }

    static func modelURL(named modelName: String?) -> URL? {
        resourceURL(
            named: modelName,
            defaultExtension: "glb",
            subdirectories: modelSubdirectories
        )
    }

    static func thumbnailURL(named thumbnailName: String?) -> URL? {
        resourceURL(
            named: thumbnailName,
            defaultExtension: "png",
            subdirectories: thumbnailSubdirectories
        )
    }

    private static func resourceURL(
        named name: String?,
        defaultExtension: String,
        subdirectories: [String]
    ) -> URL? {
        guard let name, !name.isEmpty else { return nil }

        let resourceName = (name as NSString).deletingPathExtension
        let resourceExtension = (name as NSString).pathExtension.isEmpty
            ? defaultExtension
            : (name as NSString).pathExtension

        for bundle in candidateBundles {
            for subdirectory in subdirectories {
                if let url = bundle.url(
                    forResource: resourceName,
                    withExtension: resourceExtension,
                    subdirectory: subdirectory
                ) {
                    return url
                }
            }

            if let url = bundle.url(forResource: resourceName, withExtension: resourceExtension) {
                return url
            }
        }

        return nil
    }

    private static var candidateBundles: [Bundle] {
        let bundles = [
            Bundle.main,
            Bundle(for: BundleToken.self)
        ] + Bundle.allBundles + Bundle.allFrameworks
        return bundles.reduce(into: []) { result, bundle in
            guard !result.contains(bundle) else { return }
            result.append(bundle)
        }
    }
}

extension CelestialBody {
    var usesObjectAssetResolver: Bool {
        switch type {
        case .satellite, .rocket, .spacecraft, .station, .astronaut:
            return true
        case .star, .planet, .moon, .asteroid, .dwarfPlanet:
            return false
        }
    }
}

enum BundledThumbnailImageLoader {
    static func image(named thumbnailName: String?) -> BundledThumbnailImage? {
        guard let url = SceneObjectAssetResolver.thumbnailURL(named: thumbnailName) else {
            return nil
        }

#if os(iOS)
        return BundledThumbnailImage(contentsOfFile: url.path)
#elseif os(macOS)
        return BundledThumbnailImage(contentsOf: url)
#endif
    }
}

enum BundledSceneModelLoader {
    static func node(named modelName: String?) -> SCNNode? {
        guard let url = SceneObjectAssetResolver.modelURL(named: modelName) else {
            return nil
        }
        let resourceExtension = url.pathExtension.isEmpty ? "glb" : url.pathExtension

        let loadedNode: SCNNode?
        if let scene = try? SCNScene(url: url) {
            let root = SCNNode()
            for child in scene.rootNode.childNodes {
                root.addChildNode(child.clone())
            }
            loadedNode = root
        } else if resourceExtension.lowercased() == "glb" {
            loadedNode = GLBSceneKitLoader.node(url: url)
        } else {
            loadedNode = nil
        }

        guard let root = loadedNode else { return nil }
        normalize(root)
        return root
    }

    static func fittedNode(named modelName: String?, targetLongestAxis: Float) -> SCNNode? {
        guard let node = node(named: modelName) else { return nil }
        ensureVisibleMaterials(in: node)

        let wrapper = SCNNode()
        wrapper.addChildNode(node)
        center(node, in: wrapper)
        scaleToFit(wrapper, targetLongestAxis: targetLongestAxis)
        return wrapper
    }

    static func scaleToFit(_ node: SCNNode, targetLongestAxis: Float) {
        guard targetLongestAxis.isFinite, targetLongestAxis > 0 else { return }
        let longestAxis = longestAxis(for: node)
        guard longestAxis.isFinite, longestAxis > 0 else { return }

        let scale = targetLongestAxis / longestAxis
        node.scale = SCNVector3(
            sceneScalar(Float(node.scale.x) * scale),
            sceneScalar(Float(node.scale.y) * scale),
            sceneScalar(Float(node.scale.z) * scale)
        )
    }

    static func longestAxis(for node: SCNNode) -> Float {
        guard let bounds = recursiveBounds(for: node, relativeTo: node) else { return 0 }
        let size = bounds.size
        let rawAxis = max(Float(size.x), max(Float(size.y), Float(size.z)))
        let rootScale = max(abs(Float(node.scale.x)), max(abs(Float(node.scale.y)), abs(Float(node.scale.z))))
        return rawAxis * rootScale
    }

    private static func normalize(_ node: SCNNode) {
        guard let bounds = recursiveBounds(for: node, relativeTo: node) else { return }
        let longestAxis = max(Float(bounds.size.x), max(Float(bounds.size.y), Float(bounds.size.z)))
        guard longestAxis.isFinite, longestAxis > 0 else { return }

        let scale = 1 / longestAxis

        node.scale = SCNVector3(sceneScalar(scale), sceneScalar(scale), sceneScalar(scale))
        node.position = SCNVector3(
            sceneScalar(-Float(bounds.center.x) * scale),
            sceneScalar(-Float(bounds.center.y) * scale),
            sceneScalar(-Float(bounds.center.z) * scale)
        )
    }

    private static func center(_ node: SCNNode, in root: SCNNode) {
        guard let bounds = recursiveBounds(for: root, relativeTo: root) else { return }
        node.position = SCNVector3(
            sceneScalar(Float(node.position.x) - Float(bounds.center.x)),
            sceneScalar(Float(node.position.y) - Float(bounds.center.y)),
            sceneScalar(Float(node.position.z) - Float(bounds.center.z))
        )
    }

    private static func recursiveBounds(for node: SCNNode, relativeTo root: SCNNode) -> ModelBounds? {
        recursiveBounds(for: node, transform: SCNMatrix4Identity)
    }

    private static func recursiveBounds(for node: SCNNode, transform: SCNMatrix4) -> ModelBounds? {
        var result: ModelBounds?

        if node.geometry != nil {
            let localBounds = node.boundingBox
            let corners = [
                SCNVector3(localBounds.min.x, localBounds.min.y, localBounds.min.z),
                SCNVector3(localBounds.min.x, localBounds.min.y, localBounds.max.z),
                SCNVector3(localBounds.min.x, localBounds.max.y, localBounds.min.z),
                SCNVector3(localBounds.min.x, localBounds.max.y, localBounds.max.z),
                SCNVector3(localBounds.max.x, localBounds.min.y, localBounds.min.z),
                SCNVector3(localBounds.max.x, localBounds.min.y, localBounds.max.z),
                SCNVector3(localBounds.max.x, localBounds.max.y, localBounds.min.z),
                SCNVector3(localBounds.max.x, localBounds.max.y, localBounds.max.z)
            ]

            for corner in corners {
                result = result.expanded(toInclude: corner.transformed(by: transform))
            }
        }

        for child in node.childNodes {
            let childTransform = SCNMatrix4Mult(transform, child.transform)
            if let childBounds = recursiveBounds(for: child, transform: childTransform) {
                result = result.expanded(toInclude: childBounds.min)
                result = result.expanded(toInclude: childBounds.max)
            }
        }

        return result
    }

    private static func ensureVisibleMaterials(in node: SCNNode) {
        node.enumerateChildNodes { child, _ in
            guard let geometry = child.geometry else { return }
            if geometry.materials.isEmpty {
                geometry.materials = [fallbackModelMaterial()]
            }

            for material in geometry.materials {
                material.isDoubleSided = true
                if material.transparency <= 0 {
                    material.transparency = 1
                }
                if material.diffuse.contents == nil {
                    material.diffuse.contents = LoaderColor(white: 0.84, alpha: 1)
                }
                if material.emission.contents == nil {
                    material.emission.contents = LoaderColor(white: 0.10, alpha: 1)
                }
            }
        }
    }

    private static func fallbackModelMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = LoaderColor(white: 0.84, alpha: 1)
        material.emission.contents = LoaderColor(white: 0.10, alpha: 1)
        material.roughness.contents = 0.72
        material.isDoubleSided = true
        return material
    }

    fileprivate struct ModelBounds {
        let min: SCNVector3
        let max: SCNVector3

        var center: SCNVector3 {
            SCNVector3(
                (min.x + max.x) / 2,
                (min.y + max.y) / 2,
                (min.z + max.z) / 2
            )
        }

        var size: SCNVector3 {
            SCNVector3(max.x - min.x, max.y - min.y, max.z - min.z)
        }
    }
}

#if DEBUG
extension BundledSceneModelLoader {
    static func debugBounds(for node: SCNNode) -> (min: SCNVector3, max: SCNVector3)? {
        guard let bounds = recursiveBounds(for: node, relativeTo: node) else { return nil }
        return (bounds.min, bounds.max)
    }

    static func debugNode(matrix: [Double]) -> SCNNode? {
        guard matrix.count == 16 else { return nil }
        let node = SCNNode()
        node.transform = SCNMatrix4(
            m11: sceneScalar(matrix[0]), m12: sceneScalar(matrix[1]), m13: sceneScalar(matrix[2]), m14: sceneScalar(matrix[3]),
            m21: sceneScalar(matrix[4]), m22: sceneScalar(matrix[5]), m23: sceneScalar(matrix[6]), m24: sceneScalar(matrix[7]),
            m31: sceneScalar(matrix[8]), m32: sceneScalar(matrix[9]), m33: sceneScalar(matrix[10]), m34: sceneScalar(matrix[11]),
            m41: sceneScalar(matrix[12]), m42: sceneScalar(matrix[13]), m43: sceneScalar(matrix[14]), m44: sceneScalar(matrix[15])
        )
        return node
    }

    static func debugNode(rotation: [Double]) -> SCNNode? {
        guard rotation.count >= 4 else { return nil }
        let node = SCNNode()
        node.orientation = SCNQuaternion(sceneScalar(rotation[0]), sceneScalar(rotation[1]), sceneScalar(rotation[2]), sceneScalar(rotation[3]))
        return node
    }
}
#endif

private extension Optional where Wrapped == BundledSceneModelLoader.ModelBounds {
    func expanded(toInclude point: SCNVector3) -> BundledSceneModelLoader.ModelBounds {
        guard let bounds = self else {
            return BundledSceneModelLoader.ModelBounds(min: point, max: point)
        }

        return BundledSceneModelLoader.ModelBounds(
            min: SCNVector3(
                Swift.min(bounds.min.x, point.x),
                Swift.min(bounds.min.y, point.y),
                Swift.min(bounds.min.z, point.z)
            ),
            max: SCNVector3(
                Swift.max(bounds.max.x, point.x),
                Swift.max(bounds.max.y, point.y),
                Swift.max(bounds.max.z, point.z)
            )
        )
    }
}

private extension SCNVector3 {
    func transformed(by matrix: SCNMatrix4) -> SCNVector3 {
        SCNVector3(
            sceneScalar(Float(x) * Float(matrix.m11) + Float(y) * Float(matrix.m21) + Float(z) * Float(matrix.m31) + Float(matrix.m41)),
            sceneScalar(Float(x) * Float(matrix.m12) + Float(y) * Float(matrix.m22) + Float(z) * Float(matrix.m32) + Float(matrix.m42)),
            sceneScalar(Float(x) * Float(matrix.m13) + Float(y) * Float(matrix.m23) + Float(z) * Float(matrix.m33) + Float(matrix.m43))
        )
    }
}

private enum GLBSceneKitLoader {
    static func node(url: URL) -> SCNNode? {
        guard let data = try? Data(contentsOf: url),
              data.count >= 20,
              data.uint32(at: 0) == 0x4654_6C67 else {
            return nil
        }

        var offset = 12
        var jsonData: Data?
        var binaryData: Data?

        while offset + 8 <= data.count {
            let chunkLength = Int(data.uint32(at: offset))
            let chunkType = data.uint32(at: offset + 4)
            let chunkStart = offset + 8
            let chunkEnd = min(chunkStart + chunkLength, data.count)
            guard chunkStart <= data.count, chunkEnd <= data.count else { return nil }

            let chunk = data.subdata(in: chunkStart..<chunkEnd)
            if chunkType == 0x4E4F_534A {
                jsonData = chunk
            } else if chunkType == 0x004E_4942 {
                binaryData = chunk
            }
            offset = chunkEnd
        }

        guard let jsonData,
              let binaryData,
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }

        let context = GLBContext(json: json, binaryData: binaryData)
        return context.rootNode()
    }
}

private struct GLBContext {
    let json: [String: Any]
    let binaryData: Data

    var accessors: [[String: Any]] { json["accessors"] as? [[String: Any]] ?? [] }
    var bufferViews: [[String: Any]] { json["bufferViews"] as? [[String: Any]] ?? [] }
    var meshes: [[String: Any]] { json["meshes"] as? [[String: Any]] ?? [] }
    var nodes: [[String: Any]] { json["nodes"] as? [[String: Any]] ?? [] }
    var scenes: [[String: Any]] { json["scenes"] as? [[String: Any]] ?? [] }
    var materials: [[String: Any]] { json["materials"] as? [[String: Any]] ?? [] }

    func rootNode() -> SCNNode? {
        let root = SCNNode()
        let sceneIndex = json["scene"] as? Int ?? 0
        let sceneNodes = scenes[safe: sceneIndex]?["nodes"] as? [Int]
            ?? Array(nodes.indices)

        for nodeIndex in sceneNodes {
            if let child = makeNode(index: nodeIndex) {
                root.addChildNode(child)
            }
        }

        return root.childNodes.isEmpty ? nil : root
    }

    private func makeNode(index: Int) -> SCNNode? {
        guard let nodeJSON = nodes[safe: index] else { return nil }
        let node = SCNNode()
        node.name = nodeJSON["name"] as? String

        if let meshIndex = nodeJSON["mesh"] as? Int,
           let meshNode = makeMeshNode(index: meshIndex) {
            node.addChildNode(meshNode)
        }

        for childIndex in nodeJSON["children"] as? [Int] ?? [] {
            if let child = makeNode(index: childIndex) {
                node.addChildNode(child)
            }
        }

        applyTransform(nodeJSON, to: node)
        return node
    }

    private func makeMeshNode(index: Int) -> SCNNode? {
        guard let mesh = meshes[safe: index],
              let primitives = mesh["primitives"] as? [[String: Any]] else {
            return nil
        }

        let root = SCNNode()
        root.name = mesh["name"] as? String

        for primitive in primitives {
            guard let geometry = makeGeometry(primitive: primitive) else { continue }
            root.addChildNode(SCNNode(geometry: geometry))
        }

        return root.childNodes.isEmpty ? nil : root
    }

    private func makeGeometry(primitive: [String: Any]) -> SCNGeometry? {
        guard let attributes = primitive["attributes"] as? [String: Int],
              let positionAccessor = attributes["POSITION"],
              let vertices = vectors(accessorIndex: positionAccessor, dimensions: 3) else {
            return nil
        }

        var sources = [SCNGeometrySource(vertices: vertices)]
        if let normalAccessor = attributes["NORMAL"],
           let normals = vectors(accessorIndex: normalAccessor, dimensions: 3),
           normals.count == vertices.count {
            sources.append(SCNGeometrySource(normals: normals))
        }

        let element: SCNGeometryElement
        if let indicesAccessor = primitive["indices"] as? Int,
           let indices = indices(accessorIndex: indicesAccessor) {
            element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        } else {
            let indices = vertices.indices.map(Int32.init)
            element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        }

        let geometry = SCNGeometry(sources: sources, elements: [element])
        geometry.firstMaterial = material(index: primitive["material"] as? Int)
        return geometry
    }

    private func vectors(accessorIndex: Int, dimensions: Int) -> [SCNVector3]? {
        guard let accessor = accessors[safe: accessorIndex],
              accessor["componentType"] as? Int == 5126,
              let count = accessor["count"] as? Int,
              let bufferViewIndex = accessor["bufferView"] as? Int,
              let bufferView = bufferViews[safe: bufferViewIndex] else {
            return nil
        }

        let accessorOffset = accessor["byteOffset"] as? Int ?? 0
        let viewOffset = bufferView["byteOffset"] as? Int ?? 0
        let stride = bufferView["byteStride"] as? Int ?? dimensions * 4
        let start = viewOffset + accessorOffset

        var result: [SCNVector3] = []
        result.reserveCapacity(count)

        for index in 0..<count {
            let offset = start + index * stride
            guard offset + dimensions * 4 <= binaryData.count else { return nil }

            let x = binaryData.float32(at: offset)
            let y = dimensions > 1 ? binaryData.float32(at: offset + 4) : 0
            let z = dimensions > 2 ? binaryData.float32(at: offset + 8) : 0
            result.append(SCNVector3(x, y, z))
        }

        return result
    }

    private func indices(accessorIndex: Int) -> [Int32]? {
        guard let accessor = accessors[safe: accessorIndex],
              let count = accessor["count"] as? Int,
              let componentType = accessor["componentType"] as? Int,
              let bufferViewIndex = accessor["bufferView"] as? Int,
              let bufferView = bufferViews[safe: bufferViewIndex] else {
            return nil
        }

        let componentSize: Int
        switch componentType {
        case 5121:
            componentSize = 1
        case 5123:
            componentSize = 2
        case 5125:
            componentSize = 4
        default:
            return nil
        }

        let accessorOffset = accessor["byteOffset"] as? Int ?? 0
        let viewOffset = bufferView["byteOffset"] as? Int ?? 0
        let stride = bufferView["byteStride"] as? Int ?? componentSize
        let start = viewOffset + accessorOffset

        var result: [Int32] = []
        result.reserveCapacity(count)

        for index in 0..<count {
            let offset = start + index * stride
            guard offset + componentSize <= binaryData.count else { return nil }

            switch componentType {
            case 5121:
                result.append(Int32(binaryData[offset]))
            case 5123:
                result.append(Int32(binaryData.uint16(at: offset)))
            case 5125:
                result.append(Int32(bitPattern: binaryData.uint32(at: offset)))
            default:
                return nil
            }
        }

        return result
    }

    private func material(index: Int?) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = loaderColor(red: 0.82, green: 0.84, blue: 0.88, alpha: 1)
        material.roughness.contents = 0.78

        guard let index,
              let materialJSON = materials[safe: index],
              let pbr = materialJSON["pbrMetallicRoughness"] as? [String: Any],
              let color = pbr["baseColorFactor"] as? [Double],
              color.count >= 3 else {
            return material
        }

        material.diffuse.contents = loaderColor(
            red: CGFloat(color[0]),
            green: CGFloat(color[1]),
            blue: CGFloat(color[2]),
            alpha: CGFloat(color[safe: 3] ?? 1)
        )
        return material
    }

    private func applyTransform(_ nodeJSON: [String: Any], to node: SCNNode) {
        if let matrix = nodeJSON["matrix"] as? [Double], matrix.count == 16 {
            node.transform = SCNMatrix4(
                m11: sceneScalar(matrix[0]), m12: sceneScalar(matrix[1]), m13: sceneScalar(matrix[2]), m14: sceneScalar(matrix[3]),
                m21: sceneScalar(matrix[4]), m22: sceneScalar(matrix[5]), m23: sceneScalar(matrix[6]), m24: sceneScalar(matrix[7]),
                m31: sceneScalar(matrix[8]), m32: sceneScalar(matrix[9]), m33: sceneScalar(matrix[10]), m34: sceneScalar(matrix[11]),
                m41: sceneScalar(matrix[12]), m42: sceneScalar(matrix[13]), m43: sceneScalar(matrix[14]), m44: sceneScalar(matrix[15])
            )
        }

        if let translation = nodeJSON["translation"] as? [Double], translation.count >= 3 {
            node.position = SCNVector3(sceneScalar(translation[0]), sceneScalar(translation[1]), sceneScalar(translation[2]))
        }

        if let scale = nodeJSON["scale"] as? [Double], scale.count >= 3 {
            node.scale = SCNVector3(sceneScalar(scale[0]), sceneScalar(scale[1]), sceneScalar(scale[2]))
        }

        if let rotation = nodeJSON["rotation"] as? [Double], rotation.count >= 4 {
            node.orientation = SCNQuaternion(sceneScalar(rotation[0]), sceneScalar(rotation[1]), sceneScalar(rotation[2]), sceneScalar(rotation[3]))
        }
    }
}

private func loaderColor(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) -> LoaderColor {
#if os(iOS)
    LoaderColor(red: red, green: green, blue: blue, alpha: alpha)
#elseif os(macOS)
    LoaderColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
#endif
}

private func sceneScalar(_ value: Float) -> SceneScalar {
    SceneScalar(value)
}

private func sceneScalar(_ value: Double) -> SceneScalar {
    SceneScalar(value)
}

private extension Data {
    func uint16(at offset: Int) -> UInt16 {
        subdata(in: offset..<(offset + 2)).withUnsafeBytes {
            UInt16(littleEndian: $0.load(as: UInt16.self))
        }
    }

    func uint32(at offset: Int) -> UInt32 {
        subdata(in: offset..<(offset + 4)).withUnsafeBytes {
            UInt32(littleEndian: $0.load(as: UInt32.self))
        }
    }

    func float32(at offset: Int) -> Float {
        Float(bitPattern: uint32(at: offset))
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
