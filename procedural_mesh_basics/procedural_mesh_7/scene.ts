/**
 * Build a cube using a reusable quad helper.
 */
function createQuad(corners: number[], normal: [number, number, number], doubleSided = true) {
    const vertices = [...corners];
    const indices: number[] = [0, 1, 2, 0, 2, 3];
    const normals: number[] = [
        normal[0], normal[1], normal[2],
        normal[0], normal[1], normal[2],
        normal[0], normal[1], normal[2],
        normal[0], normal[1], normal[2]
    ];
    const uvs: number[] = [
        0, 0,
        1, 0,
        1, 1,
        0, 1,
    ]; // TODO: add UVs for each quad

    if (doubleSided) {
        indices.push(0, 2, 1, 0, 3, 2);
    }

    return { vertices, indices, normals, uvs };
}

function appendQuad(target: ProceduralMeshData, quad: { vertices: number[]; indices: number[]; normals: number[]; uvs: number[] }) {
    const vertexOffset = target.vertices.length / 3;
    target.vertices.push(...quad.vertices);
    target.normals.push(...quad.normals);
    target.uvs.push(...quad.uvs);
    quad.indices.forEach((index) => target.indices.push(index + vertexOffset));
}

function createMesh(): ProceduralMeshData {
    const mesh: ProceduralMeshData = {
        vertices: [],
        indices: [],
        normals: [],
        uvs: [],
        colors: []
    };

    const halfSize = 2.0;

    appendQuad(mesh, createQuad([
        -halfSize, -halfSize,  halfSize,
         halfSize, -halfSize,  halfSize,
         halfSize,  halfSize,  halfSize,
        -halfSize,  halfSize,  halfSize
    ], [0.0, 0.0, 1.0]));

    appendQuad(mesh, createQuad([
         halfSize, -halfSize, -halfSize,
        -halfSize, -halfSize, -halfSize,
        -halfSize,  halfSize, -halfSize,
         halfSize,  halfSize, -halfSize
    ], [0.0, 0.0, -1.0]));

    appendQuad(mesh, createQuad([
         halfSize, -halfSize,  halfSize,
         halfSize, -halfSize, -halfSize,
         halfSize,  halfSize, -halfSize,
         halfSize,  halfSize,  halfSize
    ], [1.0, 0.0, 0.0]));

    appendQuad(mesh, createQuad([
        -halfSize, -halfSize, -halfSize,
        -halfSize, -halfSize,  halfSize,
        -halfSize,  halfSize,  halfSize,
        -halfSize,  halfSize, -halfSize
    ], [-1.0, 0.0, 0.0]));

    appendQuad(mesh, createQuad([
        -halfSize,  halfSize,  halfSize,
         halfSize,  halfSize,  halfSize,
         halfSize,  halfSize, -halfSize,
        -halfSize,  halfSize, -halfSize
    ], [0.0, 1.0, 0.0]));

    appendQuad(mesh, createQuad([
        -halfSize, -halfSize, -halfSize,
         halfSize, -halfSize, -halfSize,
         halfSize, -halfSize,  halfSize,
        -halfSize, -halfSize,  halfSize
    ], [0.0, -1.0, 0.0]));

    return mesh;
}

