/**
 * The profile of the vase: its radius at a height t, from 0 at the bottom to 1 at the top.
 */
function radiusAt(t: number): number {
    return 1.4 + 2.4 * Math.sin(Math.PI * t * 0.9) + 0.6 * Math.sin(Math.PI * 3.0 * t);
}

function createMesh(): ProceduralMeshData {
    const mesh: ProceduralMeshData = {
        vertices: [],
        indices: [],
        normals: [],
        uvs: [],
        colors: []
    };

    const rows = 40;
    const segments = 24;
    const height = 11.0;

    // Where each ring starts and ends, which puts the seam at the front of the vase
    const startAngle = Math.PI / 4;

    // TODO 1: For each row from 0 to rows, compute t, y and the radius from radiusAt(t).
    for (let row = 0; row <= rows; row++) {
        const t = row / rows;
        const y = (t - 0.5) * height;
        const radius = radiusAt(t);
        // TODO 2: For each segment from 0 to segments (including segments), compute u and
        // angle = startAngle + u * Math.PI * 2.0, then push the vertex (radius * cos, y, radius * sin) and the UV (u, t).
        for (let segment = 0; segment <= segments; segment++) {
            const u = segment / segments;
            const angle = startAngle + u * Math.PI * 2.0;
            const cos = Math.cos(angle);
            const sin = Math.sin(angle);

            mesh.vertices.push(radius * cos, y, radius * sin);
            mesh.uvs.push(u, t);

            // TODO 3: Tilt each normal using the slope of the profile. Normalize (cos, -slope, sin), where:
            // slope = (radiusAt(t + 0.001) - radiusAt(t - 0.001)) / (2.0 * 0.001 * height)
            const eps = 0.001;
            const slope = (radiusAt(t + eps) - radiusAt(t - eps)) / (2.0 * eps * height);
            const length = Math.sqrt(1.0 + slope * slope);
            mesh.normals.push(cos / length, -slope / length, sin / length);
        }
    }

    // TODO 4: Connect each ring to the next with two triangles per segment. For the four corners
    // a, b = a + 1, c = a + ringSize and d = c + 1, push the indices a, b, c, b, d, c.
    const ringSize = segments + 1;
    for (let row = 0; row < rows; row++) {
        for (let segment = 0; segment < segments; segment++) {
            const a = row * ringSize + segment;
            const b = a + 1;
            const c = a + ringSize;
            const d = c + 1;
            mesh.indices.push(a, b, c, b, d, c);
        }
    }
    return mesh;
}
