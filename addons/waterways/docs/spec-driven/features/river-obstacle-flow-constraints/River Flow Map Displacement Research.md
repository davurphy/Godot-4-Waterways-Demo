# **Flow-Map-Driven Height Displacement for River Water Rendering**

## **Architectural Overview of River Displacement Rendering**

The rendering of dynamic, believable river systems in real-time applications requires a fundamental departure from traditional ocean rendering techniques. While ocean simulation typically relies on the superposition of Gerstner waves or Fast Fourier Transform (FFT) grids to simulate wind-driven swells over unbounded, planar domains, rivers represent bounded, directional fluid flow heavily constrained by underlying topography. The physical behavior of river water is defined by gravity-driven advection, localized pressure differentials, friction from riverbanks, and collision with submerged or emergent obstacles. Consequently, the visual representation of rivers necessitates an architecture where surface motion is explicitly guided by a pre-computed or procedurally generated flow map, rather than global directional vectors.  
The core architectural challenge within the context of a project such as the "Godot 4 Waterways Demo" involves transferring the two-dimensional directional data encoded within a flow map into convincing three-dimensional vertical displacement. The objective is to ensure that the water surface physically rises, falls, and churns as it travels downstream, augmenting the existing FlowUVW() normal-map advection system. However, advecting a finite height texture through a variable vector field inevitably leads to severe visual distortion, as the texture coordinates stretch uncontrollably in areas of high flow divergence or shear.  
To mitigate this distortion, industry-standard techniques rely on periodic two-phase advection, where two overlapping layers of the texture are continuously reset and blended to hide the resetting seam.1 While this method is highly effective for high-frequency normal maps and albedo foam textures, applying it directly to vertex displacement introduces significant mathematical and visual complications. The continuous blending of two height fields often results in "pulsing" or "breathing" artifacts—a phenomenon where the total volume or height of the water surface unnaturally swells and collapses during the phase blend transition due to variance loss.3 Furthermore, translating vertices along the normal axis invalidates the pre-calculated geometry normals, requiring complex and performance-intensive normal reconstruction within the shader pipeline to maintain accurate lighting, specular highlights, and environmental refraction.4  
This report presents an exhaustive analysis of production-quality techniques for implementing flow-map-driven height displacement, specifically tailored for a Godot 4 rendering architecture. The analysis addresses mathematical blending models, vertex normal reconstruction utilizing finite differences, data channel packing strategies, engine-specific constraints related to transparency sorting and frustum culling, and the seamless integration of dynamic runtime ripple systems.

## **Foundational Literature and Reference Implementations**

The development of modern river rendering heavily relies on techniques pioneered in the AAA game industry, specifically regarding flow mapping and localized wave generation. The following table identifies ten critical sources and reference implementations that inform the techniques discussed throughout this report, highlighting their specific relevance to flow-map-driven displacement and shader architecture.

| Source Identification | Reference / URL | Relevance to River Displacement Architecture |
| :---- | :---- | :---- |
| **Valve's Flow Maps** | *Water Flow in Portal 2* (Vlachos, 2010\) \[[https://www.valvesoftware.com/en/publications](https://www.valvesoftware.com/en/publications)\] | Establishes the foundational two-phase flow advection model used across the industry. Crucial for understanding how offsetting phases and injecting noise masks reduces the visual repetition and pulsing artifacts inherent in advected textures.1 |
| **Naughty Dog Rapids** | *Rendering Rapids in Uncharted 4* (Gonzalez-Ochoa, 2016\) \[[https://advances.realtimerendering.com/s2016/](https://advances.realtimerendering.com/s2016/)\] | Details the deconstruction of water motion into geometric and visual elements. Essential for understanding how to decouple static obstacle pressure pillows from dynamic flow, and introduces the concept of phase-shifted vertex displacement to avoid advection stretching entirely.8 |
| **Wave Particles** | *Implementing Wave Particles for Real-time Water Waves* (Yuksel et al., 2007\) \[[https://github.com/LanLou123/waveparticle](https://github.com/LanLou123/waveparticle)\] | Provides the theoretical basis for superimposing localized, height-altering particles over a flowing mesh. Highly relevant for integrating the runtime ripple simulation into the flow-driven base displacement.3 |
| **Catlike Coding** | *Flow, Texture Distortion* (Unity Tutorial) \[[https://catlikecoding.com/unity/tutorials/flow/texture-distortion/](https://catlikecoding.com/unity/tutorials/flow/texture-distortion/)\] | Offers practical shader implementation patterns for translating Valve's flow map theories into HLSL/Shader Graph. Demonstrates scaling flow velocity, variance-preserving blending, and advecting heightmaps alongside normal maps.10 |
| **GPU Gems (Ch. 18\)** | *Using Vertex Texture Displacement for Realistic Water Rendering* (Kryachko, 2005\) \[[https://developer.nvidia.com/gpugems/gpugems2/part-ii-shading-lighting-and-shadows/chapter-18-using-vertex-texture-displacement](https://developer.nvidia.com/gpugems/gpugems2/part-ii-shading-lighting-and-shadows/chapter-18-using-vertex-texture-displacement)\] | Explores the fundamental mechanics and costs of vertex texture fetches (VTF). Critical for understanding the hardware implications of sampling heightmaps in the vertex shader stage before rasterization.12 |
| **Normal Reconstruction** | *Pixel Displacement Mapping with Distance Functions* (GPU Gems 2, Ch. 8\) \[[https://developer.nvidia.com/gpugems/gpugems2/part-i-geometric-complexity/chapter-8-pixel-displacement-mapping-distance-functions](https://developer.nvidia.com/gpugems/gpugems2/part-i-geometric-complexity/chapter-8-pixel-displacement-mapping-distance-functions)\] | Discusses the necessity of deriving surface normals via finite differences when standard screen-space derivatives (dFdx) are unavailable or produce seams, directly applicable to vertex shader normal generation.13 |
| **Godot 4 Refraction** | *Reading from depth texture produces noticeable artifacts with MSAA enabled* (Godot Forum, 2024\) \[[https://forum.godotengine.org/t/reading-from-depth-texture-produces-noticeable-artifacts-with-msaa-enabled/71544](https://forum.godotengine.org/t/reading-from-depth-texture-produces-noticeable-artifacts-with-msaa-enabled/71544)\] | Highlights a critical, engine-specific constraint in Godot 4 where depth textures bleed on the edges of submerged objects during refraction when MSAA is active. Essential for resolving edge seams.14 |
| **Godot Spatial Shaders** | *Spatial Shader Built-ins* (Godot Documentation) \[[https://docs.godotengine.org/en/stable/tutorials/shaders/shader\_reference/spatial\_shader.html](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)\] | Defines the strict pipeline stages of Godot 4's spatial shaders, including the requirement of transforming reconstructed normals from local space using MODELVIEW\_MATRIX and handling the textureLod constraint in the vertex function.15 |
| **AABB & Culling** | *Godot 4 PrimitiveMesh AABB Override* (Godot Documentation) \[[https://docs.godotengine.org/cs/stable/classes/class\_primitivemesh.html](https://docs.godotengine.org/cs/stable/classes/class_primitivemesh.html)\] | Documents the set\_custom\_aabb() method, providing the explicit engine API required to prevent the CPU from frustum-culling water meshes whose vertices have been displaced outside their original bounds by the GPU shader.17 |
| **Ubisoft River Tech** | *Interactive visualization of simulation data for rivers* (Assassins Creed III Context) | Analyzes how AAA open-world titles align displacement maps to river velocity fields and manage the divergence of water flowing around procedural environments.18 |

## **Theoretical Paradigms in AAA River Rendering**

A comprehensive review of rendering techniques utilized in high-fidelity simulation and gaming reveals several distinct paradigms for solving the river displacement problem. Understanding these historical and theoretical approaches is critical for selecting the optimal implementation strategy for a Godot 4 architecture.

### **The Two-Phase Blended Advection Model**

Initially popularized by Valve for titles such as *Left 4 Dead 2* and *Portal 2*, this technique relies on artist-authored or fluid-simulated flow maps that define a dense 2D vector field across the water surface.1 A generic noise texture or normal map is sampled twice using UV coordinates that are progressively distorted by the underlying flow vectors over a continuous time parameter. Because unbounded distortion eventually stretches the texture beyond recognition, the system restricts the distortion to a short temporal cycle. To hide the sudden snapping that occurs when the texture resets at the end of the cycle, the two samples operate on a staggered phase—offset by precisely half a cycle—and are cross-faded using a pulsating weight function.  
When adapting this established normal-map technique to vertex height displacement, a significant mathematical challenge arises regarding the preservation of energy and volume. If height data is naively blended using linear interpolation (mix in GLSL), the visual height tends to flatten drastically at the midpoint of the blend (the 50% mark). Because the two noise samples are largely uncorrelated, their linear combination drives the resulting value toward the mathematical mean. Visually, this destroys the appearance of volume, causing the river to rhythmically swell and collapse.3 Advanced iterations of this technique resolve this by introducing non-linear, variance-preserving blending functions, or by injecting a third static noise layer to break up the temporal uniformity of the pulsing artifact.1

### **Wave Particles and Phase-Shifted Geometry**

Recognizing that blending two advected heightmaps often fails to capture the aggressive, physical cresting of turbulent rapids, developers at Naughty Dog pioneered a secondary paradigm for the *Uncharted* series.3 They implemented a hybrid system utilizing "Wave Particles" and phase-shifted procedural geometry that completely bypasses the traditional advection of a height texture.3  
In this system, rather than pulling a displacement map across a static mesh, the engine encodes a scalar "phase" value directly into the river mesh vertices or a tightly mapped supporting texture. Each vertex on the river mesh is mathematically driven to move in an anisotropically scaled circle driven by time and its unique phase offset. The global axis of this circle is aligned with the local flow direction. By spacing the phase field organically along the direction of the flow and perpendicular to it, the vertices physicalize the flow natively. This completely eliminates the stretching and pulsing artifacts inherent to texture advection, allowing for highly stable standing waves, deep eddies, and sustained obstacle pillows.21 For extreme localized turbulence, this geometric base is supplemented by spawned wave particles that carry independent height data downstream.3 While visually spectacular, generating the specific phase fields requires a tightly coupled, proprietary asset pipeline that is often difficult to retrofit into existing engines without custom baking tools.

## **The Mathematical Framework of Flow-Map-Driven Displacement**

To implement the two-phase flowed height sampling effectively within a standard shader pipeline, the mathematical functions must be rigorously defined to avoid the structural degradation of the water volume discussed above.

### **Flow Advection Theory and Temporal Cycling**

Given a normalized flow vector field defining the current direction, and a scalar flow speed mapping the magnitude, the advection time variables are computed. A universal phase duration dictates the lifespan of a single texture layer before it is abruptly reset. The shader continuously evaluates the current fractional state of the two offset phases.  
The UV coordinates for the two sampling phases are displaced in the exact opposite direction of the flow vectors. This inverse translation simulates the texture moving forward along the vector field. If the flow vectors diverge or converge (such as water moving around a rock), the UV coordinates are pulled apart or compressed, creating the illusion of realistic fluid dynamics.

### **Variance-Preserving Height Blending**

As previously established, standard linear interpolation of two uncorrelated heightmaps causes a rhythmic reduction in standard deviation (and thus visible wave height) when the blend weight approaches 0.5. To resolve this, variance-preserving blending must be utilized. Instead of interpolating linearly, the sampled heights are blended based on a power-preserving mathematical model.  
The resulting height is calculated by taking the weighted sum of the two height samples and dividing it by the square root of the sum of the squared weights. This specific division ensures that the statistical variance of the noise remains perfectly constant throughout the entire phase cycle. By implementing this algebraic correction, the visual "breathing" artifact that plagues inferior water shaders is completely eliminated, maintaining a constant volume of displacement regardless of the phase transition state.11

### **Height Recentering and Dynamic Amplitude Scaling**

Standard heightmaps encode data in the normalized ![][image1] range. Direct application of this data to the vertical axis vertex position causes the water to strictly rise above its resting geometric plane, effectively ballooning the mesh outward and ruining the alignment with riverbanks. The sampled height must be mathematically centered to allow bidirectional displacement, scaling the ![][image1] range into a ![][image2] range. Consequently, the water physically dips into troughs and rises into crests equally.  
Furthermore, the physical amplitude of the displacement must be dynamically modulated. A static scaling factor applied uniformly across the river is insufficient for a realistic simulation. Displacement intensity must be heavily controlled by the physical attributes encoded in the support maps. The shader should calculate a dynamic amplitude multiplier based on flow speed, turbulence, and foam coverage. Faster currents should naturally generate higher localized waves. Conversely, in highly aerated zones where white-water foam dominates, the high-frequency geometric displacement should be dampened, as the physical structure of the water breaks down into chaotic, smaller-scale particulate movement.

## **River-Specific Physical Phenomena**

True river dynamics are heavily influenced by the interaction of flowing water with shallow terrain, bank friction, and physical obstacles. A robust displacement architecture must account for both advected motion and localized geometric reactions.

### **Standing Waves and Obstacle Pillows**

When high-velocity water encounters an obstruction or a sudden change in depth, it generates hydraulic jumps and standing waves.22 A standing wave exhibits nodes (points of zero vertical displacement) and antinodes (points of maximum vertical displacement) that remain completely stationary in world space despite the continuous, rapid flow of water through them.23 Advecting a heightmap completely fails to capture this phenomenon, as it inherently forces all wave crests to travel downstream.  
To replicate this critical river morphology, modern river shaders rely heavily on "pillow" or "pressure" maps—static textures or vertex color channels that define permanent height displacement around obstacles and riverbanks.24 This low-frequency displacement is completely decoupled from the flow advection mechanism. The water *appears* to flow furiously over these stationary displaced regions because the high-frequency advected normal maps and foam textures slide over the static physical bumps. This combination of static macroscopic vertex displacement and dynamic microscopic surface advection is the cornerstone of rendering rapids and obstacle wakes realistically.8

### **Boundary Management and Clipping**

A persistent issue with aggressive vertex displacement in rivers is the tendency for the displaced water mesh to clip into the surrounding riverbanks or rise through nearby terrain geometry. As the vertices push outward, they exceed the original boundaries of the hand-placed or procedurally generated river mesh.  
To prevent this, the displacement amplitude must be aggressively masked near the edges of the river. The architecture requires a "terrain contact" or "distance-to-bank" feature map. This map acts as an attenuation multiplier, smoothly reducing the displacement strength to zero as the UV coordinates approach the boundaries of the mesh. By forcing the displacement to zero at the banks, the water mesh seamlessly intersects with the terrain exactly where the artist or procedural generation tool intended, preventing visual breaks in the environment.

## **Normal Reconstruction and Lighting Optimization**

When vertices are displaced vertically in the vertex shader stage based on varying texture data, the original pre-computed vertex normals baked into the mesh become instantly invalid.4 If the rendering pipeline's lighting model relies on these original, un-displaced normals, the waves will appear entirely flat. They will fail to receive proper directional diffuse lighting, their specular highlights will not align with the crests, and crucially, they will fail to refract light accurately.  
In standard fragment shaders, surface normals can be quickly inferred using screen-space derivatives (dFdx, dFdy in GLSL) to calculate the cross product of the rate of change of the position.6 However, Godot 4 spatial shaders evaluate vertex displacement in the vertex() function, strictly before fragment rasterization occurs. Screen-space derivatives are mathematically impossible at this stage because adjacent screen pixels do not yet exist.

### **Finite Differences in the Vertex Shader**

To construct accurate normals that reflect the newly displaced geometry, the algorithm must approximate the spatial derivative of the height field using the method of finite differences.5 This requires sampling the total height function at discrete, microscopic neighboring points across the UV space.  
If the base UV coordinate is defined as ![][image3], the shader samples the height function at four adjacent points separated by a very small delta. This samples the height slightly to the left, right, up, and down from the current vertex. The tangent vectors along the geometric ![][image4] and ![][image5] axes of the localized UV space are formed by calculating the differences between these opposing heights. The new analytical vertex normal is derived by calculating the normalized cross product of these two tangent vectors.5  
For even higher precision, a Sobel filter operation can be employed, sampling eight surrounding points to calculate a heavily weighted average of the slope.4 However, executing eight additional discrete texture fetch instructions within a vertex shader creates a substantial memory bandwidth bottleneck, potentially starving the GPU's texture units. For real-time applications running complex lighting models, the 4-tap central difference method is widely considered the optimal balance between performance and accuracy, providing excellent shading without catastrophic overhead.28

### **Blending Analytical and Advected Normals**

Once the structural vertex normal is computed via finite differences, it provides the macro-shading for the physical waves. However, this must be blended with the high-frequency detail normal map (which is undergoing the two-phase flow advection).  
The Godot 4 spatial shader pipeline requires vertex normals to be output in local space, or view space if specifically configured. The new finite-difference normal, along with its calculated tangent and binormal vectors, must replace the standard NORMAL, TANGENT, and BINORMAL outputs in the vertex function.15 This establishes a new dynamic tangent space. In the subsequent fragment() stage, the flowed, blended detail normal map is sampled and assigned to NORMAL\_MAP. The engine then automatically handles the complex transformation of this tangent-space detail map onto the dynamically displaced macroscopic normal. Using mathematically rigorous blending techniques like Reoriented Normal Mapping (RNM) or Unwrapped Normal Blending (UDN) inside the shader can further refine how the micro-details composite over the steep slopes of the displaced waves, preventing the normals from exceeding normalized bounds and causing harsh black lighting artifacts.

## **Data Packing and Support Maps Generation**

To achieve optimal performance and minimize the severe cost of texture sampling, the data required to drive the displacement, masking, and flow must be tightly packed into minimal texture reads. The project architecture currently relies on generated support maps, which should be systematically reorganized to maximize channel efficiency.

### **Optimal Channel Allocation**

**Primary Flow and Dynamics Map (RGBA8 Linear):**

* **R & G Channels:** Flow Vector Direction. The UV directional data is stored here. Values in the ![][image1] range are decoded in the shader into the ![][image2] vector direction.  
* **B Channel:** Flow Speed Magnitude. This scalar value modulates the advection time multiplier and serves as the foundational multiplier for dynamic height intensity.  
* **A Channel:** Turbulence and Pressure Mask. This channel encodes areas representing standing waves, obstacle collisions, and bank resistance, driving the static displacement layers.

**High-Frequency Detail Map (RGBA8 or BC7 Linear):**

* **R & G Channels:** High-frequency Normal Map (derivate ![][image4] and ![][image6]).  
* **B Channel:** Heightmap/Displacement signal. Crucially, this must be stored at full 8-bit or higher precision. Compressing height data with standard DXT1/BC1 compression introduces severe blocking artifacts that translate into jagged, stair-stepped vertex displacement.10  
* **A Channel:** Foam Mask / Phase Noise. A static, non-uniform noise pattern used to locally offset the advection phase, effectively breaking up visual repetition across large stretches of the river.1

Baking these maps requires a rigorous pre-computation step within the engine or a DCC tool. Systems designed by technical artists often utilize curve-driven splines to generate the base flow field. This vector field is then combined with distance fields derived from scene geometry—such as raycasting against riverbeds and imported rock meshes—to generate the localized pressure and turbulence channels accurately.24 Maintaining these textures in Linear color space rather than sRGB is critical; the shader requires raw mathematical data, and sRGB gamma correction curves will inherently skew the flow vectors and height values, leading to incorrect physical movement.

## **Godot 4 Engine Constraints and Optimizations**

Implementing advanced vertex displacement in Godot 4 presents several specific engine-level challenges that require explicit mitigation strategies to ensure stability and performance.

### **Frustum Culling and Custom AABBs**

Godot's rendering engine performs frustum culling on the CPU. It determines whether a mesh is visible to the camera based solely on the predefined Axis-Aligned Bounding Box (AABB) of that mesh.31 Vertex displacement in a spatial shader occurs entirely on the GPU, completely detached from the CPU's spatial awareness. If a vertex is pushed vertically by the shader outside the physical boundaries of its original, undisplaced AABB, the CPU remains ignorant of this new height. Consequently, the engine will aggressively cull the entire river mesh when the camera pans away from the original flat bounds, causing the river to visually "pop" out of existence abruptly.17  
To solve this, the river mesh generation script must programmatically enlarge the bounding box upon initialization. In GDScript, the set\_custom\_aabb() method overrides the default calculated bounds. The custom AABB must expand the Y-axis by the maximum potential displacement amplitude globally applied to the shader, ensuring the CPU's culling heuristics account for the GPU's modifications.

### **Transparent Depth, Refraction, and Edge Seams**

High-quality river shaders rely heavily on reading the background SCREEN\_TEXTURE and the DEPTH\_TEXTURE using the current SCREEN\_UV coordinates. This data is utilized to calculate depth-fade (via the Beer-Lambert law) and to apply optical refraction.33 Refraction physically bends the light, meaning the shader must sample a pixel slightly offset from the current SCREEN\_UV based on the surface normal.  
However, when a vertex is displaced vertically, and the refraction calculation offsets the screen read, the shader will frequently sample pixels belonging to an opaque object that is physically *in front* of the water (for example, a rock jutting out of the rapid). Because the water is rendered in the transparent pass—strictly after all opaque objects have populated the screen and depth buffers—the pixel belonging to the foreground rock bleeds into the water surface. This creates a severe, vibrating halo or seam around submerged and intersecting objects.14 This artifact is significantly exacerbated when Multisample Anti-Aliasing (MSAA) is enabled in Godot 4, causing the depth texture to bleed further along edges.14  
This artifact is resolved through rigorous dynamic depth testing within the fragment shader. Before applying the final refracted color, the shader must sample the depth buffer at the specifically *refracted* UV coordinates. It converts this raw depth value into view-space depth and compares it directly against the view-space depth of the currently rendering displaced water vertex (VERTEX.z). If the sampled depth is closer to the camera than the water surface itself, the refraction vector is invalid—it has intersected an object in front of the water. In this scenario, the shader must gracefully fall back to sampling the un-refracted SCREEN\_UV to eliminate the bleeding seam.36

### **Texture Sampling Constraints in the Vertex Shader**

In Godot 4's spatial shader language, the standard texture() function cannot be utilized within the vertex() processing block. Standard texture sampling relies on implicit screen-space derivatives (dFdx/dFdy) to calculate the appropriate mipmap Level of Detail (LOD) to sample, preventing aliasing. Because these derivatives do not exist during vertex processing, texture sampling in vertex shaders must explicitly define the mipmap LOD using the textureLod() function.38  
When sampling heightmaps for finite differences, using textureLod(displacement\_map, uv, 0.0) forces the shader to read the highest resolution mipmap. Ensuring LOD 0 is strictly enforced for the normal reconstruction prevents the analytical normals from artificially smoothing out and losing structural definition as the camera distance increases.

### **Tessellation and Mesh Subdivision**

Unlike previous generations of graphics APIs (such as DirectX 11), Godot 4 does not currently expose hardware tessellation (Tessellation Control and Evaluation Shaders) natively through its standard spatial shader API.41 Consequently, dynamic, hardware-accelerated subdivision of triangles based on camera distance is not natively available for water materials.  
Vertex displacement fundamentally requires a dense geometric topology; attempting to displace a low-poly mesh will result in sharp, jagged spikes rather than smooth, rolling waves.44 The project architecture must therefore rely on heavily pre-subdivided source meshes for the river geometry.45 To maintain performance across variable hardware, continuous Level of Detail (LOD) must be generated offline or during the procedural mesh generation phase, ensuring denser vertex counts near the active play area and aggressive geometric decimation at a distance. If an ArrayMesh is utilized, the engine's built-in shadow meshes should ideally match the displaced geometry to prevent light leaks, though entirely disabling shadow casting on the transparent water mesh is standard industry practice for performance.32

## **Runtime Ripples Integration**

The project architecture features an existing runtime ripple simulation system equipped with ripple height and normal sampling helpers. A critical technical goal is marrying this localized, highly responsive ripple simulation with the broad, flow-driven river displacement.  
Runtime ripple displacement data is typically generated via a render target containing a dynamically updated simulation (e.g., executing shallow water equations or wave particle logic computed on a buffer). The resulting ripple height buffer can be sampled within the vertex shader simultaneously with the flow advection logic. The key mathematical insight is that the ripple height acts as a strict superposition over the base flow.  
The combined height is calculated as the sum of the flowed height and the product of the ripple height, a spatial bounding mask, and a localized strength multiplier. Because ripple textures operate in absolute world space or a localized 2D orthographic bounding box, the UV space used to sample them differs significantly from the river's flow-aligned UVs.  
Crucially, the finite difference calculation utilized for the vertex normal reconstruction must incorporate this new ripple height field. Instead of evaluating the spatial derivative of only the advected flow height, the central difference function must evaluate the *combined* total height function. This ensures that the reconstructed normal accurately reflects the complex geometric interaction between the fast-moving river current and the dynamically expanding, outward-radiating ripples. To optimize performance and prevent unnecessary texture fetches, the ripple displacement should dynamically fade with distance. An attenuation factor based on the length of the view-space distance (VERTEX.z) smoothly scales the ripple contribution down to zero at far distances, bypassing the render target lookup entirely when out of effective visual range.

## **Technique Evaluation and Matrix**

To determine the most viable approach for integrating height displacement into the existing Godot 4 architecture, multiple techniques were evaluated across various production vectors.

| Technique | Visual Quality | Implementation Complexity | Performance Cost | Godot 4 Compatibility | Risk of Artifacts | Suitability for Rivers / Rapids |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| **1\. Hybrid Model: 2-Phase Variance-Preserved Advection \+ Static Pressure Maps** | Very High | High | Medium | Excellent (Fully supported via textureLod and spatial shaders) | Low (if blended non-linearly to preserve volume) | Very High; captures both moving high-frequency chop and stationary low-frequency obstacle pillows perfectly. |
| **2\. Phase-Shifted Anisotropic Vertex Circles (Naughty Dog Style)** | High | Very High | Low (Eliminates complex advection math) | Good (Requires complex custom mesh data baking outside standard pipelines) | Low | High; excellent for large rolling rapids, but less effective for fine surface ripples or intricate flow divergence. |
| **3\. Naive 2-Phase Linear Height Advection** | Medium | Low | Low | Excellent | High (Severe pulsing, extreme volume loss at the 50% phase transition) | Low; water appears to breathe unnaturally, failing to represent physical fluid volume accurately. |
| **4\. Real-time Wave Particles / Profile Buffers** | Very High | Extremely High | High | Poor (Requires complex compute shader/buffer management not native to visual workflows) | Low | Excellent; provides true physical simulation, but outside the scope of a standard spatial vertex shader architecture. |
| **5\. Screen-Space Depth/Normal Re-projection** | Medium | High | High | Fair | High (Prone to severe occlusion, transparency sorting, and screen-edge artifacts) | Low; a generic post-processing solution that fundamentally fails to capture physical, geometric flow interactions. |

### **Justification of the Primary Recommendation**

The **Hybrid Model** is strongly recommended as the optimal architecture. In this approach, high-frequency turbulence is provided by a non-linearly blended two-phase height advection, which maps seamlessly to the FlowUVW() logic already established in the project. Low-frequency displacement—such as standing waves, bank turbulence, and obstacle pillows—is handled efficiently via static pressure maps.24 This strict separation of frequencies ensures that the water surface maintains structural integrity around obstacles while displaying highly energetic surface flow. Because Godot 4 handles vertex textures cleanly via explicit textureLod commands, this approach scales highly efficiently across hardware constraints while delivering AAA visual fidelity.

## **Concrete Shader Implementation (Pseudocode)**

The following Godot 4 spatial shader pseudocode demonstrates the robust implementation of the hybrid variance-preserving flow displacement, complete with analytical normal reconstruction and depth-tested refraction mitigating edge bleed.

OpenGL Shading Language  
shader\_type spatial;  
render\_mode depth\_draw\_always, specular\_schlick\_ggx;

// Core Data Uniforms  
uniform sampler2D flow\_map : hint\_default\_black, filter\_linear;  
uniform sampler2D detail\_map : hint\_default\_black, filter\_linear\_mipmap; // R: Nx, G: Ny, B: Height, A: Phase Noise  
uniform sampler2D pressure\_map : hint\_default\_black, filter\_linear; // Static displacement (pillows/banks)  
uniform sampler2D DEPTH\_TEXTURE : hint\_depth\_texture, filter\_nearest;  
uniform sampler2D SCREEN\_TEXTURE : hint\_screen\_texture, filter\_linear\_mipmap;

// Control Parameters  
uniform float flow\_speed \= 1.0;  
uniform float cycle\_duration \= 2.0;  
uniform float displacement\_strength \= 1.5;  
uniform float ripple\_displacement\_strength \= 1.0;  
uniform float finite\_difference\_delta \= 0.01;

// Varyings to pass pre-computed data to the fragment stage  
varying float v\_flow\_weight;  
varying vec3 v\_world\_pos;  
varying vec2 v\_flow\_uv1;  
varying vec2 v\_flow\_uv2;

// Reusable function to calculate flowed UVs and variance-preserving weight  
void calculate\_flow\_uvs(vec2 uv, vec2 flow\_dir, float speed\_mult, float phase\_offset, out vec2 uv1, out vec2 uv2, out float weight) {  
    float time\_val \= TIME \* flow\_speed \* speed\_mult;  
      
    // Calculate fractional phases (0.0 to 1.0)  
    float t1 \= mod(time\_val \+ phase\_offset, cycle\_duration) / cycle\_duration;  
    float t2 \= mod(time\_val \+ phase\_offset \+ (cycle\_duration \* 0.5), cycle\_duration) / cycle\_duration;  
      
    // Displace UVs in the opposite direction of the flow  
    uv1 \= uv \- (flow\_dir \* t1);  
    uv2 \= uv \- (flow\_dir \* t2);  
      
    // Variance preserving mathematical weight   
    float raw\_weight \= abs(2.0 \* t1 \- 1.0);  
    weight \= raw\_weight / sqrt(pow(raw\_weight, 2.0) \+ pow(1.0 \- raw\_weight, 2.0));  
}

// Function to evaluate total height at a given UV, combining dynamic flow and static pressure  
float evaluate\_height(vec2 base\_uv, vec2 flow\_dir, float speed\_mult, float phase\_offset) {  
    vec2 uv1, uv2; float w;  
    calculate\_flow\_uvs(base\_uv, flow\_dir, speed\_mult, phase\_offset, uv1, uv2, w);  
      
    // Sample height (B channel) using LOD 0 for vertex shader compatibility \[38\]  
    float h1 \= textureLod(detail\_map, uv1, 0.0).b;  
    float h2 \= textureLod(detail\_map, uv2, 0.0).b;  
      
    // Variance-preserved blend  
    float h\_blend \= mix(h2, h1, w);  
      
    // Recenter from  to \[-1, 1\] for bidirectional displacement  
    float dynamic\_h \= (h\_blend \* 2.0) \- 1.0;  
      
    // Add static pressure/obstacle pillow height  
    float static\_h \= textureLod(pressure\_map, base\_uv, 0.0).r;  
      
    return (dynamic\_h \* displacement\_strength) \+ static\_h;  
}

void vertex() {  
    v\_world\_pos \= (MODEL\_MATRIX \* vec4(VERTEX, 1.0)).xyz;  
    vec2 base\_uv \= UV;  
      
    // 1\. Sample Core Flow Data  
    vec4 flow\_data \= textureLod(flow\_map, base\_uv, 0.0);  
    vec2 flow\_dir \= (flow\_data.rg \* 2.0) \- 1.0; // Decode  to \[-1, 1\]  
    float flow\_magnitude \= length(flow\_dir);  
    float phase\_noise \= textureLod(detail\_map, base\_uv \* 0.5, 0.0).a; // Break up spatial pulsing  
      
    // 2\. Evaluate Total Displacement Height at center vertex  
    float h\_center \= evaluate\_height(base\_uv, flow\_dir, flow\_magnitude, phase\_noise);  
      
    // Optional: Superimpose Runtime Ripple Displacement if within distance threshold  
    // float dist \= length(VERTEX.z);  
    // float ripple\_h \= get\_ripple\_height(v\_world\_pos) \* max(0.0, 1.0 \- (dist / 100.0));  
    // h\_center \+= ripple\_h \* ripple\_displacement\_strength;

    // 3\. Finite Differences for Analytical Normal Reconstruction \[5, 6\]  
    float d \= finite\_difference\_delta;  
    float h\_left  \= evaluate\_height(base\_uv \+ vec2(-d, 0.0), flow\_dir, flow\_magnitude, phase\_noise);  
    float h\_right \= evaluate\_height(base\_uv \+ vec2(d, 0.0), flow\_dir, flow\_magnitude, phase\_noise);  
    float h\_down  \= evaluate\_height(base\_uv \+ vec2(0.0, \-d), flow\_dir, flow\_magnitude, phase\_noise);  
    float h\_up    \= evaluate\_height(base\_uv \+ vec2(0.0, d), flow\_dir, flow\_magnitude, phase\_noise);  
      
    // Derive Tangent and Binormal from height slopes  
    vec3 tangent\_x \= normalize(vec3(d \* 2.0, h\_right \- h\_left, 0.0));  
    vec3 tangent\_z \= normalize(vec3(0.0, h\_up \- h\_down, d \* 2.0));  
    vec3 new\_normal \= normalize(cross(tangent\_z, tangent\_x));  
      
    // Transform normal into local model space for the Godot pipeline   
    NORMAL \= new\_normal;  
    TANGENT \= tangent\_x;  
    BINORMAL \= tangent\_z;  
      
    // 4\. Displace Vertex Geometry  
    VERTEX.y \+= h\_center;  
      
    // Pre-calculate UVs and weight to pass to fragment shader, saving duplicate instructions \[47\]  
    calculate\_flow\_uvs(base\_uv, flow\_dir, flow\_magnitude, phase\_noise, v\_flow\_uv1, v\_flow\_uv2, v\_flow\_weight);  
}

void fragment() {  
    // 1\. Reconstruct blended detail normals  
    vec3 n1 \= texture(detail\_map, v\_flow\_uv1).rgb;  
    vec3 n2 \= texture(detail\_map, v\_flow\_uv2).rgb;  
    n1 \= (n1 \* 2.0) \- 1.0;  
    n2 \= (n2 \* 2.0) \- 1.0;  
    vec3 detail\_normal \= normalize(mix(n2, n1, v\_flow\_weight));  
      
    // Godot automatically applies this tangent-space normal to the new displaced vertex normal  
    NORMAL\_MAP \= detail\_normal;  
      
    // 2\. Refraction & Depth Testing to mitigate MSAA and Edge Bleed   
    float ref\_strength \= 0.05;  
    vec2 ref\_offset \= detail\_normal.xy \* ref\_strength;  
    vec2 refracted\_uv \= SCREEN\_UV \+ ref\_offset;  
      
    // Rigorous Depth logic: Test if the refracted sample hits an occluding object in front of the water  
    float depth\_raw \= texture(DEPTH\_TEXTURE, refracted\_uv).r;  
    vec3 ndc \= vec3(refracted\_uv \* 2.0 \- 1.0, depth\_raw);  
    vec4 view\_pos \= INV\_PROJECTION\_MATRIX \* vec4(ndc, 1.0);  
    view\_pos.xyz /= view\_pos.w;  
    float sampled\_depth \= \-view\_pos.z;  
    float water\_depth \= \-VERTEX.z;  
      
    // Fallback to non-refracted UV if occluded by foreground geometry \[14, 35\]  
    if (sampled\_depth \< water\_depth) {  
        refracted\_uv \= SCREEN\_UV;  
    }  
      
    // Final Refraction Sample  
    vec3 refraction\_color \= textureLod(SCREEN\_TEXTURE, refracted\_uv, 0.0).rgb;  
      
    // Define standard PBR properties...  
    ALBEDO \= refraction\_color \* vec3(0.5, 0.7, 0.9); // Thematic Tint  
    ROUGHNESS \= 0.1;  
}

## **Recommended Phased Implementation Plan**

To systematically integrate this highly complex architecture into the "Godot 4 Waterways Demo" with minimal disruption to the existing rendering pipeline, the implementation should be executed in six dedicated, sequential phases.

### **Phase 1: Minimal Flow-Map-Driven Heightmap Displacement**

The primary objective of the initial phase is to establish basic vertical tracking and ensure the engine pipeline is handling the vertex data correctly.

* Extract the dedicated heightmap (stored in the B channel) from the high-frequency detail texture. Ensure the texture is imported with full uncompressed precision (or high-quality BC7) and linear color space to prevent stepping artifacts.  
* Apply basic linear displacement to VERTEX.y, directly utilizing the existing i\_flowmap data and the core advection logic already present in the FlowUVW() function.  
* Validate the physical deformation of the mesh. At this stage, it is critical to observe and acknowledge the rhythmic pulsing artifact and the dramatic volume collapse at the 50% phase blend, establishing a baseline to correct in the subsequent phase.

### **Phase 2: Two-Phase Height Blending and Variance Preservation**

The objective of the second phase is to stabilize the physical volume of the water and permanently eliminate the pulsing artifact.1

* Replace the naive linear interpolation (mix()) used for the height fields with the variance-preserving algebraic blend discussed previously (dividing by the square root of the sum of squared weights).  
* Implement the recentering logic to shift the height response from the absolute ![][image1] range into the bidirectional ![][image2] range, allowing troughs to form.  
* Inject the spatial phase offset noise (sampled from the A channel of the detail map) into the temporal calculation. This offsets the advection cycle slightly depending on the spatial coordinate, effectively decorrelating the advection seams and breaking up visual repetition across vast stretches of the river.1

### **Phase 3: Spatial Masking and Low-Frequency Pressure Maps**

The third phase introduces environmental collision, obstacle reactions, and velocity-scaled amplitude controls.

* Modify the localized height amplitude by multiplying it with the decoded flow speed magnitude extracted from i\_flowmap. This directly couples the visual wave height to the kinetic energy of the river (faster currents equal higher localized waves).  
* Incorporate the project's existing distance/pressure and obstacle feature maps to drive the static (un-advected) height displacement layer.24 This establishes the stationary hydraulic jumps and obstacle pillows.  
* Implement localized dampening of the high-frequency flow height in areas where the generated foam mask is heavily weighted. This physically simulates highly aerated white-water smoothing out the base geometric turbulence.  
* Apply boundary masking using the terrain contact maps to force the displacement multiplier to zero at the edges, preventing the mesh from clipping awkwardly into the riverbanks.

### **Phase 4: Runtime Ripple Displacement Superposition**

This phase layers the dynamic physical interaction systems over the procedurally generated river currents.48

* Sample the project's existing runtime ripple simulation render target directly within the vertex shader pipeline.  
* Mathematically superimpose the resulting ripple height with the combined flow/pressure height generated in Phase 3\.  
* Implement a rigorous view-space distance attenuation function (fade-out) for the ripple texture lookup. This preserves vital GPU memory bandwidth by completely bypassing the texture fetch when the vertices are beyond an effective visual range.

### **Phase 5: Normal Reconstruction via Finite Differences**

The penultimate phase restores accurate lighting, specular response, and environmental reflections to the newly physicalized waves, which were broken when the vertices were displaced.4

* Implement the 4-tap central difference sampling pattern explicitly in the vertex shader. Ensure that all texture samples utilize textureLod(..., 0.0) to comply with Godot 4 spatial shader constraints and prevent unintended mipmap smoothing.5  
* Generate the analytical ![][image7] and ![][image8] tangent vectors based on the height differences, compute their normalized cross product, and assign the resulting values to NORMAL, TANGENT, and BINORMAL within the Godot shader pipeline.15  
* Pass the calculated variance-preserving flow weight as a varying to the fragment shader. Composite the detailed tangent-space normal map over the newly generated structural vertex normal.29

### **Phase 6: Engine Constraints, Culling, and Artifact Resolution**

The final phase hardens the experimental shader system for production deployment, addressing severe edge-case rendering artifacts.

* Update the engine-side mesh generation scripts (GDScript/C\#) to automatically execute the set\_custom\_aabb() method with heavily expanded vertical bounds. This ensures the CPU does not prematurely frustum-cull the water mesh when the camera approaches the surface.17  
* Implement rigorous screen-space depth checks (DEPTH\_TEXTURE vs VERTEX.z) in the fragment shader prior to sampling the SCREEN\_TEXTURE. This completely eliminates the glowing boundaries, MSAA bleeding, and reflection artifacts commonly seen around rocks and banks where foreground objects occlude the refracted background.14  
* Establish a continuous level-of-detail (LOD) generation pipeline for the river mesh to ensure adequate vertex density near the camera—which is mandatory for smooth displacement—without compromising background rendering performance.32

#### **Works cited**

1. SIGGRAPH 2010 Water Flow in Portal 2 | PDF \- Slideshare, accessed June 9, 2026, [https://www.slideshare.net/slideshow/siggraph-2010-water-flow-in-portal-2/4899875](https://www.slideshare.net/slideshow/siggraph-2010-water-flow-in-portal-2/4899875)  
2. SIGGRAPH 2010 \- Advances in Real-Time Rendering in 3D Graphics and Games, accessed June 9, 2026, [https://advances.realtimerendering.com/s2010/index.html](https://advances.realtimerendering.com/s2010/index.html)  
3. LanLou123/waveparticle \- GitHub, accessed June 9, 2026, [https://github.com/LanLou123/waveparticle](https://github.com/LanLou123/waveparticle)  
4. vcoda/aggregated-graphics-samples \- GitHub, accessed June 9, 2026, [https://github.com/vcoda/aggregated-graphics-samples](https://github.com/vcoda/aggregated-graphics-samples)  
5. Terrain triangulation – summary | IceFall Games \- WordPress.com, accessed June 9, 2026, [https://mtnphil.wordpress.com/2012/10/15/terrain-triangulation-summary/](https://mtnphil.wordpress.com/2012/10/15/terrain-triangulation-summary/)  
6. Vertex Shader Domain Warping with Automatic Differentiation \- arXiv, accessed June 9, 2026, [https://arxiv.org/html/2405.07124v1](https://arxiv.org/html/2405.07124v1)  
7. Publications \- Valve Corporation, accessed June 9, 2026, [https://www.valvesoftware.com/en/publications](https://www.valvesoftware.com/en/publications)  
8. (PDF) Rendering Rapids in Uncharted 4 \- ResearchGate, accessed June 9, 2026, [https://www.researchgate.net/publication/333915560\_Rendering\_Rapids\_in\_Uncharted\_4](https://www.researchgate.net/publication/333915560_Rendering_Rapids_in_Uncharted_4)  
9. Advances in Real-Time Rendering- SIGGRAPH 2016, accessed June 9, 2026, [https://advances.realtimerendering.com/s2016/](https://advances.realtimerendering.com/s2016/)  
10. Texture Distortion \- Catlike Coding, accessed June 9, 2026, [https://catlikecoding.com/unity/tutorials/flow/texture-distortion/](https://catlikecoding.com/unity/tutorials/flow/texture-distortion/)  
11. Flow, Texture Distortion : r/Unity3D \- Reddit, accessed June 9, 2026, [https://www.reddit.com/r/Unity3D/comments/8nhpou/flow\_texture\_distortion/](https://www.reddit.com/r/Unity3D/comments/8nhpou/flow_texture_distortion/)  
12. Chapter 18\. Using Vertex Texture Displacement for Realistic Water Rendering, accessed June 9, 2026, [https://developer.nvidia.com/gpugems/gpugems2/part-ii-shading-lighting-and-shadows/chapter-18-using-vertex-texture-displacement](https://developer.nvidia.com/gpugems/gpugems2/part-ii-shading-lighting-and-shadows/chapter-18-using-vertex-texture-displacement)  
13. Chapter 8\. Per-Pixel Displacement Mapping with Distance Functions \- NVIDIA Developer, accessed June 9, 2026, [https://developer.nvidia.com/gpugems/gpugems2/part-i-geometric-complexity/chapter-8-pixel-displacement-mapping-distance-functions](https://developer.nvidia.com/gpugems/gpugems2/part-i-geometric-complexity/chapter-8-pixel-displacement-mapping-distance-functions)  
14. Reading from DEPTH\_TEXTURE produces noticeable artifacts with MSAA enabled \- Shaders \- Godot Forum, accessed June 9, 2026, [https://forum.godotengine.org/t/reading-from-depth-texture-produces-noticeable-artifacts-with-msaa-enabled/71544](https://forum.godotengine.org/t/reading-from-depth-texture-produces-noticeable-artifacts-with-msaa-enabled/71544)  
15. Spatial shaders — Godot Engine (stable) documentation in English, accessed June 9, 2026, [https://docs.godotengine.org/en/stable/tutorials/shaders/shader\_reference/spatial\_shader.html](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)  
16. How to calculate world and view normals \- Shaders \- Godot Forum, accessed June 9, 2026, [https://forum.godotengine.org/t/how-to-calculate-world-and-view-normals/55711](https://forum.godotengine.org/t/how-to-calculate-world-and-view-normals/55711)  
17. PrimitiveMesh — Godot Engine (4.x) documentation in English, accessed June 9, 2026, [https://docs.godotengine.org/cs/stable/classes/class\_primitivemesh.html](https://docs.godotengine.org/cs/stable/classes/class_primitivemesh.html)  
18. Interactive Visualization of Simulation Data for ... \- reposiTUm, accessed June 9, 2026, [https://repositum.tuwien.at/bitstream/20.500.12708/1225/2/Cornel%20Daniel%20-%202020%20-%20Interactive%20visualization%20of%20simulation%20data%20for...pdf](https://repositum.tuwien.at/bitstream/20.500.12708/1225/2/Cornel%20Daniel%20-%202020%20-%20Interactive%20visualization%20of%20simulation%20data%20for...pdf)  
19. Untitled \- Trepo, accessed June 9, 2026, [https://trepo.tuni.fi/bitstream/handle/10024/115052/kellomaki\_1354.pdf](https://trepo.tuni.fi/bitstream/handle/10024/115052/kellomaki_1354.pdf)  
20. Water technology-of-uncharted-gdc-2012 | PDF \- Slideshare, accessed June 9, 2026, [https://www.slideshare.net/slideshow/water-technologyofunchartedgdc2012/12977478](https://www.slideshare.net/slideshow/water-technologyofunchartedgdc2012/12977478)  
21. Water Technology of Uncharted, accessed June 9, 2026, [https://cgzoo.files.wordpress.com/2012/04/water-technology-of-uncharted-gdc-2012.pdf](https://cgzoo.files.wordpress.com/2012/04/water-technology-of-uncharted-gdc-2012.pdf)  
22. Standing wave \- Wikipedia, accessed June 9, 2026, [https://en.wikipedia.org/wiki/Standing\_wave](https://en.wikipedia.org/wiki/Standing_wave)  
23. 5.3: How to make standing waves \- Physics LibreTexts, accessed June 9, 2026, [https://phys.libretexts.org/Bookshelves/Waves\_and\_Acoustics/Understanding\_Sound\_(Abbot)/05%3A\_Interference/5.03%3A\_How\_to\_make\_standing\_waves](https://phys.libretexts.org/Bookshelves/Waves_and_Acoustics/Understanding_Sound_\(Abbot\)/05%3A_Interference/5.03%3A_How_to_make_standing_waves)  
24. INTERACTIVE WATER SURFACES USING GPU BASED eWAVE ALGORITHM IN A GAME PRODUCTION ENVIRONMENT A Thesis by SOUMITRA GOSWAMI Submit \- Jerry Tessendorf \- Clemson University, accessed June 9, 2026, [https://jtessen.people.clemson.edu/students/goswami\_thesis.pdf](https://jtessen.people.clemson.edu/students/goswami_thesis.pdf)  
25. How Unreal Engine Was Used to Efficiently Create SYNCED: Off-Planet's Detailed Outdoor Environments \- NExT Studios, accessed June 9, 2026, [https://www.nextstudios.com/news/en/?url=/\_news/en/202203/1.html](https://www.nextstudios.com/news/en/?url=/_news/en/202203/1.html)  
26. Mipmaps, generation and level selection \- C0DE517E, accessed June 9, 2026, [http://c0de517e.blogspot.com/2008/05/mipmaps-generation-and-level-selection.html](http://c0de517e.blogspot.com/2008/05/mipmaps-generation-and-level-selection.html)  
27. Followup: Normal Mapping Without Precomputed Tangents | The Tenth Planet, accessed June 9, 2026, [http://www.thetenthplanet.de/archives/1180/comment-page-2](http://www.thetenthplanet.de/archives/1180/comment-page-2)  
28. Chapter 39\. Volume Rendering Techniques \- NVIDIA Developer, accessed June 9, 2026, [https://developer.nvidia.com/gpugems/gpugems/part-vi-beyond-triangles/chapter-39-volume-rendering-techniques](https://developer.nvidia.com/gpugems/gpugems/part-vi-beyond-triangles/chapter-39-volume-rendering-techniques)  
29. Practical Reconstruction Schemes and Hardware-Accelerated Direct Volume Rendering on Body-Centered Cubic Grids, accessed June 9, 2026, [https://www.cg.tuwien.ac.at/research/publications/2004/matt-masterthesis/matt-masterthesis-Thesis.pdf](https://www.cg.tuwien.ac.at/research/publications/2004/matt-masterthesis/matt-masterthesis-Thesis.pdf)  
30. Dividing Cubes Algorithm, accessed June 9, 2026, [https://www.csee.umbc.edu/\~ebert/693/THu/dividingcubes.html](https://www.csee.umbc.edu/~ebert/693/THu/dividingcubes.html)  
31. Vulkan Mobile: Decals are not showing on meshes deformed using \`vertex()\` in a shader if far away from the AABB (unless Extra Cull Margin is increased) · Issue \#72614 · godotengine/godot \- GitHub, accessed June 9, 2026, [https://github.com/godotengine/godot/issues/72614](https://github.com/godotengine/godot/issues/72614)  
32. ArrayMesh — Godot Engine (stable) documentation in English, accessed June 9, 2026, [https://docs.godotengine.org/en/stable/classes/class\_arraymesh.html](https://docs.godotengine.org/en/stable/classes/class_arraymesh.html)  
33. How To Create a Water Depth Effect // Godot 4 3D Shader Tutorial \- YouTube, accessed June 9, 2026, [https://www.youtube.com/watch?v=ib2atnKTLrs](https://www.youtube.com/watch?v=ib2atnKTLrs)  
34. Advanced post-processing — Godot Engine (stable) documentation in English, accessed June 9, 2026, [https://docs.godotengine.org/en/stable/tutorials/shaders/advanced\_postprocessing.html](https://docs.godotengine.org/en/stable/tutorials/shaders/advanced_postprocessing.html)  
35. Struggling to get rid of refraction effects on objects infront of the water shader (left cube). Help please? : r/godot \- Reddit, accessed June 9, 2026, [https://www.reddit.com/r/godot/comments/11ronm2/struggling\_to\_get\_rid\_of\_refraction\_effects\_on/](https://www.reddit.com/r/godot/comments/11ronm2/struggling_to_get_rid_of_refraction_effects_on/)  
36. Refraction Shader \- Godot Community Forums, accessed June 9, 2026, [https://godotforums.randommomentania.com/d/22782-refraction-shader?page=2](https://godotforums.randommomentania.com/d/22782-refraction-shader?page=2)  
37. how to add refraction to a water shader? \- Godot Forums, accessed June 9, 2026, [https://godotforums.org/d/35189-how-to-add-refraction-to-a-water-shader](https://godotforums.org/d/35189-how-to-add-refraction-to-a-water-shader)  
38. Shading language — Godot Engine (3.0) documentation in English, accessed June 9, 2026, [https://docs.godotengine.org/en/3.0/tutorials/shading/shading\_language.html](https://docs.godotengine.org/en/3.0/tutorials/shading/shading_language.html)  
39. Screen-reading shaders — Godot Engine (4.4) documentation in English, accessed June 9, 2026, [https://docs.godotengine.org/en/4.4/tutorials/shaders/screen-reading\_shaders.html](https://docs.godotengine.org/en/4.4/tutorials/shaders/screen-reading_shaders.html)  
40. Why did my displacement shader rip up the seams here, and how do I sew them back together? : r/godot \- Reddit, accessed June 9, 2026, [https://www.reddit.com/r/godot/comments/13uk6iu/why\_did\_my\_displacement\_shader\_rip\_up\_the\_seams/](https://www.reddit.com/r/godot/comments/13uk6iu/why_did_my_displacement_shader_rip_up_the_seams/)  
41. Implement tessellation as an alternative to parallax occlusion mapping · Issue \#5995 · godotengine/godot-proposals \- GitHub, accessed June 9, 2026, [https://github.com/godotengine/godot-proposals/issues/5995](https://github.com/godotengine/godot-proposals/issues/5995)  
42. Support vertex displacement texture for StandardMaterial \- Godot Forums, accessed June 9, 2026, [https://godotforums.org/d/39849-support-vertex-displacement-texture-for-standardmaterial](https://godotforums.org/d/39849-support-vertex-displacement-texture-for-standardmaterial)  
43. Add new Mesh resource subtype to enable creating surfaces using RenderingDevice buffers · Issue \#7209 · godotengine/godot-proposals \- GitHub, accessed June 9, 2026, [https://github.com/godotengine/godot-proposals/issues/7209](https://github.com/godotengine/godot-proposals/issues/7209)  
44. \[WIP\] River shader \- Showcase \- Epic Developer Community Forums \- Unreal Engine, accessed June 9, 2026, [https://forums.unrealengine.com/t/wip-river-shader/42444](https://forums.unrealengine.com/t/wip-river-shader/42444)  
45. Procedural Mesh Generation/Deform with Collision (code in comments) : r/godot \- Reddit, accessed June 9, 2026, [https://www.reddit.com/r/godot/comments/jwyqzd/procedural\_mesh\_generationdeform\_with\_collision/](https://www.reddit.com/r/godot/comments/jwyqzd/procedural_mesh_generationdeform_with_collision/)  
46. I'm developing a GPU Fluid Sim that can flow over terrain creating rivers : r/Unity3D \- Reddit, accessed June 9, 2026, [https://www.reddit.com/r/Unity3D/comments/18oew5d/im\_developing\_a\_gpu\_fluid\_sim\_that\_can\_flow\_over/](https://www.reddit.com/r/Unity3D/comments/18oew5d/im_developing_a_gpu_fluid_sim_that_can_flow_over/)  
47. Coarse Pixel Shading \- Intel, accessed June 9, 2026, [https://www.intel.com/content/dam/develop/external/us/en/documents/coarse-pixel-shading-516367.pdf](https://www.intel.com/content/dam/develop/external/us/en/documents/coarse-pixel-shading-516367.pdf)  
48. Cymatics: How to create this standing waves? : r/blender \- Reddit, accessed June 9, 2026, [https://www.reddit.com/r/blender/comments/1re69c2/cymatics\_how\_to\_create\_this\_standing\_waves/](https://www.reddit.com/r/blender/comments/1re69c2/cymatics_how_to_create_this_standing_waves/)

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEkAAAAZCAYAAAB9/QMrAAACpElEQVR4Xu2YTegNURjGH2EhSr6SkFKUIkmys0JZkNgoSwslGx9lbWHBSpZSsrD4Z2mjWJxsLGxJKcXKSqLsfL1P77z13veeOXfOnfu/xPzqaZp3zjNzzjN3zpy5wMDAwB/ggWiTaGM88I+yCjreF6Lj4VgrDCkHT3RXdEe0PBybxBWo9yjqvZEtoquxOIElolvQPuxs9iMJPUP6Ab2A8bbRJE5DvRbMNqiP2xr2QM/zq9GH0cNF2G96jdgnI6FHSHzsPot2u9pFaGdzd8TzBur10Hsbk72etdBf4TrUh/RT9MTtr2j2j7gaSZgyJA7kvuiZaKWr7xd9Ex12tQi9HBC9HnrZ8ZK3RE1Im6HtL4f6NdFr0XpXS5gyJE5qKdTIdtFHjF/cQy87mPPmOt6VmpB4Q9g+Dv6s6Ktor6sljLdrxQ+KkzU7FAfaVvewTS6ktnpXakLioHMh5eop7BcZQurAEFIHfOf5ZnsXasRC4pqpDXpzYVhIJW+JmpCOYTwMwv348khNvRN+UDZxP8ToK3uX6BPKk69N3PR66GW95C1RE5JN3KdC/TxmOHGTM6KXojWuZneIr1hjKcZXs2xDr4fe9xj1HsJoh0uUQuIaaKvbXwZtf8PVyD3o0sb3NaFHSLnFJNcZvLhdhFsuELmSPWGNkF9M0usXk9zyXFQX2kJiQI+h19vn6nExaU/HzBaTBlfJDOCC6CZ08HxsPCeb+g5XYwD0voJ6vzRtIqx/hw4gh81jORm81iXRU9EGV18tetToHDQ0/ooiCT1DIvwk4HcQPxT5aNXAztF7EO3eA2gPqS8M8Dq0D/5x9CTMIKTFhB+bC7E4ZxL+8pD4Zf48FudMQmVInAPm+aebn8fmzdR/unFC5Ff+/4C9qanOIQ0MDCwqvwGEzMURNhgIyQAAAABJRU5ErkJggg==>

[image2]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFkAAAAZCAYAAABaU4LDAAACKElEQVR4Xu2YzytEURTHj4WFKMlCimxQSlkIG2ksyEap2dj7EyysLVlIljayQv4Em8nGP0BKKVZWEmHl1/l259aZ4755974ZMx73U9+43zvz7jnf4b25lygSiUSC2Wf1snr0ROQbHaxB1pmeSAMh/wStrBFtpoAPe5W1w5pXc1nIUsM4a5O1zhpWcwBBl7SZRj1DPmQ9s95Yn6zFyumqFFm7ZIIBA6yr8s8QstaAdbE+6rDomkDTQy6wlliTrBfybxC3qkvWqPIR0rby0ihQthoWWB+sNuHh93fWnPCaHrIF/3IhDe6RCbRd+bgGGs9CaA03ZGrQwLsQ49yGXCJ3g3fk9n0IrQGvda0F70mMcxvyLbkbTPJ9CK0B67jW0n4MWRBagw7Tov26hNxC5onqoy1Wn3lbBaENJoWZ5PsQWoMO06L93IZ8Te4Gf0vI8uFbl5DrQWiDJTLN4AOW3Jf9LITW8OcefNNUuZtaJtNMl/AAvBvlzbDGlOcirYZZVr8YH1ByyHtinIuQ8deKwvEl3+K7GbHvdYWhqVYDNhm4xoPwXJsRBPrrNiO4lg1BqkSmOMsrmVAlCBANnbM2WI/kPneAjy2zvJ7Epwa71kl5bOkk89rjshC63iA1PeRa6WatkDmgmVJzkglKDrlWcBtbJ3NQJW8nltyH7AMOa4602UD+RchF1qk2G0jmkPN0aD+kjQaCgDMf2uNmjydxpDpr5P/tJhKJRHz5AompxT4AaGpMAAAAAElFTkSuQmCC>

[image3]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAaCAYAAADxNd/XAAACPklEQVR4Xu2XsUsdQRCHJ2hAiSFBAyIKknQBIYhEEGKniIU2FhbapwkpkiIQ7PIfBKs0wSoodiaI2giWglVsFEFBsBAbQVAk0fnYW+5u2Dv3PdFHyPvgx/Nmb2dv5mZ2T5E6de6ELVWvNd4j71XL1hhLv2rCGu+Zh6pvqid24CaY9Nsaa8ilatoay/ijemeNNWRJtWuNRfSofqga7UAN6VTtS2QpfVJNWWONIZmLqgE7YGlX7ak67IC4hjoW1xsfVQ8yY9gr2S3wNaPaVP2V1BelciXhTI+q5qzR8kp1qnpsB8Q1UauqT7WtepYZY1EyFAu+1sT5OpPUF37xFUog966rWow9x5g4B5Yh1aq4V0l/zEqatRfidok3yXUM+OJBCJr1vC9+v0s4gQR1kPwWUhRAk+qpuIc9EheQh7/3xTVaLPiCE3HBZ/lsrj23CsDjM+YhsF9SvGgZzMXX14yNBNEXIaICIJs0Fc5D0ODZALpUh5K+kdL6NDAXX+MZG7sfJRqC4FifjaaQsl0IaHCazkMv8BCPxJ0fvoyGxR2GZefJS3G+aE7PvLgdKkTULuRL4rUdSFiX9A00qC6S62bVF0mb8UNip1/IXAjmcA87EvNGVN25O/Lg8601huCwKMscD849bck1i/PmQpn7KfkMW5iLH8oJv0X4kziqRMkMdf3cDlTBhlS2OxVBn9Cb0SzI7b9GKYdBa6ySc9WkNZbB4juS/1yoBF71ilQ/PwufFXzeh0r0Rv7p/8jq1PmfuAYeZmLlMr05iQAAAABJRU5ErkJggg==>

[image4]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABMAAAAaCAYAAABVX2cEAAAA3klEQVR4XmNgGAWUAlYgFkIXRALM6AL4AAcQSwLxViD+D8SbgVgVKg4CIMteQeVCgVgGKo4XWALxTyA+AcT8aHLvgTgBTYwgyGGAuGAKEDMCsTwQX4eySQaKDBDDnkDZp4F4FooKEsFvBoiBIIzuXZIBKMxABv1BlyAVgMIGZMg/BoiBIK+SDYKB2JwBEgEgw9JRpYkHzxkghoEAKKxA3gUlFVCSIQloAnEZA2oSQE4mRANQ9M9HF2SAGAyLVbwAlN9CgHghA0TxMagYDICykgtUDoSjGCBZbBSMgqEPAKyyKUamnsX0AAAAAElFTkSuQmCC>

[image5]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAZCAYAAAA4/K6pAAAAw0lEQVR4XmNgGAXYgDEQ/yeAQWpwgnQGiKIrQKwKxJJQLAMVB2FGuGo0oATEzxkwFQQD8V8gngXErGhyKCAaiK+jCwLBewaIzfzoEuggD4iVkfjyQHwLikFsksE+BojNZugShADInyD/gvwN8j/JoIwBYjOIRg9QggBkI0gzyAXIQASIXdDEMAAstNEDDOSlVQwEXAPSBNIMCnF0EM4ACQ+cYDUDRPNcIA5BwjOB+BVUbjlcNRYAS6L4sB9c9SgYBWgAAI2PM4KuYfK7AAAAAElFTkSuQmCC>

[image6]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABEAAAAaCAYAAABRqrc5AAAA10lEQVR4Xu2RwQoBURSGf6GIothYKWXFWim28jwWttZewTMoe1l4AxuytbOStRT+M/eW445hZmQ3X301c+6dc/85F0h4R4qmnVrB1jUVmlPvWfXsba7RCb3TDS3rDZYW3dIl7cN/sEcDpsnJXbDIh2f4E/qQJqKOLdTpDM4vBHGAadJWtRJd0byqfWRIb3RNi3RM9zBJQlOlO3qhXXqknZcdIenhOZuvQwxCrlsaLNyFKIzoFSZRLDJ0DjMXmU8s5HRJIWkiI9fZhEkh85jSAX4YbELCX3gATugfzlec190AAAAASUVORK5CYII=>

[image7]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABUAAAAbCAYAAACTHcTmAAABBklEQVR4Xu2UMQtBURTHj0IGiwwGE4t8B6NvYfQFLIh8AoNJme02KaPJwGSxWAxKKaNBCv9/N3Wd97xuvEW9X/2Ge969p3vuveeJRPwVdfhw9AQHZlkwZ9ixxnE4gUdYtOLkBmsq5ssKZq1xHu7hDKasONnCiop5KMOCirXFlFpVcbKEGR3UcCHLtWHpTKpLJ0PxzneC58akocKEdx38BV4Sk/KSQoNnzKRd/eEXePMs3e/mvyLofb5owJGY99qHLbh7m6Hg7rjLoNJ7MAbH8CBmA5e3GSAp3v5+yfZlc/jBFuZRhcpVHNrVhRzcwBJcwDRsiuMP5hMJOIVzuBbTzvy7MR4RAZ5M7j1DFxBhfgAAAABJRU5ErkJggg==>

[image8]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAaCAYAAAC3g3x9AAABBUlEQVR4XmNgGAWDFuwA4v9AXAbEIVC8CirWiiT2ECpGELwF4kokPgsQrwHi50CshCTuCMS/kfhYAScQx6CJ2TBANIJchwz0gfgqmhgG0ARiRTSxcgaI11zQxEH8Y2hiRIEHDBADOdDEyQYg7xIV+MQAkKtAhj1BlyAXSDNADNyKLkEuAEXIPwbMCCELgLwLchnIuzJocshAjQGStEBAHlkCHYBcBXJdFboEErBkgBiiCsSPgNgMVRoCJIFYB4h3MUDCbyoQBwCxOBCzIqlDBqAMQZVgAYHZQGyALkguEAJiFShbDIinIcmRDGqAOBxKg4IGROMKEqIALxAzQtkCyBKjYBADAKEMKOPy90MOAAAAAElFTkSuQmCC>