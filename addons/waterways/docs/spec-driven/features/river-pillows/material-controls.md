# River Pillow Material Controls

This page explains the `Material / Pillow` inspector controls for `Water River`.

For placement review, keep `Forward Reach Tiles`, `Contact Pull Tiles`, `Contact Pull Strength`, `Terrain Height`, and `Obstruction Height` at `0.0` unless a review step explicitly asks otherwise. Those controls can change the visible read without fixing the baked pillow mask.

## Pillow Shape

| Control | Meaning |
| --- | --- |
| Strength | Overall visible pillow amount after the baked impact mask and gates. |
| Pressure Strength | Compressed-water color push on the upstream face of the pillow. |
| Highlight Strength | Bright surface highlight on top of the pillow response. |
| Forward Reach Tiles | Moves the visible pillow mask forward from the baked impact signal. Keep at `0.0` for placement review. |
| Contact Pull Tiles | Pulls the visible response back toward nearby contact after raw placement is accepted. |
| Contact Pull Strength | Blends how strongly the contact-pull offset affects visible pillow placement. |

## Pillow Mask Gates

The gate controls decide where the baked pillow signal is allowed to become visible.

| Control | Meaning |
| --- | --- |
| Confidence Gate Start | Obstacle confidence value where the pillow mask begins to appear. |
| Confidence Gate Full | Obstacle confidence value where the pillow mask reaches full contribution. |
| Hard Gate Start | Hard-boundary or protrusion value where pillow response begins to pass the gate. |
| Hard Gate Full | Hard-boundary or protrusion value where pillow response reaches full contribution. |
| Energy Gate Start | Grade/energy value where pillow response begins to appear. |
| Energy Gate | Grade/energy value where pillow response reaches full contribution. |
| Flow Gate Start | Final flow strength where pillow response begins to appear. |
| Flow Gate | Final flow strength where pillow response reaches full contribution. |
| Bank Suppression | Reduces pillow response on ordinary banks so hard protrusions read more clearly. |

## Pillow Surface

| Control | Meaning |
| --- | --- |
| Pressure Color | Tint used by the compressed-water pressure response. |
| Highlight Color | Tint used by the brighter pillow highlight response. |
| Specular Boost | Increases specular response inside the pillow mask. |
| Roughness Reduction | Makes the pillow surface smoother and glossier inside the mask. |
| Normal Strength | Adds normal-map motion and surface disturbance inside the pillow mask. |

## Pillow Bands & Foam

| Control | Meaning |
| --- | --- |
| Band Strength | Controls the strength of subtle compression bands across the pillow. |
| Band Scale | Controls compression-band spacing. Higher values make tighter bands. |
| Foam Bias | Adds a small foam preference inside the pillow mask without replacing the foam system. |

## Pillow Height

Pillow height is default-off and visual-only. It can help review a raised-water look, but it is not a placement fix.

| Control | Meaning |
| --- | --- |
| Terrain Height | Default-off lift for broad terrain or hard-boundary pillow response. |
| Terrain Height Curve | Shapes how strongly terrain lift follows the pillow mask. |
| Obstruction Height | Default-off lift for rocks or hard objects in the river. |
| Obstruction Height Curve | Shapes how strongly obstruction lift follows its mask. |
| Height Smoothing Tiles | Smooths pillow height sampling across nearby source tiles. |

## Pillow Seam Fades

Use seam controls only when reviewing seam artifacts. They can hide artifacts, but they can also suppress valid visible response near tile boundaries.

| Control | Meaning |
| --- | --- |
| Height Seam Stitch Tiles | Blends pillow height across UV tile seams to reduce visible breaks. |
| Height Tile Seam Fade | Fades pillow height near UV tile seams when seam artifacts need hiding. |
| Material Tile Seam Fade | Fades visible pillow material response near UV tile seams when needed. |
